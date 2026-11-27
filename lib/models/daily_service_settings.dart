class DailyServiceSettings {
  const DailyServiceSettings({
    required this.monthlyTuitionFee,
    required this.milkRatePerKg,
    required this.defaultMilkQuantityKg,
    this.tuitionOffWeekday = DateTime.sunday,
  });

  final double monthlyTuitionFee;
  final double milkRatePerKg;
  final double defaultMilkQuantityKg;
  final int tuitionOffWeekday;

  DailyServiceSettings copyWith({
    double? monthlyTuitionFee,
    double? milkRatePerKg,
    double? defaultMilkQuantityKg,
    int? tuitionOffWeekday,
  }) {
    return DailyServiceSettings(
      monthlyTuitionFee: monthlyTuitionFee ?? this.monthlyTuitionFee,
      milkRatePerKg: milkRatePerKg ?? this.milkRatePerKg,
      defaultMilkQuantityKg: defaultMilkQuantityKg ?? this.defaultMilkQuantityKg,
      tuitionOffWeekday: tuitionOffWeekday ?? this.tuitionOffWeekday,
    );
  }

  Map<String, Object> toMap() => <String, Object>{
    'monthlyTuitionFee': monthlyTuitionFee,
    'milkRatePerKg': milkRatePerKg,
    'defaultMilkQuantityKg': defaultMilkQuantityKg,
    'tuitionOffWeekday': tuitionOffWeekday,
  };

  factory DailyServiceSettings.fromMap(Map<String, dynamic> map) {
    final savedOffWeekday = (map['tuitionOffWeekday'] as num?)?.toInt();
    return DailyServiceSettings(
      monthlyTuitionFee: (map['monthlyTuitionFee'] as num?)?.toDouble() ?? 0,
      milkRatePerKg: (map['milkRatePerKg'] as num?)?.toDouble() ?? 0,
      defaultMilkQuantityKg:
          (map['defaultMilkQuantityKg'] as num?)?.toDouble() ?? 0,
      tuitionOffWeekday:
          savedOffWeekday != null &&
              savedOffWeekday >= DateTime.monday &&
              savedOffWeekday <= DateTime.sunday
          ? savedOffWeekday
          : DateTime.sunday,
    );
  }
}
