import '../models/credit_card_entry.dart';
import '../models/daily_service_attendance.dart';
import '../models/daily_service_settings.dart';
import '../models/monthly_record.dart';
import '../models/payment_person.dart';
import '../models/recurring_expense.dart';

abstract class LedgerRepository {
  Future<List<MonthlyRecord>> listMonthlyRecords();

  Future<MonthlyRecord?> getMonthlyRecord(int year, int month);

  Future<void> saveMonthlyRecord(
    MonthlyRecord record, {
    required bool overwrite,
  });

  Future<void> deleteMonthlyRecord(String id);

  Future<List<RecurringExpense>> listRecurringExpenses();

  Future<void> saveRecurringExpense(RecurringExpense expense);

  Future<void> deleteRecurringExpense(String id);

  Future<List<PaymentPerson>> listPaymentPeople();

  Future<PaymentPerson> savePaymentPerson(PaymentPerson person);

  Future<void> deletePaymentPerson(String id);

  Future<DailyServiceSettings?> getDailyServiceSettings();

  Future<void> saveDailyServiceSettings(DailyServiceSettings settings);

  Future<DailyServiceSettings?> getDailyServiceMonthSettings(
    int year,
    int month,
  );

  Future<void> saveDailyServiceMonthSettings(
    int year,
    int month,
    DailyServiceSettings settings,
  );

  Future<DailyServiceAttendance?> getDailyServiceAttendance(DateTime date);

  Future<List<DailyServiceAttendance>> listDailyServiceAttendance(
    int year,
    int month,
  );

  Future<void> saveDailyServiceAttendance(DailyServiceAttendance attendance);

  Future<List<CreditCardEntry>> listCreditCardEntries();

  Future<CreditCardEntry> saveCreditCardEntry(CreditCardEntry entry);

  Future<void> deleteCreditCardEntry(String id);
}

class MonthlyRecordAlreadyExistsException implements Exception {
  const MonthlyRecordAlreadyExistsException();
}
