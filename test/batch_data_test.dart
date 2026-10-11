import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgershield_my/data/batch_loader.dart';
import 'package:ledgershield_my/data/models.dart';

void main() {
  late String raw;
  late Batch batch;

  setUpAll(() {
    raw = File('assets/data/batch.json').readAsStringSync();
    batch = parseBatch(raw);
  });

  List<PoItem> topFive(Comparator<PoItem> compare) {
    final sorted = [...batch.items]..sort(compare);
    return sorted.take(5).toList();
  }

  int caught(List<PoItem> picks) =>
      picks.where((p) => p.outcome.exceptionReachedClearance).length;

  double protected(List<PoItem> picks) => picks
      .where((p) => p.outcome.exceptionReachedClearance)
      .fold(0.0, (sum, p) => sum + p.outcome.actualExposureUnits);

  int exposureRank(PoItem item) {
    final sorted = [...batch.items]
      ..sort((a, b) => b.exposureUnits.compareTo(a.exposureUnits));
    return sorted.indexOf(item) + 1;
  }

  test('parses 20 items with unique ids', () {
    expect(batch.items.length, 20);
    expect(batch.items.map((i) => i.id).toSet().length, 20);
    expect(batch.meta.reviewCapacityK, 5);
  });

  test('model_rank values are unique 1..20', () {
    final ranks = batch.items.map((i) => i.modelRank).toSet();
    expect(ranks, {for (var r = 1; r <= 20; r++) r});
  });

  test('exactly 8 outcomes are true', () {
    expect(caught(batch.items), 8);
  });

  test('risk_band matches the threshold rule', () {
    for (final item in batch.items) {
      final expected = item.riskProb < 0.35
          ? RiskBand.low
          : item.riskProb <= 0.65
              ? RiskBand.elevated
              : RiskBand.high;
      expect(item.riskBand, expected, reason: item.id);
    }
  });

  test('risk_low <= risk_prob <= risk_high', () {
    for (final item in batch.items) {
      expect(item.riskLow, lessThanOrEqualTo(item.riskProb), reason: item.id);
      expect(item.riskProb, lessThanOrEqualTo(item.riskHigh), reason: item.id);
    }
  });

  test('actual_exposure_units equals exposure_units when true and 0.0 when false',
      () {
    for (final item in batch.items) {
      final expected =
          item.outcome.exceptionReachedClearance ? item.exposureUnits : 0.0;
      expect(item.outcome.actualExposureUnits, expected, reason: item.id);
    }
  });

  test('model top 5 catches more than largest-exposure top 5', () {
    final model = topFive((a, b) => a.modelRank.compareTo(b.modelRank));
    final largest =
        topFive((a, b) => b.exposureUnits.compareTo(a.exposureUnits));
    expect(caught(model), 4);
    expect(caught(largest), 2);
    expect(caught(model), greaterThan(caught(largest)));
    expect(protected(model), closeTo(1175.1, 0.001));
    expect(protected(largest), closeTo(952.5, 0.001));
  });

  test('model top 5 protects more exposure than highest-probability top 5', () {
    final model = topFive((a, b) => a.modelRank.compareTo(b.modelRank));
    final probable = topFive((a, b) => b.riskProb.compareTo(a.riskProb));
    expect(protected(probable), closeTo(1161.3, 0.001));
    expect(protected(model), greaterThan(protected(probable)));
  });

  test('exactly one item has exposure rank above 15 and model rank at most 5',
      () {
    final surprises = batch.items
        .where((i) => exposureRank(i) > 15 && i.modelRank <= 5)
        .toList();
    expect(surprises.length, 1);
    expect(surprises.single.id, 'PO-4500013302-00010');
    expect(exposureRank(surprises.single), 17);
  });

  test('trap item PO-4500011990-00030 is Low, outcome false and the largest exposure',
      () {
    final trap = batch.items.singleWhere((i) => i.id == 'PO-4500011990-00030');
    expect(trap.riskBand, RiskBand.low);
    expect(trap.outcome.exceptionReachedClearance, isFalse);
    expect(exposureRank(trap), 1);
  });

  test('all proof numbers are placeholders', () {
    expect(batch.proof.isPlaceholder, isTrue);
    expect(batch.proof.kPerDay, 50);
    expect(batch.proof.policies.map((p) => p.name), [
      'Random sampling',
      'Largest amount first',
      'Rules-only (same checkpoint)',
      'LedgerShield',
    ]);
  });

  test('parseBatch throws on duplicate model_rank', () {
    final broken = raw.replaceFirst('"model_rank": 20', '"model_rank": 1');
    expect(broken, isNot(raw));
    expect(() => parseBatch(broken), throwsFormatException);
  });
}
