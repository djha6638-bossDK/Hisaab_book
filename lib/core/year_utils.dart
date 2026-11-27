List<int> availableYears({int? currentYear}) {
  final year = currentYear ?? DateTime.now().year;
  final firstYear = year - 10;
  final lastYear = year < 2060 ? 2060 : year;
  return List<int>.generate(
    lastYear - firstYear + 1,
    (index) => firstYear + index,
  );
}
