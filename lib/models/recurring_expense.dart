import '../core/assignee.dart';

class RecurringExpense {
  const RecurringExpense({
    required this.id,
    required this.name,
    required this.defaultAmount,
    required this.isActive,
    required this.displayOrder,
    this.assignedPersonId,
    this.assignedPersonName,
  });

  final String id;
  final String name;
  final double defaultAmount;
  final bool isActive;
  final int displayOrder;
  final String? assignedPersonId;
  final String? assignedPersonName;

  String get assigneeLabel {
    final personName = assignedPersonName?.trim() ?? '';
    return personName.isEmpty ? defaultAssigneeLabel : personName;
  }

  Map<String, Object> toMap() => <String, Object>{
    'name': name,
    'defaultAmount': defaultAmount,
    'isActive': isActive,
    'displayOrder': displayOrder,
    if (assignedPersonId?.trim().isNotEmpty == true)
      'assignedPersonId': assignedPersonId!.trim(),
    if (assignedPersonName?.trim().isNotEmpty == true)
      'assignedPersonName': assignedPersonName!.trim(),
  };

  factory RecurringExpense.fromMap(String id, Map<String, dynamic> map) {
    return RecurringExpense(
      id: id,
      name: (map['name'] ?? '').toString().trim(),
      defaultAmount: (map['defaultAmount'] as num?)?.toDouble() ?? 0,
      isActive: map['isActive'] != false,
      displayOrder: (map['displayOrder'] as num?)?.toInt() ?? 0,
      assignedPersonId: _optionalString(map['assignedPersonId']),
      assignedPersonName: _optionalString(map['assignedPersonName']),
    );
  }

  RecurringExpense copyWith({
    String? name,
    double? defaultAmount,
    bool? isActive,
    int? displayOrder,
    String? assignedPersonId,
    String? assignedPersonName,
  }) {
    return RecurringExpense(
      id: id,
      name: name ?? this.name,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      assignedPersonId: assignedPersonId ?? this.assignedPersonId,
      assignedPersonName: assignedPersonName ?? this.assignedPersonName,
    );
  }
}

String? _optionalString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
