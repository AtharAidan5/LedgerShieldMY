import 'package:flutter_test/flutter_test.dart';
import 'package:ledgershield_my/util/format.dart';

void main() {
  test('formatPercent renders 0.31 as 31% and 0.14 as 14%', () {
    expect(formatPercent(0.31), '31%');
    expect(formatPercent(0.14), '14%');
    expect(formatPercent(0.0), '0%');
    expect(formatPercent(1.0), '100%');
  });

  test('formatUnits keeps one decimal', () {
    expect(formatUnits(184.2), '184.2');
    expect(formatUnits(1450), '1450.0');
    expect(formatUnits(1175.1), '1175.1');
  });

  test('formatProb keeps two decimals', () {
    expect(formatProb(0.81), '0.81');
    expect(formatProb(0.7), '0.70');
  });

  test('formatDate renders 14 May 2018 and empty for null', () {
    expect(formatDate('2018-05-14'), '14 May 2018');
    expect(formatDate('2018-03-02'), '2 Mar 2018');
    expect(formatDate(null), '');
    expect(formatDate('not a date'), '');
  });

  test('formatTime renders HH:mm:ss', () {
    expect(formatTime(DateTime(2026, 1, 1, 9, 5, 7)), '09:05:07');
    expect(formatTime(DateTime(2026, 1, 1, 23, 59, 59)), '23:59:59');
  });

  test('formatId places a zero-width space after each hyphen', () {
    expect(formatId('PO-4500012402-00010'), 'PO-​4500012402-​00010');
    expect(formatId('nohyphen'), 'nohyphen');
  });
}
