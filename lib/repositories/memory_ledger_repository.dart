import '../models/credit_card_entry.dart';
import '../models/daily_service_attendance.dart';
import '../models/daily_service_settings.dart';
import '../models/monthly_record.dart';
import '../models/payment_person.dart';
import '../models/recurring_expense.dart';
import 'ledger_repository.dart';

class MemoryLedgerRepository implements LedgerRepository {
  MemoryLedgerRepository({
    Iterable<MonthlyRecord> records = const <MonthlyRecord>[],
    Iterable<RecurringExpense> recurringExpenses = const <RecurringExpense>[],
    Iterable<PaymentPerson> paymentPeople = const <PaymentPerson>[],
    DailyServiceSettings? initialDailyServiceSettings,
    Iterable<DailyServiceAttendance> dailyServiceAttendance =
        const <DailyServiceAttendance>[],
    Map<String, DailyServiceSettings> dailyServiceMonthSettings =
        const <String, DailyServiceSettings>{},
    Iterable<CreditCardEntry> creditCardEntries = const <CreditCardEntry>[],
  }) : _records = {for (final record in records) record.id: record},
       _recurring = {
         for (final expense in recurringExpenses) expense.id: expense,
       },
       _paymentPeople = {for (final person in paymentPeople) person.id: person},
       _dailyServiceSettings = initialDailyServiceSettings,
       _dailyServiceMonthSettings = Map<String, DailyServiceSettings>.from(
         dailyServiceMonthSettings,
       ),
       _dailyServiceAttendance = {
         for (final entry in dailyServiceAttendance)
           dailyAttendanceId(entry.date): entry,
       },
       _creditCardEntries = {
         for (final entry in creditCardEntries) entry.id: entry,
       };

  final Map<String, MonthlyRecord> _records;
  final Map<String, RecurringExpense> _recurring;
  final Map<String, PaymentPerson> _paymentPeople;
  DailyServiceSettings? _dailyServiceSettings;
  final Map<String, DailyServiceSettings> _dailyServiceMonthSettings;
  final Map<String, DailyServiceAttendance> _dailyServiceAttendance;
  final Map<String, CreditCardEntry> _creditCardEntries;

  @override
  Future<DailyServiceAttendance?> getDailyServiceAttendance(
    DateTime date,
  ) async => _dailyServiceAttendance[dailyAttendanceId(date)];

  @override
  Future<DailyServiceSettings?> getDailyServiceSettings() async =>
      _dailyServiceSettings;

  @override
  Future<void> deleteRecurringExpense(String id) async {
    _recurring.remove(id);
  }

  @override
  Future<void> deleteMonthlyRecord(String id) async {
    _records.remove(id);
  }

  @override
  Future<void> deletePaymentPerson(String id) async {
    _paymentPeople.remove(id);
  }

  @override
  Future<DailyServiceSettings?> getDailyServiceMonthSettings(
    int year,
    int month,
  ) async =>
      _dailyServiceMonthSettings['${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}'];

  @override
  Future<void> saveDailyServiceMonthSettings(
    int year,
    int month,
    DailyServiceSettings settings,
  ) async {
    _dailyServiceMonthSettings['${year.toString().padLeft(4, '0')}-'
            '${month.toString().padLeft(2, '0')}'] =
        settings;
  }

  @override
  Future<MonthlyRecord?> getMonthlyRecord(int year, int month) async {
    return _records['${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}'];
  }

  @override
  Future<List<MonthlyRecord>> listMonthlyRecords() async {
    final values = _records.values.toList()
      ..sort((a, b) {
        final year = a.year.compareTo(b.year);
        return year != 0 ? year : a.month.compareTo(b.month);
      });
    return values;
  }

  @override
  Future<List<DailyServiceAttendance>> listDailyServiceAttendance(
    int year,
    int month,
  ) async {
    final values =
        _dailyServiceAttendance.values
            .where(
              (entry) => entry.date.year == year && entry.date.month == month,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return values;
  }

  @override
  Future<List<PaymentPerson>> listPaymentPeople() async {
    final values = _paymentPeople.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  @override
  Future<List<RecurringExpense>> listRecurringExpenses() async {
    final values = _recurring.values.toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return values;
  }

  @override
  Future<void> saveMonthlyRecord(
    MonthlyRecord record, {
    required bool overwrite,
  }) async {
    if (_records.containsKey(record.id) && !overwrite) {
      throw const MonthlyRecordAlreadyExistsException();
    }
    _records[record.id] = record;
  }

  @override
  Future<PaymentPerson> savePaymentPerson(PaymentPerson person) async {
    final id = person.id.isEmpty
        ? 'person-${_paymentPeople.length + 1}'
        : person.id;
    final saved = PaymentPerson(id: id, name: person.name);
    _paymentPeople[id] = saved;
    return saved;
  }

  @override
  Future<void> saveDailyServiceAttendance(
    DailyServiceAttendance attendance,
  ) async {
    _dailyServiceAttendance[dailyAttendanceId(attendance.date)] = attendance;
  }

  @override
  Future<void> saveDailyServiceSettings(DailyServiceSettings settings) async {
    _dailyServiceSettings = settings;
  }

  @override
  Future<void> saveRecurringExpense(RecurringExpense expense) async {
    final id = expense.id.isEmpty
        ? 'recurring-${_recurring.length + 1}'
        : expense.id;
    _recurring[id] = RecurringExpense(
      id: id,
      name: expense.name,
      defaultAmount: expense.defaultAmount,
      isActive: expense.isActive,
      displayOrder: expense.displayOrder,
      assignedPersonId: expense.assignedPersonId,
      assignedPersonName: expense.assignedPersonName,
    );
  }

  @override
  Future<List<CreditCardEntry>> listCreditCardEntries() async {
    final values = _creditCardEntries.values.toList()
      ..sort((a, b) {
        final dateOrder = b.date.compareTo(a.date);
        if (dateOrder != 0) return dateOrder;
        final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bCreated.compareTo(aCreated);
      });
    return values;
  }

  @override
  Future<CreditCardEntry> saveCreditCardEntry(CreditCardEntry entry) async {
    final id = entry.id.isEmpty
        ? 'credit-${DateTime.now().microsecondsSinceEpoch}'
        : entry.id;
    final saved = CreditCardEntry(
      id: id,
      type: entry.type,
      amount: entry.amount,
      description: entry.description,
      date: entry.date,
      createdAt: entry.createdAt ?? DateTime.now(),
    );
    _creditCardEntries[id] = saved;
    return saved;
  }

  @override
  Future<void> deleteCreditCardEntry(String id) async {
    _creditCardEntries.remove(id);
  }
}
