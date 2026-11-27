import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/month_utils.dart';
import '../models/daily_service_attendance.dart';
import '../models/daily_service_settings.dart';
import '../models/monthly_record.dart';
import '../models/payment_person.dart';
import '../models/recurring_expense.dart';
import 'ledger_repository.dart';

class FirestoreLedgerRepository implements LedgerRepository {
  FirestoreLedgerRepository({required this.firestore, required this.userId});

  final FirebaseFirestore firestore;
  final String userId;

  DocumentReference<Map<String, dynamic>> get _userDocument =>
      firestore.collection('users').doc(userId);

  CollectionReference<Map<String, dynamic>> get _monthlyRecords =>
      _userDocument.collection('monthlyRecords');

  CollectionReference<Map<String, dynamic>> get _legacyExpenses =>
      _userDocument.collection('expenses');

  CollectionReference<Map<String, dynamic>> get _recurringExpenses =>
      _userDocument.collection('recurringExpenses');

  CollectionReference<Map<String, dynamic>> get _paymentPeople =>
      _userDocument.collection('paymentPeople');

  DocumentReference<Map<String, dynamic>> get _dailyServiceSettings =>
      _userDocument.collection('settings').doc('dailyServices');

  CollectionReference<Map<String, dynamic>> get _dailyServiceMonthSettings =>
      _userDocument.collection('dailyServiceMonthSettings');

  CollectionReference<Map<String, dynamic>> get _dailyServiceAttendance =>
      _userDocument.collection('dailyServiceAttendance');

  @override
  Future<DailyServiceAttendance?> getDailyServiceAttendance(
    DateTime date,
  ) async {
    final id = dailyAttendanceId(date);
    final snapshot = await _dailyServiceAttendance.doc(id).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return DailyServiceAttendance.fromMap(id, snapshot.data()!);
  }

  @override
  Future<DailyServiceSettings?> getDailyServiceSettings() async {
    final snapshot = await _dailyServiceSettings.get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return DailyServiceSettings.fromMap(snapshot.data()!);
  }

  @override
  Future<DailyServiceSettings?> getDailyServiceMonthSettings(
    int year,
    int month,
  ) async {
    final snapshot = await _dailyServiceMonthSettings
        .doc(monthlyRecordId(year, month))
        .get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return DailyServiceSettings.fromMap(snapshot.data()!);
  }

