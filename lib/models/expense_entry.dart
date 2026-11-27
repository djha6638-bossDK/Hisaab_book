import '../core/assignee.dart';

class ExpenseEntry {
  const ExpenseEntry({
    required this.name,
    required this.amount,
    this.fromRecurringTemplate = false,
    this.assignedPersonId,
    this.assignedPersonName,
  });

  final String name;
  final double amount;
  final bool fromRecurringTemplate;
  final String? assignedPersonId;
  final String? assignedPersonName;

  String get normalizedName => name.trim().toLowerCase();
  String get assigneeLabel {
    final personName = assignedPersonName?.trim() ?? '';
    return personName.isEmpty ? defaultAssigneeLabel : personName;
  }

  Map<String, Object> toMap() => <String, Object>{
    'name': name,
    'amount': amount,
    'fromRecurringTemplate': fromRecurringTemplate,
    if (assignedPersonId?.trim().isNotEmpty == true)
      'assignedPersonId': assignedPersonId!.trim(),
    if (assignedPersonName?.trim().isNotEmpty == true)
      'assignedPersonName': assignedPersonName!.trim(),
  };

  factory ExpenseEntry.fromMap(Map<String, dynamic> map) {
    return ExpenseEntry(
      name: (map['name'] ?? map['expense'] ?? '').toString().trim(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      fromRecurringTemplate: map['fromRecurringTemplate'] == true,
      assignedPersonId: _optionalString(map['assignedPersonId']),
      assignedPersonName: _optionalString(map['assignedPersonName']),
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
