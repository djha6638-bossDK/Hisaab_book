class IncomeEntry {
  const IncomeEntry({required this.name, required this.amount});

  final String name;
  final double amount;

  Map<String, Object> toMap() => <String, Object>{
    'name': name,
    'amount': amount,
  };

  factory IncomeEntry.fromMap(Map<String, dynamic> map) {
    return IncomeEntry(
      name: (map['name'] ?? map['income'] ?? '').toString().trim(),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
