class PaymentPerson {
  const PaymentPerson({required this.id, required this.name});

  final String id;
  final String name;

  String get normalizedName => name.trim().toLowerCase();

  Map<String, Object> toMap() => <String, Object>{'name': name};

  factory PaymentPerson.fromMap(String id, Map<String, dynamic> map) {
    return PaymentPerson(id: id, name: (map['name'] ?? '').toString().trim());
  }
}
