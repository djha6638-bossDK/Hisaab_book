import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_book/domain/daily_service_logic.dart';
import 'package:hisaab_book/models/daily_service_attendance.dart';
import 'package:hisaab_book/models/daily_service_settings.dart';

void main() {
  test('daily service settings preserve and default the tuition off day', () {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 2600,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.friday,
    );

    expect(
      DailyServiceSettings.fromMap(settings.toMap()).tuitionOffWeekday,
      DateTime.friday,
    );
    expect(
      DailyServiceSettings.fromMap(const <String, dynamic>{
        'monthlyTuitionFee': 2600,
        'milkRatePerKg': 60,
        'defaultMilkQuantityKg': 1.5,
      }).tuitionOffWeekday,
      DateTime.sunday,
    );
  });

  test('daily attendance remarks serialize and detect non-empty notes', () {
    final attendance = DailyServiceAttendance(
      date: DateTime(2026, 8, 5),
      tuitionPresent: true,
      milkReceived: true,
      milkQuantityKg: 1.5,
      monthlyTuitionFee: 3100,
      milkRatePerKg: 60,
      remarks: '  Milk arrived late.  ',
    );

    final restored = DailyServiceAttendance.fromMap(
      dailyAttendanceId(attendance.date),
      attendance.toMap(),
    );

    expect(restored.remarks, 'Milk arrived late.');
    expect(restored.hasRemarks, isTrue);
    expect(restored.tuitionExtraConfirmed, isFalse);
    expect(
      DailyServiceAttendance.fromMap(
        '2026-08-05',
        <String, dynamic>{},
      ).hasRemarks,
      isFalse,
    );
  });

  test('empty month has zero totals until attendance is saved', () {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 2600,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.sunday,
    );

    final summary = summarizeDailyServices(
      const <DailyServiceAttendance>[],
      year: 2026,
      month: 8,
      settings: settings,
      asOfDate: DateTime(2026, 8, 31),
    );

    expect(summary.tuitionDays, 0);
    expect(summary.milkDays, 0);
    expect(summary.totalMilkQuantityKg, 0);
    expect(summary.tuitionAmount, 0);
    expect(summary.milkAmount, 0);
    expect(summary.tuitionAbsences, isEmpty);
    expect(summary.tuitionOffDayAttendances, 0);
  });

  test('saved tuition off day is paid and is not an absence', () {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 3100,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.monday,
    );
    final offDay = DateTime(2026, 8, 3);

    final summary = summarizeDailyServices(
      <DailyServiceAttendance>[
        _attendance(offDay, tuitionPresent: false, milkReceived: true),
        _attendance(
          DateTime(2026, 8, 4),
          tuitionPresent: false,
          milkReceived: false,
        ),
      ],
      year: 2026,
      month: 8,
      settings: settings,
      asOfDate: DateTime(2026, 8, 4),
    );

    expect(summary.tuitionDays, 1);
    expect(summary.tuitionOffDayAttendances, 0);
    expect(summary.tuitionAbsences.single.date, DateTime(2026, 8, 4));
    expect(summary.tuitionAmount, closeTo(3100 / 31, 0.000001));
  });

  test('off-day presence compensates the earliest unpaid absence', () {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 3000,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.wednesday,
    );

    final summary = summarizeDailyServices(
      <DailyServiceAttendance>[
        _attendance(
          DateTime(2026, 6, 1),
          tuitionPresent: false,
          milkReceived: true,
        ),
        _attendance(
          DateTime(2026, 6, 2),
          tuitionPresent: true,
          milkReceived: true,
        ),
        _attendance(
          DateTime(2026, 6, 3),
          tuitionPresent: true,
          milkReceived: true,
        ),
      ],
      year: 2026,
      month: 6,
      settings: settings,
    );

    expect(summary.tuitionTeachingDays, 30);
    expect(summary.tuitionDailyRate, 100);
    expect(summary.tuitionDays, 3);
    expect(summary.tuitionAmount, 300);
    expect(summary.tuitionOffDayAttendances, 1);
    expect(summary.tuitionAbsences, hasLength(1));
    expect(summary.tuitionAbsences.single.date, DateTime(2026, 6, 1));
    expect(summary.tuitionAbsences.single.compensated, isTrue);
  });

  test('successive off-day attendances compensate successive absences', () {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 3000,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.wednesday,
    );

    final summary = summarizeDailyServices(
      <DailyServiceAttendance>[
        _attendance(
          DateTime(2026, 6, 1),
          tuitionPresent: false,
          milkReceived: true,
        ),
        _attendance(
          DateTime(2026, 6, 2),
          tuitionPresent: false,
          milkReceived: true,
        ),
        _attendance(
          DateTime(2026, 6, 3),
          tuitionPresent: true,
          milkReceived: true,
        ),
        _attendance(
          DateTime(2026, 6, 10),
          tuitionPresent: true,
          milkReceived: true,
        ),
      ],
      year: 2026,
      month: 6,
      settings: settings,
    );

    expect(summary.tuitionAbsences, hasLength(2));
    expect(
      summary.tuitionAbsences.map((absence) => absence.compensation),
      everyElement(TuitionAbsenceCompensation.laterOffDay),
    );
    expect(summary.unpaidTuitionAbsences, 0);
    expect(summary.tuitionDays, 4);
    expect(summary.tuitionAmount, 400);
  });

  test('tuition totals follow paid off-day and oldest-absence recovery', () {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 3100,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.thursday,
    );
    final entries = <DailyServiceAttendance>[
      for (final day in <int>[1, 2, 3])
        _attendance(
          DateTime(2026, 8, day),
          tuitionPresent: true,
          milkReceived: true,
        ),
    ];

    DailyServiceMonthSummary summarize() => summarizeDailyServices(
      entries,
      year: 2026,
      month: 8,
      settings: settings,
    );

    expect(summarize().tuitionDays, 3);
    expect(summarize().tuitionAbsences, isEmpty);

    entries.addAll(<DailyServiceAttendance>[
      _attendance(
        DateTime(2026, 8, 4),
        tuitionPresent: false,
        milkReceived: true,
      ),
      _attendance(
        DateTime(2026, 8, 5),
        tuitionPresent: false,
        milkReceived: true,
      ),
    ]);
    expect(summarize().tuitionDays, 3);
    expect(
      summarize().tuitionAbsences.map((absence) => absence.compensated),
      everyElement(isFalse),
    );

    entries.add(
      _attendance(
        DateTime(2026, 8, 6),
        tuitionPresent: false,
        milkReceived: true,
      ),
    );
    expect(summarize().tuitionDays, 4);

    entries.addAll(<DailyServiceAttendance>[
      for (final day in <int>[7, 8, 9, 10, 11])
        _attendance(
          DateTime(2026, 8, day),
          tuitionPresent: true,
          milkReceived: true,
        ),
    ]);
    expect(summarize().tuitionDays, 9);

    entries.add(
      _attendance(
        DateTime(2026, 8, 13),
        tuitionPresent: true,
        milkReceived: true,
      ),
    );
    final afterThirteenth = summarize();
    expect(afterThirteenth.tuitionDays, 11);
    expect(
      afterThirteenth.tuitionAbsences.map((absence) => absence.compensated),
      <bool>[true, false],
    );

    final sixthIndex = entries.indexWhere((entry) => entry.date.day == 6);
    entries[sixthIndex] = _attendance(
      DateTime(2026, 8, 6),
      tuitionPresent: true,
      milkReceived: true,
    );
    final afterSixthIsPresent = summarize();
    expect(afterSixthIsPresent.tuitionDays, 12);
    expect(
      afterSixthIsPresent.tuitionAbsences.map(
        (absence) => absence.compensation,
      ),
      everyElement(TuitionAbsenceCompensation.laterOffDay),
    );
    expect(afterSixthIsPresent.tuitionAmount, 1200);
  });

  test('confirmed extra off day still recovers an earlier absence first', () {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 3000,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.wednesday,
    );

    final summary = summarizeDailyServices(
      <DailyServiceAttendance>[
        _attendance(
          DateTime(2026, 6, 1),
          tuitionPresent: false,
          milkReceived: true,
        ),
        DailyServiceAttendance(
          date: DateTime(2026, 6, 3),
          tuitionPresent: true,
          milkReceived: true,
          milkQuantityKg: 1.5,
          monthlyTuitionFee: 3000,
          milkRatePerKg: 60,
          tuitionExtraConfirmed: true,
        ),
      ],
      year: 2026,
      month: 6,
      settings: settings,
    );

    expect(summary.tuitionDays, 2);
    expect(
      summary.tuitionAbsences.single.compensation,
      TuitionAbsenceCompensation.laterOffDay,
    );
  });

  test(
    'confirmed extra tuition prepays a later absence without total change',
    () {
      const settings = DailyServiceSettings(
        monthlyTuitionFee: 3100,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
        tuitionOffWeekday: DateTime.monday,
      );
      final extraOffDay = DailyServiceAttendance(
        date: DateTime(2026, 8, 3),
        tuitionPresent: true,
        milkReceived: true,
        milkQuantityKg: 1.5,
        monthlyTuitionFee: 3100,
        milkRatePerKg: 60,
        tuitionExtraConfirmed: true,
      );

      final beforeAbsence = summarizeDailyServices(
        <DailyServiceAttendance>[extraOffDay],
        year: 2026,
        month: 8,
        settings: settings,
      );
      final afterAbsence = summarizeDailyServices(
        <DailyServiceAttendance>[
          extraOffDay,
          _attendance(
            DateTime(2026, 8, 4),
            tuitionPresent: false,
            milkReceived: true,
          ),
        ],
        year: 2026,
        month: 8,
        settings: settings,
      );

      expect(
        DailyServiceAttendance.fromMap(
          dailyAttendanceId(extraOffDay.date),
          extraOffDay.toMap(),
        ).tuitionExtraConfirmed,
        isTrue,
      );
      expect(beforeAbsence.tuitionDays, 2);
      expect(beforeAbsence.tuitionAmount, 200);
      expect(afterAbsence.tuitionDays, 2);
      expect(afterAbsence.tuitionAmount, beforeAbsence.tuitionAmount);
      expect(afterAbsence.tuitionAbsences, hasLength(1));
      expect(
        afterAbsence.tuitionAbsences.single.compensation,
        TuitionAbsenceCompensation.prepaidExtra,
      );
    },
  );

  test('off-day presence does not compensate a later absence', () {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 3100,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.monday,
    );

    final summary = summarizeDailyServices(
      <DailyServiceAttendance>[
        _attendance(
          DateTime(2026, 8, 3),
          tuitionPresent: true,
          milkReceived: true,
        ),
        _attendance(
          DateTime(2026, 8, 4),
          tuitionPresent: false,
          milkReceived: true,
        ),
      ],
      year: 2026,
      month: 8,
      settings: settings,
    );

    expect(summary.tuitionDays, 1);
    expect(summary.tuitionAmount, closeTo(3100 / 31, 0.000001));
    expect(summary.tuitionAbsences.single.compensated, isFalse);
  });

  test('summarizes saved milk quantities from explicit entries only', () {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 2600,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
    );
    final entries = <DailyServiceAttendance>[
      DailyServiceAttendance(
        date: DateTime(2026, 8, 1),
        tuitionPresent: true,
        milkReceived: true,
        milkQuantityKg: 1.5,
        monthlyTuitionFee: 3100,
        milkRatePerKg: 60,
      ),
      DailyServiceAttendance(
        date: DateTime(2026, 8, 2),
        tuitionPresent: true,
        milkReceived: true,
        milkQuantityKg: 2,
        monthlyTuitionFee: 3100,
        milkRatePerKg: 60,
      ),
    ];

    final summary = summarizeDailyServices(
      entries,
      year: 2026,
      month: 8,
      settings: settings,
      asOfDate: DateTime(2026, 8, 2),
    );

    expect(summary.tuitionDays, 2);
    expect(summary.milkDays, 2);
    expect(summary.totalMilkQuantityKg, 3.5);
    expect(summary.tuitionAmount, closeTo(2 * (2600 / 31), 0.000001));
    expect(summary.milkAmount, 210);
    expect(summary.totalAmount, closeTo(210 + (2 * 2600 / 31), 0.000001));
  });
}

DailyServiceAttendance _attendance(
  DateTime date, {
  required bool tuitionPresent,
  required bool milkReceived,
}) {
  return DailyServiceAttendance(
    date: date,
    tuitionPresent: tuitionPresent,
    milkReceived: milkReceived,
    milkQuantityKg: milkReceived ? 1.5 : 0,
    monthlyTuitionFee: 2600,
    milkRatePerKg: 60,
  );
}
