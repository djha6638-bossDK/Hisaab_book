import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_book/app.dart';
import 'package:hisaab_book/core/currency.dart';
import 'package:hisaab_book/core/month_utils.dart';
import 'package:hisaab_book/models/daily_service_attendance.dart';
import 'package:hisaab_book/models/daily_service_settings.dart';
import 'package:hisaab_book/models/expense_entry.dart';
import 'package:hisaab_book/models/income_entry.dart';
import 'package:hisaab_book/models/monthly_record.dart';
import 'package:hisaab_book/models/payment_person.dart';
import 'package:hisaab_book/models/recurring_expense.dart';
import 'package:hisaab_book/repositories/memory_ledger_repository.dart';
import 'package:hisaab_book/screens/daily_attendance_screen.dart';
import 'package:hisaab_book/screens/daily_service_settings_screen.dart';
import 'package:hisaab_book/screens/daily_services_screen.dart';
import 'package:hisaab_book/screens/income_setup_dialog.dart';
import 'package:hisaab_book/screens/monthly_record_screen.dart';
import 'package:hisaab_book/screens/payment_people_screen.dart';
import 'package:hisaab_book/screens/recurring_expenses_screen.dart';
import 'package:hisaab_book/screens/saved_records_screen.dart';
import 'package:hisaab_book/services/attendance_reminder_service.dart';
import 'package:hisaab_book/services/app_update_service.dart';
import 'package:hisaab_book/services/auth_service.dart';
import 'package:hisaab_book/services/daily_attendance_prompt_store.dart';
import 'package:hisaab_book/services/memory_auth_service.dart';
import 'package:hisaab_book/services/pdf_report_service.dart';

class _FakeAppUpdateService extends AppUpdateService {
  _FakeAppUpdateService({
    this.availableUpdate,
    this.installed = const InstalledAppVersion(
      versionName: '1.1.0',
      buildNumber: 2,
    ),
  }) : super();

  AppUpdateInfo? availableUpdate;
  final InstalledAppVersion installed;
  int checkCount = 0;
  int skipCount = 0;
  int downloadCount = 0;
  int installCount = 0;
  bool installSucceeds = true;

  @override
  Future<InstalledAppVersion> installedVersion() async => installed;

  @override
  Future<AppUpdateInfo?> checkForUpdate({bool force = false}) async {
    checkCount++;
    return availableUpdate;
  }

  @override
  Future<void> skipVersion(AppUpdateInfo update) async {
    skipCount++;
    availableUpdate = null;
  }

  @override
  Future<String> downloadApk(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    downloadCount++;
    onProgress?.call(0.4);
    onProgress?.call(1);
    return 'fake-update.apk';
  }

  @override
  Future<AppUpdateInstallResult> installApk(String path) async {
    installCount++;
    return installSucceeds
        ? AppUpdateInstallResult.opened
        : AppUpdateInstallResult.failed;
  }
}

