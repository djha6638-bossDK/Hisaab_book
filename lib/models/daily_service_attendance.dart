class DailyServiceAttendance {
  const DailyServiceAttendance({
    required this.date,
    required this.tuitionPresent,
    required this.milkReceived,
    required this.milkQuantityKg,
    required this.monthlyTuitionFee,
    required this.milkRatePerKg,
    this.tuitionOffWeekday,
    this.tuitionExtraConfirmed = false,
    this.remarks = '',
  });

  final DateTime date;
  final bool tuitionPresent;
  final bool milkReceived;
  final double milkQuantityKg;
  final double monthlyTuitionFee;
  final double milkRatePerKg;
  final int? tuitionOffWeekday;
  final bool tuitionExtraConfirmed;
  final String remarks;

  bool get hasRemarks => remarks.trim().isNotEmpty;

  int get daysInMonth => DateTime(date.year, date.month + 1, 0).day;

  double get tuitionDailyRate => monthlyTuitionFee / daysInMonth;

  double get tuitionAmount => tuitionPresent ? tuitionDailyRate : 0;

  double get milkAmount => milkReceived ? milkQuantityKg * milkRatePerKg : 0;

  double get totalAmount => tuitionAmount + milkAmount;

  Map<String, Object> toMap() => <String, Object>{
    'date': dailyAttendanceId(date),
    'year': date.year,
    'month': date.month,
    'day': date.day,
    'tuitionPresent': tuitionPresent,
    'milkReceived': milkReceived,
    'milkQuantityKg': milkQuantityKg,
    'monthlyTuitionFee': monthlyTuitionFee,
    'milkRatePerKg': milkRatePerKg,
    'tuitionOffWeekday': ?tuitionOffWeekday,
    'tuitionExtraConfirmed': tuitionExtraConfirmed,
    'remarks': remarks.trim(),
  };

  factory DailyServiceAttendance.fromMap(String id, Map<String, dynamic> map) {
    final parsedDate = parseDailyAttendanceId((map['date'] ?? id).toString());
    final fallbackDate = DateTime(
      (map['year'] as num?)?.toInt() ?? 2000,
      (map['month'] as num?)?.toInt() ?? 1,
      (map['day'] as num?)?.toInt() ?? 1,
    );
    return DailyServiceAttendance(
      date: parsedDate ?? fallbackDate,
      tuitionPresent: map['tuitionPresent'] == true,
      milkReceived: map['milkReceived'] == true,
      milkQuantityKg: (map['milkQuantityKg'] as num?)?.toDouble() ?? 0,
      monthlyTuitionFee: (map['monthlyTuitionFee'] as num?)?.toDouble() ?? 0,
      milkRatePerKg: (map['milkRatePerKg'] as num?)?.toDouble() ?? 0,
      tuitionOffWeekday: (map['tuitionOffWeekday'] as num?)?.toInt(),
      tuitionExtraConfirmed: map['tuitionExtraConfirmed'] == true,
      remarks: map['remarks']?.toString() ?? '',
    );
  }
}

String dailyAttendanceId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime? parseDailyAttendanceId(String id) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(id);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
