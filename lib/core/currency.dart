double? parseIndianAmount(String input) {
  final cleaned = input
      .trim()
      .replaceAll('\u20b9', '')
      .replaceAll(',', '')
      .replaceAll(' ', '')
      .replaceAll('\u00a0', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String formatIndianCurrency(num value) {
  final negative = value < 0;
  final absolute = value.abs();
  final fixed = absolute.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final decimals = parts.last;

  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final lastThree = digits.substring(digits.length - 3);
    var leading = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (leading.length > 2) {
      groups.insert(0, leading.substring(leading.length - 2));
      leading = leading.substring(0, leading.length - 2);
    }
    if (leading.isNotEmpty) groups.insert(0, leading);
    grouped = '${groups.join(',')},$lastThree';
  }

  return '${negative ? '-' : ''}\u20b9$grouped.$decimals';
}

String formatIndianCurrencyForPdf(num value) =>
    formatIndianCurrency(value).replaceFirst('\u20b9', 'Rs. ');
