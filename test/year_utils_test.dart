import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_book/core/year_utils.dart';

void main() {
  test('year selector options include years through 2060', () {
    final years = availableYears(currentYear: 2026);

    expect(years.first, 2016);
    expect(years.last, 2060);
    expect(years, contains(2060));
  });

  test('year selector continues beyond 2060 when needed', () {
    final years = availableYears(currentYear: 2065);

    expect(years.first, 2055);
    expect(years.last, 2065);
  });
}
