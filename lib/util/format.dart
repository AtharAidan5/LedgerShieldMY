/// Number, date and time formatting shared by every screen.
library;

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Exposure units with one decimal, for example `184.2`.
String formatUnits(double v) => v.toStringAsFixed(1);

/// Probabilities with two decimals, for example `0.81`.
String formatProb(double v) => v.toStringAsFixed(2);

/// A 0..1 rate as a whole percent, so `0.31` renders `31%`.
String formatPercent(double v) => '${(v * 100).round()}%';

/// Renders a raw `yyyy-MM-dd` string as `14 May 2018`. A null or malformed
/// value renders as an empty string; callers decide what to show instead.
String formatDate(String? iso) {
  if (iso == null) return '';
  final parts = iso.split('-');
  if (parts.length != 3) return '';
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return '';
  if (month < 1 || month > 12) return '';
  return '$day ${_months[month - 1]} $year';
}

/// Local wall-clock time as `HH:mm:ss`, for the audit log.
String formatTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// An item id prepared for display in a narrow column. ICU line breaking
/// never breaks between a hyphen and a digit, so a zero-width space is placed
/// after each hyphen; the id then wraps as `PO-4500012402-` / `00010` instead
/// of being cut. Use the raw id for semantics labels and anywhere the text is
/// compared or copied.
String formatId(String id) => id.replaceAll('-', '-\u200B');
