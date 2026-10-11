import 'package:flutter_test/flutter_test.dart';
import 'package:ledgershield_my/data/models.dart';

Map<String, dynamic> _item({Object exposure = 184.2}) => {
      'id': 'PO-0000000001-00010',
      'vendor': 'V-0001',
      'match_type': '3-way, invoice after goods receipt',
      'exposure_units': exposure,
      'days_to_clearance': 6,
      'risk_prob': 0.81,
      'risk_low': 0.72,
      'risk_high': 0.88,
      'risk_band': 'High',
      'category': 'Missing goods receipt',
      'reason': 'No receipt is recorded yet.',
      'vendor_base_rate': 0.14,
      'what_would_change': 'A goods receipt would drop this to Low.',
      'events': [
        {'label': 'PO created', 'date': '2018-03-02', 'present': true},
        {'label': 'Goods receipt', 'date': null, 'present': false},
      ],
      'model_rank': 2,
      'outcome': {
        'exception_reached_clearance': true,
        'actual_exposure_units': 184,
      },
    };

void main() {
  test('fromJson accepts int exposure_units', () {
    final item = PoItem.fromJson(_item(exposure: 184));
    expect(item.exposureUnits, 184.0);
    expect(item.exposureUnits, isA<double>());
    expect(item.outcome.actualExposureUnits, 184.0);
    expect(item.daysToClearance, 6);
  });

  test('null event date parses as null', () {
    final item = PoItem.fromJson(_item());
    final missing = item.events.last;
    expect(missing.label, 'Goods receipt');
    expect(missing.date, isNull);
    expect(missing.present, isFalse);
    expect(item.events.first.date, '2018-03-02');
  });

  test('enum parse round-trips labels and rejects unknown values', () {
    for (final band in RiskBand.values) {
      expect(RiskBand.parse(band.label), band);
    }
    for (final category in ExceptionCategory.values) {
      expect(ExceptionCategory.parse(category.label), category);
    }
    expect(() => RiskBand.parse('Medium'), throwsFormatException);
    expect(() => ExceptionCategory.parse('Other'), throwsFormatException);
  });

  test('PoItem equality is by id', () {
    final a = PoItem.fromJson(_item());
    final b = PoItem.fromJson(_item(exposure: 1));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('review_capacity_K defaults to 5 when absent', () {
    final meta = BatchMeta.fromJson({
      'checkpoint': 'PO item created + 14 days',
      'units': 'exposure units',
      'split': 'forward-time',
      'model_version': 'test',
    });
    expect(meta.reviewCapacityK, 5);
  });
}
