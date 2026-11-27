import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/month_utils.dart';
import 'expense_entry.dart';
import 'income_entry.dart';

class MonthlyRecord {
  const MonthlyRecord({
    required this.id,
    required this.year,
    required this.month,
    required this.incomes,
    required this.expenses,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int year;
  final int month;
  final List<IncomeEntry> incomes;
  final List<ExpenseEntry> expenses;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get totalIncome =>
      incomes.fold(0, (total, entry) => total + entry.amount);
  double get totalExpenses =>
      expenses.fold(0, (total, entry) => total + entry.amount);
  String get label => '${monthName(month)} $year';

  Map<String, Object?> toMap() => <String, Object?>{
    'schemaVersion': 4,
    'year': year,
    'month': month,
    'monthName': monthName(month),
    'incomes': incomes.map((entry) => entry.toMap()).toList(),
    'expenses': expenses.map((entry) => entry.toMap()).toList(),
    'totalIncome': totalIncome,
    'totalExpenses': totalExpenses,
  };

  factory MonthlyRecord.fromMap(String id, Map<String, dynamic> map) {
    final parsedId = parseMonthlyRecordId(id);
    final rawMonth = map['month'];
    final month = rawMonth is num
        ? rawMonth.toInt()
        : monthNumber((map['monthName'] ?? rawMonth ?? '').toString());
    final year = (map['year'] as num?)?.toInt() ?? parsedId?.year ?? 0;
    final rawIncomes = (map['incomes'] as List?) ?? const <Object>[];
    final incomes = rawIncomes
        .whereType<Map>()
        .map((entry) => IncomeEntry.fromMap(Map<String, dynamic>.from(entry)))
        .toList();

    // Original documents stored combined monthly income as totalBalance.
    if (incomes.isEmpty && map['schemaVersion'] == null) {
      final legacyIncome = (map['totalBalance'] as num?)?.toDouble() ?? 0;
      if (legacyIncome > 0) {
        incomes.add(
          IncomeEntry(name: 'Legacy total income', amount: legacyIncome),
        );
      }
    }

    return MonthlyRecord(
      id: parsedId == null && year > 0 && month > 0
          ? monthlyRecordId(year, month)
          : id,
      year: year,
      month: month,
      incomes: incomes,
      expenses: ((map['expenses'] as List?) ?? const <Object>[])
          .whereType<Map>()
          .map(
            (entry) => ExpenseEntry.fromMap(Map<String, dynamic>.from(entry)),
          )
          .where((entry) => entry.name.isNotEmpty)
          .toList(),
      createdAt: _dateTime(map['createdAt'] ?? map['savedAt']),
      updatedAt: _dateTime(map['updatedAt'] ?? map['savedAt']),
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  MonthlyRecord copyWith({
    List<IncomeEntry>? incomes,
    List<ExpenseEntry>? expenses,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlyRecord(
      id: id,
      year: year,
      month: month,
      incomes: incomes ?? this.incomes,
      expenses: expenses ?? this.expenses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
