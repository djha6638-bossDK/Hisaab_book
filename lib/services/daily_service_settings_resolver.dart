import '../models/daily_service_attendance.dart';
import '../models/daily_service_settings.dart';
import '../repositories/ledger_repository.dart';

/// Returns the settings that belong to a specific month.
///
/// The first time a month is used, its snapshot is created. After that,
/// changing the global settings only affects the current month and future
/// months, so old totals stay exactly as they were.
Future<DailyServiceSettings?> resolveDailyServiceMonthSettings({
  required LedgerRepository repository,
  required int year,
  required int month,
  List<DailyServiceAttendance>? entries,
}) async {
  final saved = await repository.getDailyServiceMonthSettings(year, month);
  if (saved != null) return saved;

  final current = await repository.getDailyServiceSettings();
  if (current == null) return null;

  final monthEntries =
      entries ??
      await repository.listDailyServiceAttendance(year, month);
  final firstEntry = monthEntries.isEmpty ? null : monthEntries.first;
  final snapshot = DailyServiceSettings(
    monthlyTuitionFee:
        firstEntry?.monthlyTuitionFee ?? current.monthlyTuitionFee,
    milkRatePerKg: firstEntry?.milkRatePerKg ?? current.milkRatePerKg,
    defaultMilkQuantityKg: current.defaultMilkQuantityKg,
    tuitionOffWeekday:
        firstEntry?.tuitionOffWeekday ?? current.tuitionOffWeekday,
  );
  await repository.saveDailyServiceMonthSettings(year, month, snapshot);
  return snapshot;
}
