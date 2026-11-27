import 'package:cloud_firestore/cloud_firestore.dart';

enum CreditCardEntryType {
  spend,
  payment;

  static CreditCardEntryType fromValue(Object? value) {
    return value?.toString() == CreditCardEntryType.payment.name
        ? CreditCardEntryType.payment
        : CreditCardEntryType.spend;
  }
}

class CreditCardEntry {
  const CreditCardEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.createdAt,
  });

  final String id;
  final CreditCardEntryType type;
  final double amount;
  final String description;
  final DateTime date;
  final DateTime? createdAt;

  bool get isPayment => type == CreditCardEntryType.payment;

  double get signedAmount => isPayment ? -amount : amount;

  String get displayDescription {
    final trimmed = description.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return isPayment ? 'Card payment' : 'Card kharch';
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'type': type.name,
    'amount': amount,
    'description': description.trim(),
    'date': creditCardDateId(date),
    'year': date.year,
    'month': date.month,
    'day': date.day,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };

  factory CreditCardEntry.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = (map['date'] ?? '').toString();
    final parsedDate = parseCreditCardDateId(rawDate);
    final fallbackDate = DateTime(
      (map['year'] as num?)?.toInt() ?? 2000,
      (map['month'] as num?)?.toInt() ?? 1,
      (map['day'] as num?)?.toInt() ?? 1,
    );
    return CreditCardEntry(
      id: id,
      type: CreditCardEntryType.fromValue(map['type']),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      description: (map['description'] ?? '').toString().trim(),
      date: parsedDate ?? fallbackDate,
      createdAt: _dateTime(map['createdAt']),
    );
  }

  CreditCardEntry copyWith({
    CreditCardEntryType? type,
    double? amount,
    String? description,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return CreditCardEntry(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

String creditCardDateId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime? parseCreditCardDateId(String id) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(id);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}