void main() {
  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    required MemoryAuthService auth,
    required MemoryLedgerRepository repository,
    MemoryDailyAttendancePromptStore? promptStore,
    MemoryAttendanceReminderService? reminderService,
    AppUpdateService? appUpdateService,
  }) async {
    await tester.pumpWidget(
      HisaabBookApp(
        key: UniqueKey(),
        authService: auth,
        repositoryFactory: (_) => repository,
        dailyAttendancePromptStore:
            promptStore ?? MemoryDailyAttendancePromptStore(),
        attendanceReminderService:
            reminderService ?? MemoryAttendanceReminderService(),
        pdfReportService: PdfReportService(),
        appUpdateService: appUpdateService ?? _FakeAppUpdateService(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectDailyServicesMonth(
    WidgetTester tester,
    int year,
    int month,
  ) async {
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(monthNames[month - 1]).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('$year').last);
    await tester.pumpAndSettle();
  }

  Future<void> scrollToAttendanceBanner(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('today-attendance-banner')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  AppUpdateInfo updateFixture() => AppUpdateInfo(
    versionName: '1.1.1',
    buildNumber: 3,
    releaseNotes: 'Update card aur bug fixes.',
    apkUri: Uri.parse('https://example.com/hisaab-book-1.1.1+3.apk'),
    releasePageUri: Uri.parse(
      'https://github.com/djha6638-bossDK/Hisaab_book/releases/tag/v1.1.1+3',
    ),
    apkSizeBytes: 1200000,
    checksumUri: Uri.parse(
      'https://example.com/hisaab-book-1.1.1+3.apk.sha256',
    ),
  );

  testWidgets('daily attendance allows a one-day milk quantity override', (
    tester,
  ) async {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 3100,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.monday,
    );
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: settings,
    );
    final date = DateTime(2026, 8, 2);
    await tester.pumpWidget(
      MaterialApp(
        home: DailyAttendanceScreen(
          repository: repository,
          date: date,
          settings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final quantityField = find.byKey(
      const ValueKey<String>('milk-quantity-field'),
    );
    await tester.scrollUntilVisible(
      quantityField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(quantityField).controller?.text, '1.5');
    await tester.enterText(quantityField, '2');
    await tester.enterText(
      find.byKey(const ValueKey<String>('daily-attendance-remarks')),
      'Milk arrived late.',
    );
    await tester.tap(find.text('Attendance save karo'));
    await tester.pumpAndSettle();

    final saved = await repository.getDailyServiceAttendance(date);
    expect(saved?.tuitionPresent, isTrue);
    expect(saved?.milkReceived, isTrue);
    expect(saved?.milkQuantityKg, 2);
    expect(saved?.tuitionAmount, 100);
    expect(saved?.milkAmount, 120);
    expect(saved?.remarks, 'Milk arrived late.');
    expect(
      (await repository.getDailyServiceSettings())?.defaultMilkQuantityKg,
      1.5,
    );
  });

  testWidgets('daily service settings preserve legacy off-day data', (
    tester,
  ) async {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 2600,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.friday,
    );
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: settings,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DailyServiceSettingsScreen(
          repository: repository,
          initialSettings: settings,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Friday'), findsOneWidget);
    await tester.tap(find.text('Settings save karo'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getDailyServiceSettings())?.tuitionOffWeekday,
      DateTime.friday,
    );
  });

  testWidgets(
    'home shows a pending attendance card and opens today attendance',
    (tester) async {
      final auth = MemoryAuthService(
        initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
      );
      final repository = MemoryLedgerRepository(
        initialDailyServiceSettings: const DailyServiceSettings(
          monthlyTuitionFee: 3000,
          milkRatePerKg: 60,
          defaultMilkQuantityKg: 1.5,
        ),
      );
      final promptStore = MemoryDailyAttendancePromptStore();
      await pumpApp(
        tester,
        auth: auth,
        repository: repository,
        promptStore: promptStore,
      );

      expect(find.text('Hisaab Book'), findsOneWidget);
      await scrollToAttendanceBanner(tester);
      expect(
        find.byKey(const ValueKey<String>('today-attendance-banner')),
        findsOneWidget,
      );
      expect(find.text('Aaj ki attendance baaki hai'), findsOneWidget);
      expect(find.text('Attendance save karo'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('today-attendance-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attendance'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('milk-quantity-field')),
        findsOneWidget,
      );
      await tester.tap(find.text('Attendance save karo'));
      await tester.pumpAndSettle();

      final day = today();
      expect(find.text('Hisaab Book'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('today-attendance-banner')),
        findsNothing,
      );
      expect(await repository.getDailyServiceAttendance(day), isNotNull);
      expect(await promptStore.hasHandled(auth.currentUser!.id, day), isTrue);
      await auth.dispose();
    },
  );

  testWidgets('skip hides today attendance without saving an entry', (
    tester,
  ) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: const DailyServiceSettings(
        monthlyTuitionFee: 3000,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
      ),
    );
    final promptStore = MemoryDailyAttendancePromptStore();
    await pumpApp(
      tester,
      auth: auth,
      repository: repository,
      promptStore: promptStore,
    );

    await scrollToAttendanceBanner(tester);
    expect(find.text('Aaj ki attendance baaki hai'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('skip-today-attendance')),
    );
    await tester.pumpAndSettle();

    final day = today();
    expect(
      find.byKey(const ValueKey<String>('today-attendance-banner')),
      findsNothing,
    );
    expect(await repository.getDailyServiceAttendance(day), isNull);
    expect(await promptStore.hasHandled(auth.currentUser!.id, day), isTrue);
    expect(
      await promptStore.hasHandled(
        auth.currentUser!.id,
        day.add(const Duration(days: 1)),
      ),
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp(
      tester,
      auth: auth,
      repository: repository,
      promptStore: promptStore,
    );
    expect(
      find.byKey(const ValueKey<String>('today-attendance-banner')),
      findsNothing,
    );
    await auth.dispose();
  });

  testWidgets('home attendance card honors the tuition off day default', (
    tester,
  ) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: DailyServiceSettings(
        monthlyTuitionFee: 3000,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
        tuitionOffWeekday: DateTime.now().weekday,
      ),
    );
    await pumpApp(tester, auth: auth, repository: repository);

    await scrollToAttendanceBanner(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('today-attendance-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('tuition-off-button')),
      findsOneWidget,
    );
    expect(find.text('Tuition: Chhutti'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('milk-present-button')),
      findsOneWidget,
    );

    await tester.tap(find.text('Attendance save karo'));
    await tester.pumpAndSettle();

    final saved = await repository.getDailyServiceAttendance(today());
    expect(saved?.tuitionPresent, isFalse);
    expect(saved?.milkReceived, isTrue);
    await auth.dispose();
  });

  testWidgets('daily services shows monthly totals and edits a saved day', (
    tester,
  ) async {
    useTallSurface(tester);
    final daysInMonth = DateTime(2026, 9, 0).day;
    final firstDate = DateTime(2026, 8, 1);
    final secondDate = DateTime(2026, 8, 2);
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: DailyServiceSettings(
        monthlyTuitionFee: daysInMonth * 100,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
        tuitionOffWeekday: DateTime.monday,
      ),
      dailyServiceAttendance: <DailyServiceAttendance>[
        DailyServiceAttendance(
          date: firstDate,
          tuitionPresent: false,
          milkReceived: true,
          milkQuantityKg: 2,
          monthlyTuitionFee: daysInMonth * 100,
          milkRatePerKg: 60,
        ),
        DailyServiceAttendance(
          date: secondDate,
          tuitionPresent: true,
          milkReceived: false,
          milkQuantityKg: 0,
          monthlyTuitionFee: daysInMonth * 100,
          milkRatePerKg: 60,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: DailyServicesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await selectDailyServicesMonth(tester, 2026, 8);

    expect(find.text('Current rates'), findsNothing);
    expect(find.text('Gair-hazir dates'), findsOneWidget);
    expect(find.text('1 Aug'), findsOneWidget);
    expect(find.text('2 Aug'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('absent-Tuition-1 Aug')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('absent-Milk-2 Aug')),
      findsOneWidget,
    );
    expect(find.text('Combined total'), findsNothing);
    expect(find.text('Tuition ka amount'), findsOneWidget);
    expect(find.text('Doodh amount'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('Tuition amount-current')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('Tuition amount-current')),
          )
          .data,
      formatIndianCurrency(100),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('Tuition amount-monthly-total')),
          )
          .data,
      '/ ${formatIndianCurrency(daysInMonth * 100)}',
    );
    expect(find.text(formatIndianCurrency(120)), findsOneWidget);
    expect(find.textContaining('din pending hain'), findsOneWidget);

    final savedDay = find.text('Doodh 2 kg');
    final savedDayRow = find.byKey(
      const ValueKey<String>('daily-service-2026-08-02'),
    );
    await tester.scrollUntilVisible(
      savedDay,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(savedDay, findsOneWidget);
    expect(
      find.descendant(of: savedDayRow, matching: find.text('Tuition aaya')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: savedDayRow, matching: find.text('Doodh nahi aaya')),
      findsOneWidget,
    );

    await tester.tap(savedDay);
    await tester.pumpAndSettle();
    expect(find.text('Attendance'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('milk-quantity-field')),
      findsOneWidget,
    );
  });

  testWidgets('remarks mark the date orange and open read-only on long press', (
    tester,
  ) async {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, 1);
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: const DailyServiceSettings(
        monthlyTuitionFee: 3100,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
      ),
      dailyServiceAttendance: <DailyServiceAttendance>[
        DailyServiceAttendance(
          date: date,
          tuitionPresent: true,
          milkReceived: true,
          milkQuantityKg: 1.5,
          monthlyTuitionFee: 3100,
          milkRatePerKg: 60,
          remarks: 'Teacher came thirty minutes late.',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: DailyServicesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(
      ValueKey<String>('daily-service-${dailyAttendanceId(date)}'),
    );
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey<String>('remarks-date-1')),
      findsOneWidget,
    );

    await tester.longPress(row);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('remarks-read-only-text')),
      findsOneWidget,
    );
    expect(find.text('Teacher came thirty minutes late.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Note',
      ),
      findsNothing,
    );
  });

  testWidgets('blank month starts tuition amount at zero', (tester) async {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final monthlyFee = daysInMonth * 100.0;
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: DailyServiceSettings(
        monthlyTuitionFee: monthlyFee,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: DailyServicesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final currentAmount = tester.widget<Text>(
      find.byKey(const ValueKey<String>('Tuition amount-current')),
    );
    final monthlyTotal = tester.widget<Text>(
      find.byKey(const ValueKey<String>('Tuition amount-monthly-total')),
    );

    expect(currentAmount.data, formatIndianCurrency(0));
    expect(monthlyTotal.data, '/ ${formatIndianCurrency(monthlyFee)}');
    expect(
      monthlyTotal.style?.fontSize,
      Theme.of(
        tester.element(
          find.byKey(const ValueKey<String>('Tuition amount-monthly-total')),
        ),
      ).textTheme.bodySmall?.fontSize,
    );
    expect(monthlyTotal.style?.color, Colors.grey.shade600);
    expect(find.textContaining('din pending hain'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('Milk amount-current')),
          )
          .data,
      formatIndianCurrency(0),
    );
  });

  testWidgets('daily services shows pending tuition off days on missing dates', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: const DailyServiceSettings(
        monthlyTuitionFee: 2600,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
        tuitionOffWeekday: DateTime.monday,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: DailyServicesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await selectDailyServicesMonth(tester, 2026, 8);

    final defaultDay = find.byKey(
      const ValueKey<String>('daily-service-2026-08-03'),
    );
    await tester.scrollUntilVisible(
      defaultDay,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(defaultDay, findsOneWidget);
    expect(
      find.descendant(
        of: defaultDay,
        matching: find.text('Tuition chhutti - pending'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: defaultDay, matching: find.text('Doodh pending')),
      findsOneWidget,
    );

    await tester.tap(defaultDay);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('tuition-present-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('tuition-off-button')),
      findsOneWidget,
    );
    expect(find.text('Tuition: Chhutti'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('tuition-present-button')),
    );
    await tester.pump();
    await tester.tap(find.text('Attendance save karo'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('extra-tuition-confirmation')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-extra-tuition')),
    );
    await tester.pumpAndSettle();

    final saved = await repository.getDailyServiceAttendance(
      DateTime(2026, 8, 3),
    );
    expect(saved?.tuitionPresent, isTrue);
  });

  testWidgets('saved tuition off day is shown as off instead of absent', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: const DailyServiceSettings(
        monthlyTuitionFee: 3100,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
        tuitionOffWeekday: DateTime.monday,
      ),
      dailyServiceAttendance: <DailyServiceAttendance>[
        DailyServiceAttendance(
          date: DateTime(2026, 8, 3),
          tuitionPresent: false,
          milkReceived: true,
          milkQuantityKg: 1.5,
          monthlyTuitionFee: 3100,
          milkRatePerKg: 60,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: DailyServicesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await selectDailyServicesMonth(tester, 2026, 8);

    final offDay = find.byKey(
      const ValueKey<String>('daily-service-2026-08-03'),
    );
    await tester.scrollUntilVisible(
      offDay,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.descendant(of: offDay, matching: find.text('Tuition chhutti')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: offDay, matching: find.text('Tuition nahi aaya')),
      findsNothing,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('Tuition amount-current')),
          )
          .data,
      formatIndianCurrency(100),
    );
  });

  testWidgets('off-day presence turns an unpaid tuition absence green', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: const DailyServiceSettings(
        monthlyTuitionFee: 3100,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
        tuitionOffWeekday: DateTime.monday,
      ),
      dailyServiceAttendance: <DailyServiceAttendance>[
        DailyServiceAttendance(
          date: DateTime(2026, 8, 1),
          tuitionPresent: false,
          milkReceived: true,
          milkQuantityKg: 1.5,
          monthlyTuitionFee: 3100,
          milkRatePerKg: 60,
        ),
        DailyServiceAttendance(
          date: DateTime(2026, 8, 2),
          tuitionPresent: true,
          milkReceived: true,
          milkQuantityKg: 1.5,
          monthlyTuitionFee: 3100,
          milkRatePerKg: 60,
        ),
        DailyServiceAttendance(
          date: DateTime(2026, 8, 3),
          tuitionPresent: true,
          milkReceived: true,
          milkQuantityKg: 1.5,
          monthlyTuitionFee: 3100,
          milkRatePerKg: 60,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: DailyServicesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await selectDailyServicesMonth(tester, 2026, 8);

    expect(
      find.byKey(const ValueKey<String>('compensated-Tuition-1 Aug')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('absent-Tuition-1 Aug')),
      findsNothing,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('Tuition amount-current')),
          )
          .data,
      formatIndianCurrency(300),
    );
  });

  testWidgets('off-day presence with no absence requires extra confirmation', (
    tester,
  ) async {
    const settings = DailyServiceSettings(
      monthlyTuitionFee: 3100,
      milkRatePerKg: 60,
      defaultMilkQuantityKg: 1.5,
      tuitionOffWeekday: DateTime.monday,
    );
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: settings,
    );
    final date = DateTime(2026, 8, 3);

    await tester.pumpWidget(
      MaterialApp(
        home: DailyAttendanceScreen(
          repository: repository,
          date: date,
          settings: settings,
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('tuition-present-button')),
    );
    await tester.tap(find.text('Attendance save karo'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('extra-tuition-confirmation')),
      findsOneWidget,
    );
    expect(await repository.getDailyServiceAttendance(date), isNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-extra-tuition')),
    );
    await tester.pumpAndSettle();

    final saved = await repository.getDailyServiceAttendance(date);
    expect(saved?.tuitionPresent, isTrue);
    expect(saved?.tuitionExtraConfirmed, isTrue);
  });

  testWidgets('extra tuition and its later makeup absence are shown in gold', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: const DailyServiceSettings(
        monthlyTuitionFee: 3100,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
        tuitionOffWeekday: DateTime.monday,
      ),
      dailyServiceAttendance: <DailyServiceAttendance>[
        DailyServiceAttendance(
          date: DateTime(2026, 8, 3),
          tuitionPresent: true,
          milkReceived: true,
          milkQuantityKg: 1.5,
          monthlyTuitionFee: 3100,
          milkRatePerKg: 60,
          tuitionExtraConfirmed: true,
        ),
        DailyServiceAttendance(
          date: DateTime(2026, 8, 4),
          tuitionPresent: false,
          milkReceived: true,
          milkQuantityKg: 1.5,
          monthlyTuitionFee: 3100,
          milkRatePerKg: 60,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: DailyServicesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await selectDailyServicesMonth(tester, 2026, 8);

    expect(
      find.byKey(const ValueKey<String>('extra-compensated-Tuition-4 Aug')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('Tuition amount-current')),
          )
          .data,
      formatIndianCurrency(200),
    );

    final extraOffDay = find.byKey(
      const ValueKey<String>('daily-service-2026-08-03'),
    );
    await tester.scrollUntilVisible(
      extraOffDay,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: extraOffDay,
        matching: find.byKey(const ValueKey<String>('extra-tuition-date-3')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: extraOffDay, matching: find.text('Extra tuition')),
      findsOneWidget,
    );
  });

  testWidgets(
    'income setup keeps each source on one row and locks default names',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IncomeSetupDialog())),
      );

      List<TextField> sourceFields() => tester
          .widgetList<TextField>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.decoration?.labelText == 'Income source',
            ),
          )
          .toList();

      expect(sourceFields().map((field) => field.controller?.text), <String>[
        'Salary',
        'Pension',
      ]);
      expect(sourceFields().every((field) => field.readOnly), isTrue);

      await tester.tap(find.text('Income jodo'));
      await tester.pump();

      final sources = sourceFields();
      expect(sources, hasLength(3));
      expect(sources.last.readOnly, isFalse);

      final sourceFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Income source',
      );
      final amountFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Amount',
      );
      final deleteFinder = find.byTooltip('Income hatao');

      for (var index = 0; index < 3; index++) {
        final sourceCenter = tester.getCenter(sourceFinder.at(index));
        final amountCenter = tester.getCenter(amountFinder.at(index));
        final deleteCenter = tester.getCenter(deleteFinder.at(index));

        expect(sourceCenter.dx, lessThan(amountCenter.dx));
        expect(amountCenter.dx, lessThan(deleteCenter.dx));
        expect((sourceCenter.dy - amountCenter.dy).abs(), lessThan(2));
        expect((amountCenter.dy - deleteCenter.dy).abs(), lessThan(2));
      }
    },
  );

  testWidgets('shows login and transitions to authenticated home', (
    tester,
  ) async {
    final auth = MemoryAuthService();
    final repository = MemoryLedgerRepository();
    await pumpApp(tester, auth: auth, repository: repository);

    expect(find.text('Google se aage badho'), findsOneWidget);
    await tester.tap(find.text('Google se aage badho'));
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text(monthName(DateTime.now().month)), findsOneWidget);
    expect(find.text('Hisaab Book'), findsOneWidget);
    await auth.dispose();
  });

  testWidgets('home info button shows creator and app details', (tester) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    await pumpApp(
      tester,
      auth: auth,
      repository: MemoryLedgerRepository(),
      appUpdateService: _FakeAppUpdateService(
        installed: const InstalledAppVersion(
          versionName: '1.1.5',
          buildNumber: 7,
        ),
      ),
    );

    await tester.tap(find.byTooltip('App ke baare me'));
    await tester.pumpAndSettle();

    expect(find.text('Hisaab Book ke baare me'), findsOneWidget);
    expect(find.text('Dhiraj Kumar Jha'), findsOneWidget);
    expect(find.text('djha6638@gmail.com'), findsOneWidget);
    expect(find.text('1.1.5'), findsOneWidget);

    await tester.tap(find.text('Band karo'));
    await tester.pumpAndSettle();
    expect(find.text('Hisaab Book ke baare me'), findsNothing);
    await auth.dispose();
  });

  testWidgets('home shows the update card and Baad me skips that version', (
    tester,
  ) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    final updateService = _FakeAppUpdateService(
      availableUpdate: updateFixture(),
    );
    await pumpApp(
      tester,
      auth: auth,
      repository: MemoryLedgerRepository(),
      appUpdateService: updateService,
    );

    final card = find.byKey(const ValueKey<String>('app-update-card'));
    expect(card, findsOneWidget);
    expect(find.text('Naya update aa gaya hai'), findsOneWidget);
    expect(find.textContaining('1.1.1'), findsWidgets);
    expect(find.text('Update card aur bug fixes.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('update-later-button')),
    );
    await tester.pumpAndSettle();

    expect(card, findsNothing);
    expect(updateService.skipCount, 1);
    await auth.dispose();
  });

  testWidgets('update card downloads the APK and opens the installer', (
    tester,
  ) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    final updateService = _FakeAppUpdateService(
      availableUpdate: updateFixture(),
    );
    await pumpApp(
      tester,
      auth: auth,
      repository: MemoryLedgerRepository(),
      appUpdateService: updateService,
    );

    await tester.tap(find.byKey(const ValueKey<String>('update-now-button')));
    await tester.pumpAndSettle();

    expect(updateService.downloadCount, 1);
    expect(updateService.installCount, 1);
    expect(find.text('Update install nahi hua'), findsNothing);
    await auth.dispose();
  });

  testWidgets('update install failure shows a browser fallback', (
    tester,
  ) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    final updateService = _FakeAppUpdateService(
      availableUpdate: updateFixture(),
    )..installSucceeds = false;
    await pumpApp(
      tester,
      auth: auth,
      repository: MemoryLedgerRepository(),
      appUpdateService: updateService,
    );

    await tester.tap(find.byKey(const ValueKey<String>('update-now-button')));
    await tester.pumpAndSettle();

    expect(find.text('Update install nahi hua'), findsOneWidget);
    expect(find.text('Browser se kholo'), findsOneWidget);
    await tester.tap(find.text('Band karo'));
    await tester.pumpAndSettle();
    await auth.dispose();
  });

  testWidgets('home drawer shows record shortcuts and opens saved records', (
    tester,
  ) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    await pumpApp(
      tester,
      auth: auth,
      repository: MemoryLedgerRepository(),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Purane record'), findsOneWidget);
    expect(find.text('Recurring kharch'), findsOneWidget);
    expect(find.text('Tuition aur doodh'), findsOneWidget);
    expect(find.text('Payment log'), findsOneWidget);
    expect(find.text('Manage'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('drawer-saved-records')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Purane record'), findsOneWidget);
    expect(find.text('Koi saved record nahi'), findsOneWidget);
    await auth.dispose();
  });

  testWidgets(
    'home reminder settings enable a default reminder and turn blue',
    (tester) async {
      final auth = MemoryAuthService(
        initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
      );
      final reminderService = MemoryAttendanceReminderService(
        permissionRequestResult: true,
      );
      await pumpApp(
        tester,
        auth: auth,
        repository: MemoryLedgerRepository(),
        reminderService: reminderService,
      );

      final reminderButton = find.byKey(
        const ValueKey<String>('attendance-reminder-button'),
      );
      expect(reminderButton, findsOneWidget);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: reminderButton,
                matching: find.byIcon(Icons.notifications_none_rounded),
              ),
            )
            .color,
        isNull,
      );

      await tester.tap(reminderButton);
      await tester.pumpAndSettle();
      expect(find.text('Attendance reminder'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('reminder-toggle')),
      );
      await tester.pumpAndSettle();

      expect(reminderService.permissionRequestCount, 1);
      expect(reminderService.permissionsGranted, isTrue);
      expect(reminderService.scheduleCount, 1);
      expect(reminderService.reminderTime?.hour, 20);
      expect(reminderService.reminderTime?.minute, 0);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: reminderButton,
                matching: find.byIcon(Icons.notifications_rounded),
              ),
            )
            .color,
        Colors.blue,
      );
      final enabledCover = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey<String>('attendance-reminder-icon-cover')),
      );
      final enabledDecoration = enabledCover.decoration as BoxDecoration;
      expect(enabledDecoration.borderRadius, BorderRadius.circular(10));
      expect(enabledDecoration.color, Colors.blue.withValues(alpha: 0.12));
      expect(find.textContaining('par on ho gaya'), findsOneWidget);
      await auth.dispose();
    },
  );

  testWidgets('long press reminder button schedules the selected daily time', (
    tester,
  ) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    final reminderService = MemoryAttendanceReminderService(
      permissionsGranted: true,
    );
    await pumpApp(
      tester,
      auth: auth,
      repository: MemoryLedgerRepository(),
      reminderService: reminderService,
    );

    final reminderButton = find.byKey(
      const ValueKey<String>('attendance-reminder-button'),
    );
    await tester.longPress(reminderButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Attendance reminder ka time chuno'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(reminderService.scheduleCount, 1);
    expect(reminderService.reminderTime?.hour, 20);
    expect(reminderService.reminderTime?.minute, 0);
    expect(find.textContaining('par set ho gaya'), findsOneWidget);
    await auth.dispose();
  });

  testWidgets('reminder can be disabled, re-enabled, and disabled again', (
    tester,
  ) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    final reminderService = MemoryAttendanceReminderService(
      permissionsGranted: true,
    )..reminderTime = const AttendanceReminderTime(hour: 20, minute: 0);

    await pumpApp(
      tester,
      auth: auth,
      repository: MemoryLedgerRepository(),
      reminderService: reminderService,
    );

    final reminderButton = find.byKey(
      const ValueKey<String>('attendance-reminder-button'),
    );
    final reminderToggle = find.byKey(
      const ValueKey<String>('reminder-toggle'),
    );

    await tester.tap(reminderButton);
    await tester.pumpAndSettle();
    await tester.tap(reminderToggle);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('disable-reminder-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-disable-reminder')),
    );
    await tester.pumpAndSettle();

    expect(reminderService.reminderTime, isNull);
    expect(reminderService.cancelCount, 1);
    expect(find.text('Attendance reminder band ho gaya.'), findsOneWidget);
    expect(
      find.descendant(
        of: reminderButton,
        matching: find.byIcon(Icons.notifications_none_rounded),
      ),
      findsOneWidget,
    );
    final disabledCover = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey<String>('attendance-reminder-icon-cover')),
    );
    final disabledDecoration = disabledCover.decoration as BoxDecoration;
    expect(disabledDecoration.color, Colors.transparent);
    expect(disabledDecoration.border, isNull);

    await tester.tap(reminderButton);
    await tester.pumpAndSettle();
    await tester.tap(reminderToggle);
    await tester.pumpAndSettle();

    expect(reminderService.scheduleCount, 1);
    expect(reminderService.reminderTime?.hour, 20);
    expect(reminderService.reminderTime?.minute, 0);
    expect(find.textContaining('par on ho gaya'), findsOneWidget);
    expect(
      find.descendant(
        of: reminderButton,
        matching: find.byIcon(Icons.notifications_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(reminderButton);
    await tester.pumpAndSettle();
    await tester.tap(reminderToggle);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('disable-reminder-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-disable-reminder')),
    );
    await tester.pumpAndSettle();

    expect(reminderService.reminderTime, isNull);
    expect(reminderService.cancelCount, 2);
    expect(
      find.descendant(
        of: reminderButton,
        matching: find.byIcon(Icons.notifications_none_rounded),
      ),
      findsOneWidget,
    );
    await auth.dispose();
  });

  testWidgets('logout asks for confirmation and shows signed-in email', (
    tester,
  ) async {
    final auth = MemoryAuthService(
      initialUser: const AuthUser(
        id: 'u1',
        displayName: 'Dhiraj',
        email: 'dhiraj@example.com',
      ),
    );
    await pumpApp(
      tester,
      auth: auth,
      repository: MemoryLedgerRepository(),
    );

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Logout karna hai?'), findsOneWidget);
    expect(find.text('dhiraj@example.com'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNotNull);

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNull);
    expect(find.text('Google se aage badho'), findsOneWidget);
    await auth.dispose();
  });

  testWidgets('surfaces authentication errors and restores login action', (
    tester,
  ) async {
    final auth = MemoryAuthService()..signInError = StateError('offline');
    await pumpApp(
      tester,
      auth: auth,
      repository: MemoryLedgerRepository(),
    );

    await tester.tap(find.text('Google se aage badho'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Internet nahi chal raha'), findsOneWidget);
    expect(find.text('Google se aage badho'), findsOneWidget);
    await auth.dispose();
  });

  testWidgets('new month flow prefills active recurring expenses', (
    tester,
  ) async {
    useTallSurface(tester);
    final auth = MemoryAuthService(
      initialUser: const AuthUser(id: 'u1', displayName: 'Dhiraj'),
    );
    final repository = MemoryLedgerRepository(
      recurringExpenses: const <RecurringExpense>[
        RecurringExpense(
          id: 'rent',
          name: 'Rent',
          defaultAmount: 12000,
          isActive: true,
          displayOrder: 0,
        ),
        RecurringExpense(
          id: 'paused',
          name: 'Paused',
          defaultAmount: 500,
          isActive: false,
          displayOrder: 1,
        ),
      ],
    );
    await pumpApp(tester, auth: auth, repository: repository);

    await tester.tap(find.text('Mahina kholo'));
    await tester.pumpAndSettle();
    expect(find.text('Mahine ki income'), findsOneWidget);

    final amountFields = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Amount',
    );
    await tester.enterText(amountFields.at(0), '50000');
    await tester.enterText(amountFields.at(1), '0');
    await tester.tap(find.text('Aage badho'));
    await tester.pumpAndSettle();

    expect(find.text('Mahina save karo'), findsOneWidget);
    expect(find.text('Income'), findsWidgets);
    expect(find.text('Kharch'), findsWidgets);
    expect(find.text('Bachat = ${formatIndianCurrency(38000)}'), findsOneWidget);
    expect(find.text('Income source'), findsNothing);
    expect(find.text('Income jodo'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    final monthlyFields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      monthlyFields.any((field) => field.controller?.text == 'Rent'),
      isTrue,
    );
    expect(
      monthlyFields.any((field) => field.controller?.text == 'Paused'),
      isFalse,
    );
    await auth.dispose();
  });

  testWidgets('existing monthly record opens in view mode and can enter edit', (
    tester,
  ) async {
    const record = MonthlyRecord(
      id: '2026-07',
      year: 2026,
      month: 7,
      incomes: <IncomeEntry>[IncomeEntry(name: 'Salary', amount: 5000)],
      expenses: <ExpenseEntry>[ExpenseEntry(name: 'Rent', amount: 2000)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyRecordScreen(
          repository: MemoryLedgerRepository(records: <MonthlyRecord>[record]),
          initialRecord: record,
          viewOnly: true,
        ),
      ),
    );

    expect(find.text('Mahina save karo'), findsNothing);
    expect(find.text('Income'), findsWidgets);
    expect(find.text('Kharch'), findsWidgets);
    expect(find.text('Bachat = ${formatIndianCurrency(3000)}'), findsOneWidget);
    expect(find.text('Income source'), findsNothing);
    expect(find.text('Income jodo'), findsNothing);
    expect(find.text('Opening balance'), findsNothing);
    expect(find.text('Opening'), findsNothing);
    expect(find.text('Remaining'), findsNothing);
    expect(find.textContaining('Available balance'), findsNothing);
    expect(find.text('Copy previous'), findsNothing);
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    expect(find.text('Mahina save karo'), findsOneWidget);
    expect(find.text('Copy previous'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(find.text('Update recurring defaults on save'), findsNothing);
  });

  testWidgets('income can be edited from an existing month', (tester) async {
    useTallSurface(tester);
    const record = MonthlyRecord(
      id: '2026-07',
      year: 2026,
      month: 7,
      incomes: <IncomeEntry>[IncomeEntry(name: 'Salary', amount: 5000)],
      expenses: <ExpenseEntry>[ExpenseEntry(name: 'Rent', amount: 2000)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyRecordScreen(
          repository: MemoryLedgerRepository(records: <MonthlyRecord>[record]),
          initialRecord: record,
          viewOnly: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('edit-income-button')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Income badlo'), findsOneWidget);

    final amountFields = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Amount',
    );
    expect(
      tester.widget<TextField>(amountFields.first).controller?.text,
      '5000',
    );
    await tester.enterText(amountFields.first, '8000');
    await tester.tap(find.text('Save karo'));
    await tester.pumpAndSettle();

    expect(find.text('Bachat = ${formatIndianCurrency(6000)}'), findsOneWidget);
    expect(find.text(formatIndianCurrency(8000)), findsWidgets);
  });

  testWidgets('shows cumulative and negative expense balances', (tester) async {
    const record = MonthlyRecord(
      id: '2026-08',
      year: 2026,
      month: 8,
      incomes: <IncomeEntry>[IncomeEntry(name: 'Salary', amount: 100)],
      expenses: <ExpenseEntry>[
        ExpenseEntry(name: 'First', amount: 60),
        ExpenseEntry(name: 'Second', amount: 75),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyRecordScreen(
          repository: MemoryLedgerRepository(
            records: const <MonthlyRecord>[record],
          ),
          initialRecord: record,
          viewOnly: true,
        ),
      ),
    );

    expect(find.text(formatIndianCurrency(40)), findsOneWidget);
    expect(find.text(formatIndianCurrency(-35)), findsOneWidget);
    expect(
      find.text('Bachat = ${formatIndianCurrency(-35)}'),
      findsOneWidget,
    );
  });

  testWidgets('keeps add expense button fixed while the page scrolls', (
    tester,
  ) async {
    final record = MonthlyRecord(
      id: '2026-10',
      year: 2026,
      month: 10,
      incomes: const <IncomeEntry>[IncomeEntry(name: 'Salary', amount: 50000)],
      expenses: List<ExpenseEntry>.generate(
        8,
        (index) => ExpenseEntry(name: 'Expense ${index + 1}', amount: 100),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyRecordScreen(
          repository: MemoryLedgerRepository(),
          initialRecord: record,
          viewOnly: false,
          isNewRecord: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addExpenseButton = find.byType(FloatingActionButton);
    expect(find.byTooltip('Kharcha jodo'), findsOneWidget);
    expect(addExpenseButton, findsOneWidget);
    expect(
      tester.widget<FloatingActionButton>(addExpenseButton).shape,
      isA<CircleBorder>(),
    );
    final positionBeforeScroll = tester.getTopLeft(addExpenseButton);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(addExpenseButton), positionBeforeScroll);
    expect(
      positionBeforeScroll.dx,
      greaterThan(tester.getSize(find.byType(Scaffold)).width / 2),
    );

    final pageScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final scrollable = tester.state<ScrollableState>(pageScrollable);
    final extentBeforeAdd = scrollable.position.maxScrollExtent;
    await tester.tap(addExpenseButton);
    await tester.pump();
    expect(scrollable.position.maxScrollExtent, greaterThan(extentBeforeAdd));
  });

  testWidgets('assigns expenses to people and adds reusable people', (
    tester,
  ) async {
    useTallSurface(tester);
    const record = MonthlyRecord(
      id: '2026-09',
      year: 2026,
      month: 9,
      incomes: <IncomeEntry>[IncomeEntry(name: 'Salary', amount: 10000)],
      expenses: <ExpenseEntry>[
        ExpenseEntry(name: 'Rent', amount: 3000),
        ExpenseEntry(name: 'School', amount: 4000),
        ExpenseEntry(name: 'Milk', amount: 1000),
      ],
    );
    final repository = MemoryLedgerRepository(
      paymentPeople: const <PaymentPerson>[
        PaymentPerson(id: 'rohan', name: 'Rohan'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyRecordScreen(
          repository: repository,
          initialRecord: record,
          viewOnly: false,
          isNewRecord: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> assignFirstNishuToRohan() async {
      await tester.tap(find.widgetWithText(ActionChip, 'Nishu').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Rohan').last);
      await tester.pumpAndSettle();
    }

    await assignFirstNishuToRohan();
    await assignFirstNishuToRohan();

    expect(find.widgetWithText(ActionChip, 'Rohan'), findsNWidgets(2));
    expect(find.widgetWithText(ListTile, 'Rohan'), findsOneWidget);
    expect(find.text('2 kharch'), findsOneWidget);

    final nishuChip = find.widgetWithText(ActionChip, 'Nishu');
    await tester.tap(nishuChip.first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Naya person jodo'));
    await tester.pumpAndSettle();
    expect(find.text('Naya payment person'), findsOneWidget);
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Person ka naam',
      ),
      'Mohan',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add karo'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, 'Mohan'), findsOneWidget);
    expect(
      (await repository.listPaymentPeople()).map((person) => person.name),
      containsAll(<String>['Rohan', 'Mohan']),
    );

    await tester.tap(find.text('Mahina save karo'));
    await tester.pumpAndSettle();
    final saved = await repository.getMonthlyRecord(2026, 9);
    expect(saved?.expenses.map((expense) => expense.assigneeLabel), <String>[
      'Rohan',
      'Rohan',
      'Mohan',
    ]);
  });

  testWidgets('assigns recurring expenses to existing and new people', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MemoryLedgerRepository(
      paymentPeople: const <PaymentPerson>[
        PaymentPerson(id: 'rohan', name: 'Rohan'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: RecurringExpensesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Recurring kharch jodo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Kharch ka naam',
      ),
      'School fees',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Har mahine ki default rakam',
      ),
      '4000',
    );

    await tester.tap(find.widgetWithText(ActionChip, 'Nishu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Rohan'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Rohan'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Rohan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Naya person jodo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Person ka naam',
      ),
      'Mohan',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add karo'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Mohan'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save karo'));
    await tester.pumpAndSettle();

    final saved = (await repository.listRecurringExpenses()).single;
    expect(saved.assignedPersonName, 'Mohan');
    expect(saved.assignedPersonId, isNotEmpty);
    expect(find.textContaining('Mohan'), findsOneWidget);
    expect(
      (await repository.listPaymentPeople()).map((person) => person.name),
      containsAll(<String>['Rohan', 'Mohan']),
    );
  });

  testWidgets('saved records offer view, PDF and delete actions', (
    tester,
  ) async {
    final records = <MonthlyRecord>[
      const MonthlyRecord(
        id: '2026-01',
        year: 2026,
        month: 1,
        incomes: <IncomeEntry>[],
        expenses: <ExpenseEntry>[],
      ),
      const MonthlyRecord(
        id: '2026-03',
        year: 2026,
        month: 3,
        incomes: <IncomeEntry>[],
        expenses: <ExpenseEntry>[],
      ),
    ];
    final repository = MemoryLedgerRepository(records: records);
    await tester.pumpWidget(
      MaterialApp(
        home: SavedRecordsScreen(
          repository: repository,
          pdfReportService: PdfReportService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('March 2026'), findsOneWidget);
    await tester.tap(find.text('March 2026'));
    await tester.pumpAndSettle();
    expect(find.text('January 2026'), findsOneWidget);
    expect(find.text('February 2026'), findsNothing);
    await tester.tap(find.text('January 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Record dekho'), findsOneWidget);
    expect(find.text('PDF dekho ya print karo'), findsOneWidget);
    expect(find.text('PDF share karo'), findsOneWidget);
    expect(find.text('PDF save karo'), findsOneWidget);

    await tester.tap(find.text('Record delete karo'));
    await tester.pumpAndSettle();
    expect(find.text('Ye record delete karna hai?'), findsOneWidget);
    await tester.tap(find.text('Delete karo'));
    await tester.pumpAndSettle();

    expect(await repository.getMonthlyRecord(2026, 1), isNull);
    expect(await repository.getMonthlyRecord(2026, 3), isNotNull);
  });

  testWidgets('payment people can be added, renamed and deleted', (
    tester,
  ) async {
    final repository = MemoryLedgerRepository(
      paymentPeople: const <PaymentPerson>[
        PaymentPerson(id: 'rohan', name: 'Rohan'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: PaymentPeopleScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rohan'), findsOneWidget);
    await tester.tap(find.byTooltip('Naya person jodo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Person ka naam',
      ),
      'Mohan',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add karo'));
    await tester.pumpAndSettle();
    expect(find.text('Mohan'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Rohan'),
        matching: find.byTooltip('Naam badlo'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Person ka naam',
      ),
      'Rohit',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save karo'));
    await tester.pumpAndSettle();
    expect(find.text('Rohit'), findsOneWidget);
    expect(find.text('Rohan'), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Mohan'),
        matching: find.byTooltip('Person hatao'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hata do'));
    await tester.pumpAndSettle();
    expect(
      (await repository.listPaymentPeople()).map((person) => person.name),
      isNot(contains('Mohan')),
    );
  });

  testWidgets('past month settings are locked', (tester) async {
    useTallSurface(tester);
    final repository = MemoryLedgerRepository(
      initialDailyServiceSettings: const DailyServiceSettings(
        monthlyTuitionFee: 2600,
        milkRatePerKg: 60,
        defaultMilkQuantityKg: 1.5,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: DailyServicesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await selectDailyServicesMonth(tester, 2026, 7);

    await tester.tap(find.byTooltip('Tuition aur doodh settings'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Purane mahine ka rate lock hai'), findsOneWidget);
    expect(find.text('Tuition aur doodh settings'), findsNothing);
  });
}
