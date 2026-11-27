import '../core/assignee.dart';
import '../core/currency.dart';
import '../models/expense_entry.dart';
import '../models/income_entry.dart';
import '../models/recurring_expense.dart';

class ValidationResult<T> {
  const ValidationResult({required this.value, required this.errors});

  final T value;
  final List<String> errors;
  bool get isValid => errors.isEmpty;
}

class ExpenseAllocation {
  const ExpenseAllocation({
    required this.key,
    required this.label,
    required this.expenseCount,
    required this.amount,
  });

  final String key;
  final String label;
  final int expenseCount;
  final double amount;
}

double incomeTotal(Iterable<IncomeEntry> incomes) =>
    incomes.fold(0, (total, entry) => total + entry.amount);

double expenseTotal(Iterable<ExpenseEntry> expenses) =>
    expenses.fold(0, (total, entry) => total + entry.amount);

List<ExpenseAllocation> expenseAllocations(Iterable<ExpenseEntry> expenses) {
  final grouped = <String, ExpenseAllocation>{};
  for (final expense in expenses) {
    final personId = expense.assignedPersonId?.trim() ?? '';
    final personName = expense.assignedPersonName?.trim() ?? '';
    final key = personName.isEmpty
        ? defaultAssigneeKey
        : personId.isNotEmpty
        ? 'person:$personId'
        : 'name:${personName.toLowerCase()}';
    final label = personName.isEmpty ? defaultAssigneeLabel : personName;
    final existing = grouped[key];
    grouped[key] = ExpenseAllocation(
      key: key,
      label: label,
      expenseCount: (existing?.expenseCount ?? 0) + 1,
      amount: (existing?.amount ?? 0) + expense.amount,
    );
  }

  final allocations = grouped.values.toList()
    ..sort((a, b) {
      if (a.key == defaultAssigneeKey) return -1;
      if (b.key == defaultAssigneeKey) return 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  return allocations;
}

List<ExpenseEntry> activeRecurringExpenses(
  Iterable<RecurringExpense> templates,
) {
  final active = templates.where((template) => template.isActive).toList()
    ..sort((a, b) {
      final order = a.displayOrder.compareTo(b.displayOrder);
      return order != 0 ? order : a.name.compareTo(b.name);
    });
  return active
      .map(
        (template) => ExpenseEntry(
          name: template.name,
          amount: template.defaultAmount,
          fromRecurringTemplate: true,
          assignedPersonId: template.assignedPersonId,
          assignedPersonName: template.assignedPersonName,
        ),
      )
      .toList();
}

ValidationResult<List<IncomeEntry>> validateIncomeRows(
  Iterable<({String name, String amount})> rows,
) {
  final entries = <IncomeEntry>[];
  final errors = <String>[];
  for (final row in rows) {
    final name = row.name.trim();
    final amountText = row.amount.trim();
    if (name.isEmpty && amountText.isEmpty) continue;
    final amount = parseIndianAmount(amountText);
    if (name.isEmpty) {
      errors.add('Income ka naam bharo.');
    } else if (amount == null) {
      errors.add('$name ke liye sahi rakam bharo.');
    } else if (amount < 0) {
      errors.add('$name ki income negative nahi ho sakti.');
    } else {
      entries.add(IncomeEntry(name: name, amount: amount));
    }
  }
  return ValidationResult(value: entries, errors: errors);
}

ValidationResult<List<ExpenseEntry>> validateExpenseRows(
  Iterable<
    ({
      String name,
      String amount,
      bool fromRecurring,
      String? assignedPersonId,
      String? assignedPersonName,
    })
  >
  rows,
) {
  final entries = <ExpenseEntry>[];
  final errors = <String>[];
  for (final row in rows) {
    final name = row.name.trim();
    final amountText = row.amount.trim();
    if (name.isEmpty && amountText.isEmpty) continue;
    final amount = parseIndianAmount(amountText);
    if (name.isEmpty) {
      errors.add('Kharch ka naam bharo.');
    } else if (amount == null) {
      errors.add('$name ke liye sahi rakam bharo.');
    } else if (amount < 0) {
      errors.add('$name ka kharcha negative nahi ho sakta.');
    } else {
      entries.add(
        ExpenseEntry(
          name: name,
          amount: amount,
          fromRecurringTemplate: row.fromRecurring,
          assignedPersonId: row.assignedPersonId,
          assignedPersonName: row.assignedPersonName,
        ),
      );
    }
  }
  return ValidationResult(value: entries, errors: errors);
}
