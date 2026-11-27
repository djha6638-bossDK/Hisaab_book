import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_book/domain/monthly_record_logic.dart';
import 'package:hisaab_book/models/expense_entry.dart';
import 'package:hisaab_book/models/income_entry.dart';
import 'package:hisaab_book/models/recurring_expense.dart';

void main() {
  group('monthly calculations', () {
    test('calculates income and expenses', () {
      const incomes = <IncomeEntry>[
        IncomeEntry(name: 'Salary', amount: 50000),
        IncomeEntry(name: 'Interest', amount: 500),
      ];
      const expenses = <ExpenseEntry>[
        ExpenseEntry(name: 'Rent', amount: 12000),
        ExpenseEntry(name: 'Food', amount: 8000),
      ];

      expect(incomeTotal(incomes), 50500);
      expect(expenseTotal(expenses), 20000);
    });

    test('groups expenses by assigned payment person', () {
      final allocations = expenseAllocations(const <ExpenseEntry>[
        ExpenseEntry(name: 'Milk', amount: 1000),
        ExpenseEntry(
          name: 'Rent',
          amount: 3000,
          assignedPersonId: 'rohan',
          assignedPersonName: 'Rohan',
        ),
        ExpenseEntry(
          name: 'School',
          amount: 4000,
          assignedPersonId: 'rohan',
          assignedPersonName: 'Rohan',
        ),
      ]);

      expect(allocations, hasLength(2));
      expect(allocations.first.label, 'Nishu');
      expect(allocations.first.expenseCount, 1);
      expect(allocations.first.amount, 1000);
      expect(allocations.last.label, 'Rohan');
      expect(allocations.last.expenseCount, 2);
      expect(allocations.last.amount, 7000);
    });
  });

  group('recurring behavior', () {
    test('prefills only active recurring entries in display order', () {
      final result = activeRecurringExpenses(const <RecurringExpense>[
        RecurringExpense(
          id: '2',
          name: 'Second',
          defaultAmount: 2,
          isActive: true,
          displayOrder: 2,
        ),
        RecurringExpense(
          id: 'off',
          name: 'Inactive',
          defaultAmount: 9,
          isActive: false,
          displayOrder: 0,
        ),
        RecurringExpense(
          id: '1',
          name: 'First',
          defaultAmount: 1,
          isActive: true,
          displayOrder: 1,
        ),
      ]);

      expect(result.map((entry) => entry.name), <String>['First', 'Second']);
      expect(result.first.amount, 1);
      expect(result.first.fromRecurringTemplate, isTrue);
    });

    test('monthly snapshot does not change with a later template update', () {
      const template = RecurringExpense(
        id: 'rent',
        name: 'Rent',
        defaultAmount: 100,
        isActive: true,
        displayOrder: 0,
      );
      final snapshot = activeRecurringExpenses(<RecurringExpense>[template]);
      final changed = template.copyWith(defaultAmount: 200);

      expect(changed.defaultAmount, 200);
      expect(snapshot.single.amount, 100);
    });
  });

  group('validation', () {
    test('ignores empty rows and accepts valid rows', () {
      final result = validateExpenseRows(const <
        ({
          String name,
          String amount,
          bool fromRecurring,
          String? assignedPersonId,
          String? assignedPersonName,
        })
      >[
        (
          name: '',
          amount: '',
          fromRecurring: false,
          assignedPersonId: null,
          assignedPersonName: null,
        ),
        (
          name: 'Food',
          amount: '250.50',
          fromRecurring: false,
          assignedPersonId: 'rohan',
          assignedPersonName: 'Rohan',
        ),
      ]);

      expect(result.isValid, isTrue);
      expect(result.value.single.amount, 250.5);
      expect(result.value.single.assigneeLabel, 'Rohan');
    });

    test('rejects missing names, invalid numbers, and negatives', () {
      final result = validateExpenseRows(const <
        ({
          String name,
          String amount,
          bool fromRecurring,
          String? assignedPersonId,
          String? assignedPersonName,
        })
      >[
        (
          name: '',
          amount: '10',
          fromRecurring: false,
          assignedPersonId: null,
          assignedPersonName: null,
        ),
        (
          name: 'Bad',
          amount: 'abc',
          fromRecurring: false,
          assignedPersonId: null,
          assignedPersonName: null,
        ),
        (
          name: 'Negative',
          amount: '-1',
          fromRecurring: false,
          assignedPersonId: null,
          assignedPersonName: null,
        ),
      ]);

      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(3));
    });

    test('validates income rows', () {
      final result = validateIncomeRows(const <({String name, String amount})>[
        (name: '', amount: ''),
        (name: 'Salary', amount: '50000'),
      ]);

      expect(result.isValid, isTrue);
      expect(result.value.single.name, 'Salary');
    });
  });
}
