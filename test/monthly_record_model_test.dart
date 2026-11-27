import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_book/models/expense_entry.dart';
import 'package:hisaab_book/models/income_entry.dart';
import 'package:hisaab_book/models/monthly_record.dart';

void main() {
  test('serializes and deserializes the complete monthly schema', () {
    const record = MonthlyRecord(
      id: '2026-07',
      year: 2026,
      month: 7,
      incomes: <IncomeEntry>[IncomeEntry(name: 'Salary', amount: 50000)],
      expenses: <ExpenseEntry>[
        ExpenseEntry(
          name: 'Rent',
          amount: 12000,
          fromRecurringTemplate: true,
          assignedPersonId: 'rohan',
          assignedPersonName: 'Rohan',
        ),
      ],
    );

    final restored = MonthlyRecord.fromMap(record.id, record.toMap());

    expect(restored.id, '2026-07');
    expect(restored.incomes.single.name, 'Salary');
    expect(restored.expenses.single.fromRecurringTemplate, isTrue);
    expect(restored.expenses.single.assignedPersonId, 'rohan');
    expect(restored.expenses.single.assigneeLabel, 'Rohan');
    expect(restored.totalIncome, 50000);
    expect(restored.totalExpenses, 12000);
    expect(restored.toMap(), isNot(contains('openingBalance')));
    expect(restored.toMap(), isNot(contains('closingBalance')));
  });

  test('reads and normalizes a legacy expense document', () {
    final record = MonthlyRecord.fromMap('June_2026', <String, dynamic>{
      'month': 'June',
      'year': 2026,
      'totalBalance': 50000,
      'expenses': <Map<String, Object>>[
        <String, Object>{'expense': 'Food', 'amount': 5000},
      ],
    });

    expect(record.id, '2026-06');
    expect(record.month, 6);
    expect(record.incomes.single.name, 'Legacy total income');
    expect(record.totalIncome, 50000);
    expect(record.expenses.single.name, 'Food');
    expect(record.expenses.single.assigneeLabel, 'Nishu');
    expect(record.totalExpenses, 5000);
  });
}
