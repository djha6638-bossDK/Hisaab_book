import '../models/daily_service_attendance.dart';
import '../models/daily_service_settings.dart';

class TuitionAbsenceStatus {
  const TuitionAbsenceStatus({
    required this.date,
    this.compensation = TuitionAbsenceCompensation.none,
  });

  final DateTime date;
  final TuitionAbsenceCompensation compensation;

  bool get compensated => compensation != TuitionAbsenceCompensation.none;

  bool get compensatedByExtra =>
      compensation == TuitionAbsenceCompensation.prepaidExtra;
}

enum TuitionAbsenceCompensation { none, laterOffDay, prepaidExtra }

class DailyServiceMonthSummary {
  const DailyServiceMonthSummary({
    required this.tuitionDays,
    required this.milkDays,
    required this.totalMilkQuantityKg,
    required this.tuitionAmount,
    required this.milkAmount,
    required this.tuitionTeachingDays,
    required this.tuitionDailyRate,
    required this.tuitionAbsences,
    required this.tuitionOffDayAttendances,
    required this.pendingDates,
  });

  final int tuitionDays;
  final int milkDays;
  final double totalMilkQuantityKg;
  final double tuitionAmount;
  final double milkAmount;
  final int tuitionTeachingDays;
  final double tuitionDailyRate;
  final List<TuitionAbsenceStatus> tuitionAbsences;
  final int tuitionOffDayAttendances;
  final List<DateTime> pendingDates;

  int get pendingDays => pendingDates.length;

  double get pendingTuitionAmount => pendingDates.length * tuitionDailyRate;

  int get unpaidTuitionAbsences =>
      tuitionAbsences.where((absence) => !absence.compensated).length;

  double get totalAmount => tuitionAmount + milkAmount;
}

DailyServiceMonthSummary summarizeDailyServices(
  Iterable<DailyServiceAttendance> entries, {
  required int year,
  required int month,
  required DailyServiceSettings settings,
  DateTime? asOfDate,
}) {
  final sortedEntries =
      entries
          .where(
            (entry) => entry.date.year == year && entry.date.month == month,
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final tuitionTeachingDays = daysInMonth;
  final offDayPresentEntries = sortedEntries
      .where(
        (entry) =>
            isTuitionOffDay(entry.date, settings) && entry.tuitionPresent,
      )
      .toList();
  final tuitionOffDayAttendances = offDayPresentEntries.length;

  final tuitionAbsences = <TuitionAbsenceStatus>[];
  final pendingAbsenceIndexes = <int>[];
  var prepaidExtraCredits = 0;
  var tuitionExtraDays = 0;

  for (final entry in sortedEntries) {
    final offDay = isTuitionOffDay(entry.date, settings);
    if (!offDay && !entry.tuitionPresent) {
      final absenceIndex = tuitionAbsences.length;
      if (prepaidExtraCredits > 0) {
        prepaidExtraCredits--;
        tuitionAbsences.add(
          TuitionAbsenceStatus(
            date: entry.date,
            compensation: TuitionAbsenceCompensation.prepaidExtra,
          ),
        );
      } else {
        tuitionAbsences.add(TuitionAbsenceStatus(date: entry.date));
        pendingAbsenceIndexes.add(absenceIndex);
      }
      continue;
    }

    if (!offDay || !entry.tuitionPresent) continue;
    if (pendingAbsenceIndexes.isNotEmpty) {
      final absenceIndex = pendingAbsenceIndexes.removeAt(0);
      tuitionAbsences[absenceIndex] = TuitionAbsenceStatus(
        date: tuitionAbsences[absenceIndex].date,
        compensation: TuitionAbsenceCompensation.laterOffDay,
      );
      tuitionExtraDays++;
      continue;
    }
    if (entry.tuitionExtraConfirmed) {
      prepaidExtraCredits++;
      tuitionExtraDays++;
    }
  }

  final tuitionDailyRate = tuitionTeachingDays == 0
      ? 0.0
      : settings.monthlyTuitionFee / tuitionTeachingDays;
  var tuitionDays = 0;
  var milkDays = 0;
  var totalMilkQuantityKg = 0.0;
  var milkAmount = 0.0;

  for (final entry in sortedEntries) {
    if (isTuitionPaidDay(entry, settings)) tuitionDays++;
    if (entry.milkReceived) {
      milkDays++;
      totalMilkQuantityKg += entry.milkQuantityKg;
    }
    milkAmount += entry.milkAmount;
  }
  tuitionDays += tuitionExtraDays;
  final tuitionAmount = (tuitionDailyRate * tuitionDays)
      .clamp(0.0, double.infinity)
      .toDouble();

  final recordedDays = sortedEntries.map((entry) => entry.date.day).toSet();
  final monthStart = DateTime(year, month, 1);
  final monthEnd = DateTime(year, month, daysInMonth);
  final referenceDate = asOfDate ?? DateTime.now();
  final normalizedReference = DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  );
  var lastRelevantDay = 0;
  if (!normalizedReference.isBefore(monthStart)) {
    lastRelevantDay = normalizedReference.isAfter(monthEnd)
        ? daysInMonth
        : normalizedReference.day;
  }
  final pendingDates = <DateTime>[
    for (var day = 1; day <= lastRelevantDay; day++)
      if (!recordedDays.contains(day)) DateTime(year, month, day),
  ];

  return DailyServiceMonthSummary(
    tuitionDays: tuitionDays,
    milkDays: milkDays,
    totalMilkQuantityKg: totalMilkQuantityKg,
    tuitionAmount: tuitionAmount,
    milkAmount: milkAmount,
    tuitionTeachingDays: tuitionTeachingDays,
    tuitionDailyRate: tuitionDailyRate,
    tuitionAbsences: tuitionAbsences,
    tuitionOffDayAttendances: tuitionOffDayAttendances,
    pendingDates: pendingDates,
  );
}

List<DailyServiceAttendance> effectiveDailyServiceEntries(
  Iterable<DailyServiceAttendance> entries, {
  required int year,
  required int month,
  required DailyServiceSettings settings,
  DateTime? asOfDate,
}) {
  return entries
      .where((entry) => entry.date.year == year && entry.date.month == month)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

bool isTuitionOffDay(DateTime date, DailyServiceSettings settings) =>
    date.weekday == settings.tuitionOffWeekday;

bool isTuitionPaidDay(
  DailyServiceAttendance entry,
  DailyServiceSettings settings,
) => isTuitionOffDay(entry.date, settings) || entry.tuitionPresent;

bool hasUnpaidTuitionAbsenceBefore(
  Iterable<DailyServiceAttendance> entries, {
  required DateTime date,
  required DailyServiceSettings settings,
}) {
  final summary = summarizeDailyServices(
    entries.where((entry) => entry.date.isBefore(date)),
    year: date.year,
    month: date.month,
    settings: settings,
  );
  return summary.unpaidTuitionAbsences > 0;
}
