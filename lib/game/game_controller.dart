import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../copy.dart';
import '../data/batch_loader.dart';
import '../data/models.dart';
import 'decision.dart';
import 'scoring.dart';

export 'scoring.dart' show Disagreement, DisagreementSide;

/// The Evidence sheet, the How-it-works dialog and the Audit log are
/// Navigator routes, not phases.
enum GamePhase { loading, error, stack, locking, reveal, proof }

/// Schedules [f] after [d]. Injected so tests can run it immediately or
/// capture it and fire it by hand.
typedef Delay = void Function(Duration d, void Function() f);

void timerDelay(Duration d, void Function() f) {
  Timer(d, f);
}

/// The whole game state: one session of up to 20 cards, the decisions taken
/// on them, the audit trail and the current phase.
class GameController extends ChangeNotifier {
  GameController({
    this.lockPause = const Duration(seconds: 1),
    Delay? delay,
    DateTime Function()? now,
    Random? random,
  })  : _delay = delay ?? timerDelay,
        _now = now ?? DateTime.now,
        _random = random ?? Random();

  /// How long the lock overlay stays before the Reveal.
  final Duration lockPause;

  final Delay _delay;
  final DateTime Function() _now;
  final Random _random;

  Batch? _batch;
  List<PoItem> _session = const [];
  Map<String, PoItem> _byId = const {};
  int _index = 0;
  final LinkedHashMap<String, Decision> _decisions = LinkedHashMap();
  final List<AuditEntry> _audit = [];
  GamePhase _phase = GamePhase.loading;
  String? _errorMessage;

  /// Bumped by every new session so a lock callback scheduled for an older
  /// session is ignored without having to cancel timers.
  int _generation = 0;
  bool _disposed = false;

  // Loading and session setup.

  /// Uses [batch] when given, otherwise loads the bundled asset, then starts
  /// a session. Any failure lands on [GamePhase.error] with [errorMessage].
  Future<void> loadBatch({Batch? batch}) async {
    _phase = GamePhase.loading;
    _errorMessage = null;
    _notify();
    try {
      final loaded = batch ?? await loadBatchAsset();
      if (_disposed) return;
      _batch = loaded;
      startSession();
    } catch (e) {
      if (_disposed) return;
      _errorMessage = e.toString();
      _phase = GamePhase.error;
      _notify();
    }
  }

  /// Shuffles the pool, takes up to 20 items and resets every decision.
  void startSession() {
    final batch = _batch;
    if (batch == null) return;
    _generation++;
    final pool = [...batch.items]..shuffle(_random);
    _session = List.unmodifiable(pool.take(min(20, pool.length)));
    _byId = {for (final item in _session) item.id: item};
    _decisions.clear();
    _audit.clear();
    _index = 0;
    _phase = GamePhase.stack;
    _notify();
  }

  // Decisions.

  /// Holds the current card. The 5th hold locks the deck, so the phase guard
  /// alone blocks a 6th; no separate slot check is needed.
  void hold({
    DecisionSource source = DecisionSource.button,
    String reason = Copy.holdReason,
  }) {
    _consumeSlot(Decision.hold, source, reason);
  }

  /// Releases the current card. Release never consumes a slot.
  void release({
    DecisionSource source = DecisionSource.button,
    String reason = Copy.releaseReason,
  }) {
    final item = currentItem;
    if (_phase != GamePhase.stack || item == null) return;
    _record(item, Decision.release, source, reason);
    _advance();
  }

  /// Escalates the current card. A human must still review it, so it
  /// consumes a slot and follows the hold path, including the 5th-slot rule.
  void escalate({DecisionSource source = DecisionSource.sheet}) {
    _consumeSlot(Decision.escalate, source, Copy.escalateReason);
  }

  void _consumeSlot(Decision decision, DecisionSource source, String reason) {
    final item = currentItem;
    if (_phase != GamePhase.stack || item == null) return;
    _record(item, decision, source, reason);
    if (slotsUsed >= k) {
      _lock();
    } else {
      _advance();
    }
  }

  void _record(
    PoItem item,
    Decision decision,
    DecisionSource source,
    String reason,
  ) {
    _decisions[item.id] = decision;
    logDecision(item, decision, source, reason);
  }

