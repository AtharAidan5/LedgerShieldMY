import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgershield_my/copy.dart';
import 'package:ledgershield_my/data/batch_loader.dart';
import 'package:ledgershield_my/data/models.dart';
import 'package:ledgershield_my/game/decision.dart';
import 'package:ledgershield_my/game/game_controller.dart';

const String surpriseId = 'PO-4500013302-00010';

final DateTime fixedClock = DateTime(2026, 10, 11, 9, 30, 0);

/// Stores the lock callback instead of running it, so a test can observe the
/// locking phase and then fire the transition by hand.
class _CapturingDelay {
  void Function()? _pending;
  Duration? lastDuration;

  void call(Duration d, void Function() f) {
    lastDuration = d;
    _pending = f;
  }

  bool get hasPending => _pending != null;

  void fire() {
    final f = _pending;
    _pending = null;
    f?.call();
  }
}

void _immediate(Duration d, void Function() f) => f();

void main() {
  late Batch batch;

  setUpAll(() {
    batch = parseBatch(File('assets/data/batch.json').readAsStringSync());
  });

  Future<GameController> make({Delay delay = _immediate}) async {
    final controller = GameController(
      lockPause: Duration.zero,
      delay: delay,
      now: () => fixedClock,
      random: Random(42),
    );
    await controller.loadBatch(batch: batch);
    return controller;
  }

  /// Plays through the deck holding only the given ids, releasing the rest.
  void playHolding(GameController c, Set<String> ids) {
    while (c.phase == GamePhase.stack && c.currentItem != null) {
      if (ids.contains(c.currentItem!.id)) {
        c.hold();
      } else {
        c.release();
      }
    }
  }

  Set<String> topFiveBy(Comparator<PoItem> compare) {
    final sorted = [...batch.items]..sort(compare);
    return sorted.take(5).map((p) => p.id).toSet();
  }

  test('startSession picks 20 items with unique ids', () async {
    final c = await make();
    expect(c.phase, GamePhase.stack);
    expect(c.session.length, 20);
    expect(c.session.map((p) => p.id).toSet().length, 20);
    expect(c.k, 5);
    expect(c.cardNumber, 1);
    expect(c.slotsUsed, 0);
  });

  test('hold consumes exactly one slot', () async {
    final c = await make();
    final first = c.currentItem!;
    c.hold();
    expect(c.slotsUsed, 1);
    expect(c.currentIndex, 1);
    expect(c.decisionFor(first.id), Decision.hold);
    expect(c.yourPicks, [first]);
    expect(c.auditEntries.length, 1);
    expect(c.auditEntries.single.decision, Decision.hold);
    expect(c.auditEntries.single.source, DecisionSource.button);
    expect(c.auditEntries.single.reason, Copy.holdReason);
  });

  test('hold is ignored once phase leaves stack', () async {
    final c = await make(delay: _CapturingDelay().call);
    for (var i = 0; i < 5; i++) {
      c.hold();
    }
    expect(c.phase, GamePhase.locking);
    expect(c.slotsUsed, 5);
    final auditBefore = c.auditEntries.length;
    final indexBefore = c.currentIndex;
    c.hold();
    expect(c.slotsUsed, 5);
    expect(c.auditEntries.length, auditBefore);
    expect(c.currentIndex, indexBefore);
    expect(c.phase, GamePhase.locking);
  });

  test(
      '5th hold auto-releases every remaining card with source auto and moves to reveal after the pause',
      () async {
    final capturing = _CapturingDelay();
    final c = await make(delay: capturing.call);
    for (var i = 0; i < 5; i++) {
      c.hold();
    }
    expect(c.phase, GamePhase.locking);
    expect(c.isLocked, isTrue);
    expect(c.currentIndex, 4);
    expect(c.cardNumber, 5);
    expect(capturing.hasPending, isTrue);
    expect(capturing.lastDuration, Duration.zero);

    final remaining = c.session.skip(5).map((p) => p.id).toList();
    for (final id in remaining) {
      expect(c.decisionFor(id), Decision.autoRelease, reason: id);
    }
    final autoEntries =
        c.auditEntries.where((e) => e.decision == Decision.autoRelease).toList();
    expect(autoEntries.map((e) => e.itemId).toList(), remaining);
    expect(autoEntries.every((e) => e.source == DecisionSource.auto), isTrue);
    expect(
      autoEntries.every((e) => e.reason == Copy.autoReleaseReason),
      isTrue,
    );
    expect(autoEntries.map((e) => e.cardIndex).toList(),
        List.generate(15, (i) => i + 5));
    expect(c.auditEntries.length, 20);

    capturing.fire();
    expect(c.phase, GamePhase.reveal);
  });

  test('release does not consume a slot', () async {
    final c = await make();
    final first = c.currentItem!;
    c.release();
    expect(c.slotsUsed, 0);
    expect(c.currentIndex, 1);
    expect(c.decisionFor(first.id), Decision.release);
    expect(c.yourPicks, isEmpty);
    expect(c.auditEntries.single.decision, Decision.release);
    expect(c.auditEntries.single.reason, Copy.releaseReason);
  });

  test('escalate consumes a slot and logs Decision.escalate', () async {
    final c = await make();
    final first = c.currentItem!;
    c.escalate();
    expect(c.slotsUsed, 1);
    expect(c.decisionFor(first.id), Decision.escalate);
    expect(c.isYourPick(first.id), isTrue);
    expect(c.yourPicks, [first]);
    expect(c.auditEntries.single.decision, Decision.escalate);
    expect(c.auditEntries.single.source, DecisionSource.sheet);
    expect(c.auditEntries.single.reason, Copy.escalateReason);
  });

  test('escalate from sheet records exactly one audit entry and one slot',
      () async {
    final c = await make();
    // The StackScreen hands the deck a commit callback that calls only
    // escalate; the deck runs it once when the fling completes.
    void commit() => c.escalate(source: DecisionSource.sheet);
    commit();
    expect(c.auditEntries.length, 1);
    expect(c.slotsUsed, 1);
    expect(c.auditEntries.single.decision, Decision.escalate);
    expect(c.currentIndex, 1);
  });

  test('deck exhausted with 3 holds still reaches reveal and headline says 3 holds',
      () async {
    final c = await make();
    final toHold = c.session.take(3).map((p) => p.id).toSet();
    playHolding(c, toHold);
    expect(c.phase, GamePhase.reveal);
    expect(c.slotsUsed, 3);
    expect(c.yourPicks.length, 3);
    expect(c.auditEntries.length, 20);
    expect(
      c.auditEntries.where((e) => e.decision == Decision.autoRelease),
      isEmpty,
    );
    expect(c.headline, contains('with 3 holds'));
    expect(
      c.headline,
      Copy.headlineFewerHolds(c.yourCaught, 3, c.modelCaught, 5),
    );
  });

  test('cardNumber never exceeds session length after exhaustion', () async {
    final c = await make();
    playHolding(c, const {});
    expect(c.phase, GamePhase.reveal);
    expect(c.currentIndex, 20);
    expect(c.currentItem, isNull);
    expect(c.cardNumber, 20);
  });

  test('hold and release are no-ops outside phase stack', () async {
    final idle = GameController(
      lockPause: Duration.zero,
      delay: _immediate,
      now: () => fixedClock,
      random: Random(42),
    );
    expect(idle.phase, GamePhase.loading);
    idle.hold();
    idle.release();
    idle.escalate();
    expect(idle.auditEntries, isEmpty);
    expect(idle.slotsUsed, 0);

    final c = await make();
    playHolding(c, const {});
    expect(c.phase, GamePhase.reveal);
    final before = c.auditEntries.length;
    c.hold();
    c.release();
    c.escalate();
    expect(c.auditEntries.length, before);
    expect(c.slotsUsed, 0);

    c.showProof();
    expect(c.phase, GamePhase.proof);
    c.hold();
    c.release();
    expect(c.auditEntries.length, before);
    c.showReveal();
    expect(c.phase, GamePhase.reveal);
  });

  test('yourCaught and yourExposureProtected sum only true outcomes', () async {
    final c = await make();
    final held = c.session.take(5).toList();
    for (var i = 0; i < 5; i++) {
      c.hold();
    }
    final expectedCaught =
        held.where((p) => p.outcome.exceptionReachedClearance).length;
    final expectedUnits = held
        .where((p) => p.outcome.exceptionReachedClearance)
        .fold(0.0, (sum, p) => sum + p.outcome.actualExposureUnits);
    expect(c.yourCaught, expectedCaught);
    expect(c.yourExposureProtected, closeTo(expectedUnits, 0.001));
    final missed = held.where((p) => !p.outcome.exceptionReachedClearance);
    for (final p in missed) {
      expect(p.outcome.actualExposureUnits, 0.0);
    }
    expect(c.actualExceptionCount, 8);
  });

  test('modelPicks are the five lowest model_rank items', () async {
    final c = await make();
    expect(c.modelPicks.length, 5);
    expect(c.modelPicks.map((p) => p.modelRank).toList(), [1, 2, 3, 4, 5]);
    for (final p in c.modelPicks) {
      expect(c.isModelPick(p.id), isTrue);
    }
    final notPicked = c.session.where((p) => p.modelRank > 5);
    for (final p in notPicked) {
      expect(c.isModelPick(p.id), isFalse);
    }
  });

  test('modelCaught is 4 and modelExposureProtected is 1175.1', () async {
    final c = await make();
    expect(c.modelCaught, 4);
    expect(c.modelExposureProtected, closeTo(1175.1, 0.001));
  });

  test(
      'biggestDisagreement picks PO-4500013302-00010 when the player holds the five largest exposures',
      () async {
    final c = await make();
    playHolding(
      c,
      topFiveBy((a, b) => b.exposureUnits.compareTo(a.exposureUnits)),
    );
    expect(c.phase, GamePhase.reveal);
    expect(c.slotsUsed, 5);
    final d = c.biggestDisagreement;
    expect(d, isNotNull);
    expect(d!.item.id, surpriseId);
    expect(d.side, DisagreementSide.modelOnly);
  });

  test(
      'biggestDisagreement picks PO-4500013302-00010 when the player holds the five highest probabilities',
      () async {
    final c = await make();
    playHolding(c, topFiveBy((a, b) => b.riskProb.compareTo(a.riskProb)));
    expect(c.phase, GamePhase.reveal);
    final d = c.biggestDisagreement;
    expect(d, isNotNull);
    expect(d!.item.id, surpriseId);
    expect(d.side, DisagreementSide.modelOnly);
  });

  test('biggestDisagreement why contains the vendor base rate as 31%',
      () async {
    final c = await make();
    playHolding(
      c,
      topFiveBy((a, b) => b.exposureUnits.compareTo(a.exposureUnits)),
    );
    final d = c.biggestDisagreement!;
    expect(d.why, contains('31%'));
    expect(d.why, contains(Copy.vendorBaseRate('31%')));
    expect(d.why, contains(Copy.rankedThis(5, 20)));
    expect(d.why, contains(Copy.rankWeighsHistory));
    expect(d.why, contains(d.item.reason));
    expect(d.why, contains(Copy.outcomeException));
  });

  test('biggestDisagreement is null when picks match the model', () async {
    final c = await make();
    playHolding(c, topFiveBy((a, b) => a.modelRank.compareTo(b.modelRank)));
    expect(c.phase, GamePhase.reveal);
    expect(c.yourPicks.toSet(), c.modelPicks.toSet());
    expect(c.biggestDisagreement, isNull);
    expect(c.headline, Copy.headlineSameReviews(4, 4, 5));
  });

  test('audit entries carry the injected clock and one entry per decision',
      () async {
    final c = await make();
    final toHold = c.session.take(5).map((p) => p.id).toSet();
    playHolding(c, toHold);
    expect(c.auditEntries.length, 20);
    expect(c.auditEntries.map((e) => e.itemId).toSet().length, 20);
    for (final e in c.auditEntries) {
      expect(e.at, fixedClock);
    }
    expect(
      c.auditEntries.where((e) => e.decision == Decision.hold).length,
      5,
    );
    expect(
      c.auditEntries.where((e) => e.decision == Decision.autoRelease).length,
      15,
    );
    final sessionIds = c.session.map((p) => p.id).toList();
    for (final e in c.auditEntries) {
      expect(sessionIds[e.cardIndex], e.itemId);
      expect(e.vendor, c.session[e.cardIndex].vendor);
    }
  });

  test('playAgain changes the order and clears decisions and audit', () async {
    final c = await make();
    final before = c.session.map((p) => p.id).toList();
    c.hold();
    c.release();
    expect(c.auditEntries.length, 2);
    c.playAgain();
    final after = c.session.map((p) => p.id).toList();
    expect(after, isNot(before));
    expect(after.toSet(), before.toSet());
    expect(c.phase, GamePhase.stack);
    expect(c.currentIndex, 0);
    expect(c.slotsUsed, 0);
    expect(c.auditEntries, isEmpty);
    expect(c.yourPicks, isEmpty);
    for (final id in after) {
      expect(c.decisionFor(id), isNull);
    }
  });

  test('reset keeps order and clears decisions', () async {
    final c = await make();
    final before = c.session.map((p) => p.id).toList();
    c.hold();
    c.release();
    c.escalate();
    expect(c.slotsUsed, 2);
    c.reset();
    expect(c.session.map((p) => p.id).toList(), before);
    expect(c.phase, GamePhase.stack);
    expect(c.currentIndex, 0);
    expect(c.slotsUsed, 0);
    expect(c.auditEntries, isEmpty);
    for (final id in before) {
      expect(c.decisionFor(id), isNull);
    }
  });

  test(
      'sample data: largest-exposure holds and highest-probability holds both make PO-4500013302-00010 the disagreement',
      () async {
    final bySize = await make();
    playHolding(
      bySize,
      topFiveBy((a, b) => b.exposureUnits.compareTo(a.exposureUnits)),
    );
    final byProb = await make();
    playHolding(byProb, topFiveBy((a, b) => b.riskProb.compareTo(a.riskProb)));

    expect(bySize.biggestDisagreement?.item.id, surpriseId);
    expect(byProb.biggestDisagreement?.item.id, surpriseId);
    expect(bySize.yourCaught, 2);
    expect(bySize.yourExposureProtected, closeTo(952.5, 0.001));
    expect(byProb.yourCaught, 4);
    expect(byProb.yourExposureProtected, closeTo(1161.3, 0.001));
    expect(bySize.modelExposureProtected, greaterThan(byProb.yourExposureProtected));
  });
}
