const List<String> monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String monthName(int month) => monthNames[month - 1];

int monthNumber(String month) => monthNames.indexOf(month) + 1;

String monthlyRecordId(int year, int month) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

({int year, int month})? parseMonthlyRecordId(String id) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(id);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  if (year == null || month == null || month < 1 || month > 12) return null;
  return (year: year, month: month);
}

String legacyMonthlyRecordId(int year, int month) =>
    '${monthName(month)}_$year';
