import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_book/models/expense_entry.dart';
import 'package:hisaab_book/models/income_entry.dart';
import 'package:hisaab_book/models/monthly_record.dart';
import 'package:hisaab_book/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = PdfReportService();

  test('generates a PDF for an empty record', () async {
    const record = MonthlyRecord(
      id: '2026-01',
      year: 2026,
      month: 1,
      incomes: <IncomeEntry>[],
      expenses: <ExpenseEntry>[],
    );

    final bytes = await service.buildReport(record);
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('generates a PDF with income and expense data', () async {
    const record = MonthlyRecord(
      id: '2026-02',
      year: 2026,
      month: 2,
      incomes: <IncomeEntry>[IncomeEntry(name: 'Salary', amount: 10000)],
      expenses: <ExpenseEntry>[
        ExpenseEntry(name: 'Food', amount: 1000),
        ExpenseEntry(
          name: 'School fees',
          amount: 2500,
          assignedPersonId: 'rohan',
          assignedPersonName: 'Rohan',
        ),
        ExpenseEntry(
          name: 'Electricity',
          amount: 800,
          assignedPersonId: 'rohan',
          assignedPersonName: 'Rohan',
        ),
        ExpenseEntry(
          name: 'Medicine',
          amount: 500,
          assignedPersonId: 'mohan',
          assignedPersonName: 'Mohan',
        ),
      ],
    );

    final bytes = await service.buildReport(record);
    expect(bytes.length, greaterThan(2000));
  });

  test('paginates a long expense report without throwing', () async {
    final record = MonthlyRecord(
      id: '2026-03',
      year: 2026,
      month: 3,
      incomes: const <IncomeEntry>[IncomeEntry(name: 'Salary', amount: 100000)],
      expenses: List<ExpenseEntry>.generate(
        150,
        (index) => ExpenseEntry(name: 'Expense $index', amount: 10),
      ),
    );

    final bytes = await service.buildReport(record);
    expect(bytes.length, greaterThan(2000));
  });
}