  @override
  Future<void> saveDailyServiceMonthSettings(
    int year,
    int month,
    DailyServiceSettings settings,
  ) {
    return _dailyServiceMonthSettings
        .doc(monthlyRecordId(year, month))
        .set(<String, Object?>{
          ...settings.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Future<List<MonthlyRecord>> listMonthlyRecords() async {
    final snapshots = await Future.wait(
      <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _monthlyRecords.get(),
        _legacyExpenses.get(),
      ],
    );
    final canonicalSnapshot = snapshots[0];
    final legacySnapshot = snapshots[1];
    final records = <String, MonthlyRecord>{};
    for (final document in canonicalSnapshot.docs) {
      final record = MonthlyRecord.fromMap(document.id, document.data());
      if (_isValid(record)) records[record.id] = record;
    }

    final migrations = <Future<void>>[];
    for (final document in legacySnapshot.docs) {
      final legacy = MonthlyRecord.fromMap(document.id, document.data());
      if (!_isValid(legacy) || records.containsKey(legacy.id)) continue;
      records[legacy.id] = legacy;
      migrations.add(_migrateLegacyRecord(legacy));
    }
    await Future.wait(migrations);

    final sorted = records.values.toList()
      ..sort((a, b) {
        final year = a.year.compareTo(b.year);
        return year != 0 ? year : a.month.compareTo(b.month);
      });
    return sorted;
  }

  @override
  Future<List<DailyServiceAttendance>> listDailyServiceAttendance(
    int year,
    int month,
  ) async {
    final snapshot = await _dailyServiceAttendance
        .where('year', isEqualTo: year)
        .where('month', isEqualTo: month)
        .get();
    final entries =
        snapshot.docs
            .map(
              (document) =>
                  DailyServiceAttendance.fromMap(document.id, document.data()),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  @override
  Future<List<PaymentPerson>> listPaymentPeople() async {
    final snapshot = await _paymentPeople.get();
    final people =
        snapshot.docs
            .map((doc) => PaymentPerson.fromMap(doc.id, doc.data()))
            .where((person) => person.name.isNotEmpty)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return people;
  }

  @override
  Future<MonthlyRecord?> getMonthlyRecord(int year, int month) async {
    final id = monthlyRecordId(year, month);
    final canonical = await _monthlyRecords.doc(id).get();
    if (canonical.exists && canonical.data() != null) {
      final record = MonthlyRecord.fromMap(id, canonical.data()!);
      return _isValid(record) ? record : null;
    }

    final legacy = await _legacyExpenses
        .doc(legacyMonthlyRecordId(year, month))
        .get();
    if (!legacy.exists || legacy.data() == null) return null;
    final record = MonthlyRecord.fromMap(legacy.id, legacy.data()!);
    if (!_isValid(record)) return null;
    await _migrateLegacyRecord(record);
    return record;
  }

  @override
  Future<void> saveMonthlyRecord(
    MonthlyRecord record, {
    required bool overwrite,
  }) async {
    final reference = _monthlyRecords.doc(record.id);
    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists && !overwrite) {
        throw const MonthlyRecordAlreadyExistsException();
      }
      final data = record.toMap();
      data['updatedAt'] = FieldValue.serverTimestamp();
      if (!existing.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(reference, data, SetOptions(merge: overwrite));
    });
  }

  @override
  Future<void> deleteMonthlyRecord(String id) =>
      _monthlyRecords.doc(id).delete();

  @override
  Future<void> deletePaymentPerson(String id) =>
      _paymentPeople.doc(id).delete();

  @override
  Future<PaymentPerson> savePaymentPerson(PaymentPerson person) async {
    final reference = person.id.isEmpty
        ? _paymentPeople.doc()
        : _paymentPeople.doc(person.id);
    final saved = PaymentPerson(id: reference.id, name: person.name.trim());
    await reference.set(<String, Object?>{
      ...saved.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return saved;
  }

  @override
  Future<void> saveDailyServiceAttendance(DailyServiceAttendance attendance) {
    return _dailyServiceAttendance.doc(dailyAttendanceId(attendance.date)).set(
      <String, Object?>{
        ...attendance.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> saveDailyServiceSettings(DailyServiceSettings settings) {
    return _dailyServiceSettings.set(<String, Object?>{
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<RecurringExpense>> listRecurringExpenses() async {
    final snapshot = await _recurringExpenses.get();
    final entries =
        snapshot.docs
            .map((doc) => RecurringExpense.fromMap(doc.id, doc.data()))
            .where((entry) => entry.name.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final order = a.displayOrder.compareTo(b.displayOrder);
            return order != 0 ? order : a.name.compareTo(b.name);
          });
    return entries;
  }

  @override
  Future<void> saveRecurringExpense(RecurringExpense expense) async {
    final reference = expense.id.isEmpty
        ? _recurringExpenses.doc()
        : _recurringExpenses.doc(expense.id);
    await reference.set(<String, Object?>{
      ...expense.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteRecurringExpense(String id) =>
      _recurringExpenses.doc(id).delete();

  Future<void> _migrateLegacyRecord(MonthlyRecord record) async {
    final reference = _monthlyRecords.doc(record.id);
    final data = record.toMap()
      ..['createdAt'] = record.createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(record.createdAt!)
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..['migratedFromLegacy'] = true;
    await reference.set(data, SetOptions(merge: false));
  }

  bool _isValid(MonthlyRecord record) =>
      record.year >= 2000 && record.month >= 1 && record.month <= 12;
}