  /// Appends one audit row. Public so tests and the sheet can call it.
  /// [cardIndex] defaults to the current card.
  void logDecision(
    PoItem item,
    Decision decision,
    DecisionSource source,
    String reason, {
    int? cardIndex,
  }) {
    _audit.add(
      AuditEntry(
        at: _now(),
        itemId: item.id,
        vendor: item.vendor,
        decision: decision,
        source: source,
        reason: reason,
        cardIndex: cardIndex ?? _index,
      ),
    );
  }

  void _advance() {
    _index++;
    if (_index >= _session.length) {
      _lock();
    } else {
      _notify();
    }
  }

  /// The exact lock rule: every undecided card after the current one is
  /// auto-released in session order, the index stays so the Stack can show
  /// the overlay, and the Reveal follows after [lockPause].
  void _lock() {
    for (var i = _index + 1; i < _session.length; i++) {
      final item = _session[i];
      if (_decisions.containsKey(item.id)) continue;
      _decisions[item.id] = Decision.autoRelease;
      logDecision(
        item,
        Decision.autoRelease,
        DecisionSource.auto,
        Copy.autoReleaseReason,
        cardIndex: i,
      );
    }
    _phase = GamePhase.locking;
    _notify();
    final generation = _generation;
    _delay(lockPause, () {
      if (_disposed) return;
      if (generation != _generation || _phase != GamePhase.locking) return;
      _phase = GamePhase.reveal;
      _notify();
    });
  }

  // Navigation between the end screens.

  void showProof() {
    if (_phase != GamePhase.reveal) return;
    _phase = GamePhase.proof;
    _notify();
  }

  void showReveal() {
    if (_phase != GamePhase.proof) return;
    _phase = GamePhase.reveal;
    _notify();
  }

  /// A fresh shuffle from the same random source, so the order changes.
  void playAgain() => startSession();

  /// Debug only: same order, decisions and audit cleared.
  void reset() {
    if (_batch == null) return;
    _generation++;
    _decisions.clear();
    _audit.clear();
    _index = 0;
    _phase = GamePhase.stack;
    _notify();
  }

  // Read-only state.

  GamePhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  List<PoItem> get session => _session;
  int get currentIndex => _index;
  int get k => _batch?.meta.reviewCapacityK ?? 5;
  ProofData? get proof => _batch?.proof;

  /// One-based, clamped so the overlay after exhaustion reads "Card 20 of 20".
  int get cardNumber => min(_index + 1, _session.length);

  PoItem? get currentItem =>
      _index < _session.length ? _session[_index] : null;

  int get slotsUsed => _decisions.values
      .where((d) => d == Decision.hold || d == Decision.escalate)
      .length;

  bool get isLocked => slotsUsed >= k || _phase != GamePhase.stack;

  /// Held or escalated items in the order they were held.
  List<PoItem> get yourPicks => List.unmodifiable([
        for (final entry in _decisions.entries)
          if (entry.value == Decision.hold || entry.value == Decision.escalate)
            _byId[entry.key]!,
      ]);

  List<PoItem> get modelPicks => modelPicksOf(_session, k);

  bool isYourPick(String id) {
    final d = _decisions[id];
    return d == Decision.hold || d == Decision.escalate;
  }

  bool isModelPick(String id) => modelPicks.any((p) => p.id == id);

  int get yourCaught => caughtCount(yourPicks);
  int get modelCaught => caughtCount(modelPicks);
  double get yourExposureProtected => exposureProtected(yourPicks);
  double get modelExposureProtected => exposureProtected(modelPicks);

  int get actualExceptionCount => caughtCount(_session);

  Disagreement? get biggestDisagreement =>
      pickDisagreement(_session, yourPicks, modelPicks);

  List<AuditEntry> get auditEntries => List.unmodifiable(_audit);

  Decision? decisionFor(String id) => _decisions[id];

  String get headline {
    final holds = yourPicks.length;
    if (holds == k) {
      return Copy.headlineSameReviews(yourCaught, modelCaught, k);
    }
    return Copy.headlineFewerHolds(yourCaught, holds, modelCaught, k);
  }

  // Lifecycle.

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
