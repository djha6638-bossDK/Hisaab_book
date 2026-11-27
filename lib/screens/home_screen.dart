import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/month_utils.dart';
import '../core/user_error.dart';
import '../core/year_utils.dart';
import '../domain/monthly_record_logic.dart';
import '../models/monthly_record.dart';
import '../repositories/ledger_repository.dart';
import '../services/app_update_service.dart';
import '../services/attendance_reminder_service.dart';
import '../services/auth_service.dart';
import '../services/daily_attendance_prompt_store.dart';
import '../services/daily_service_settings_resolver.dart';
import '../services/pdf_report_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/app_update_card.dart';
import '../widgets/home_drawer.dart';
import 'daily_attendance_screen.dart';
import 'daily_services_screen.dart';
import 'income_setup_dialog.dart';
import 'monthly_record_screen.dart';
import 'payment_people_screen.dart';
import 'recurring_expenses_screen.dart';
import 'saved_records_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.user,
    required this.authService,
    required this.repository,
    required this.attendanceReminderService,
    required this.pdfReportService,
    required this.dailyAttendancePromptStore,
    this.appUpdateService = const AppUpdateService.disabled(),
    super.key,
  });

  final AuthUser user;
  final AuthService authService;
  final LedgerRepository repository;
  final AttendanceReminderService attendanceReminderService;
  final PdfReportService pdfReportService;
  final DailyAttendancePromptStore dailyAttendancePromptStore;
  final AppUpdateService appUpdateService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _defaultReminderTime = AttendanceReminderTime(
    hour: 20,
    minute: 0,
  );

  late int _selectedMonth;
  late int _selectedYear;
  bool _openingMonth = false;
  bool _loggingOut = false;
  bool _checkingReminder = true;
  bool _reminderPermissionsReady = false;
  AttendanceReminderTime? _reminderTime;
  AttendanceReminderTime? _lastReminderTime;
  bool _showAttendanceBanner = false;
  String? _attendanceCheckError;
  String _appVersion = '';
  AppUpdateInfo? _availableUpdate;
  bool _updateDownloading = false;
  double _updateProgress = 0;
  bool _updateCheckInFlight = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadReminderState();
    _loadAttendanceBanner();
    _loadAppVersion();
    _checkForUpdate();
  }

  Future<void> _loadAppVersion() async {
    try {
      final installed = await widget.appUpdateService.installedVersion();
      if (!mounted) return;
      setState(() => _appVersion = installed.versionName);
    } catch (_) {
      // Version sirf About me dikhta hai, isliye failure silent rahegi.
    }
  }

  Future<void> _checkForUpdate({bool force = false}) async {
    if (_updateCheckInFlight) return;
    _updateCheckInFlight = true;
    try {
      final update = await widget.appUpdateService.checkForUpdate(
        force: force,
      );
      if (!mounted) return;
      setState(() => _availableUpdate = update);
    } catch (_) {
      // Update check fail hone se home screen block nahi hogi.
    } finally {
      _updateCheckInFlight = false;
    }
  }

  Future<void> _dismissUpdate() async {
    final update = _availableUpdate;
    if (update == null) return;
    setState(() => _availableUpdate = null);
    try {
      await widget.appUpdateService.skipVersion(update);
    } catch (_) {
      // Skip save fail ho jaye to agli launch par card dobara aa sakta hai.
    }
  }

  Future<void> _installUpdate() async {
    final update = _availableUpdate;
    if (update == null || _updateDownloading) return;
    setState(() {
      _updateDownloading = true;
      _updateProgress = 0;
    });
    try {
      final path = await widget.appUpdateService.downloadApk(
        update,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _updateProgress = progress);
        },
      );
      if (!mounted) return;
      final result = await widget.appUpdateService.installApk(path);
      if (!mounted) return;
      setState(() => _updateDownloading = false);
      if (result != AppUpdateInstallResult.opened) {
        await _showUpdateInstallHelp(update, result);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _updateDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              error,
              fallback: 'Update install nahi ho paya. Phir try karo.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showUpdateInstallHelp(
    AppUpdateInfo update,
    AppUpdateInstallResult result,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update install nahi hua'),
        content: Text(
          result == AppUpdateInstallResult.permissionDenied
              ? 'Android settings me Hisaab Book ke liye "Install unknown '
                    'apps" allow karo, phir Update karo dobara dabao.'
              : 'Installer khul nahi paya. Neeche se browser me release page '
                    'kholo, APK download karke install karo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Band karo'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await launchUrl(
                update.releasePageUri,
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Browser se kholo'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAttendanceBanner() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _attendanceCheckError = null;
    });
    try {
      final handled = await widget.dailyAttendancePromptStore.hasHandled(
        widget.user.id,
        today,
      );
      if (handled) {
        if (!mounted) return;
        setState(() {
          _showAttendanceBanner = false;
        });
        return;
      }
      final settings = await widget.repository.getDailyServiceSettings();
      if (settings == null) {
        if (!mounted) return;
        setState(() {
          _showAttendanceBanner = false;
        });
        return;
      }
      final entry = await widget.repository.getDailyServiceAttendance(today);
      if (!mounted) return;
      setState(() {
        _showAttendanceBanner = entry == null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _attendanceCheckError = friendlyError(
          error,
          fallback: 'Attendance check nahi hui.',
        );
      });
    }
  }

  Future<void> _markTodayHandled() async {
    final now = DateTime.now();
    await widget.dailyAttendancePromptStore.markHandled(
      widget.user.id,
      DateTime(now.year, now.month, now.day),
    );
  }

  Future<void> _skipTodayAttendance() async {
    try {
      await _markTodayHandled();
      if (!mounted) return;
      setState(() => _showAttendanceBanner = false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(error, fallback: 'Skip save nahi hua. Phir koshish karo.'),
          ),
        ),
      );
    }
  }

  Future<void> _openTodayAttendance() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    try {
      final settings = await resolveDailyServiceMonthSettings(
        repository: widget.repository,
        year: today.year,
        month: today.month,
      );
      if (!mounted) return;
      if (settings == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pehle Tuition & Milk settings bharo.'),
          ),
        );
        return;
      }
      final entry = await widget.repository.getDailyServiceAttendance(today);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DailyAttendanceScreen(
            repository: widget.repository,
            date: today,
            settings: settings,
            initialAttendance: entry,
            onCompleted: _markTodayHandled,
            onSkipped: _skipTodayAttendance,
          ),
        ),
      );
      await _loadAttendanceBanner();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              error,
              fallback: 'Attendance screen nahi khuli. Phir koshish karo.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _loadReminderState() async {
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        widget.attendanceReminderService.hasRequiredPermissions(),
        widget.attendanceReminderService.getReminderTime(widget.user.id),
      ]);
      if (!mounted) return;
      setState(() {
        _reminderPermissionsReady = results[0] as bool;
        _reminderTime = results[1] as AttendanceReminderTime?;
        _lastReminderTime = _reminderTime;
        _checkingReminder = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingReminder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(error, fallback: 'Reminder setting check nahi hui.'),
          ),
        ),
      );
    }
  }

  Future<bool> _enableReminderPermissions({
    bool showSuccessMessage = true,
  }) async {
    if (_checkingReminder) return false;
    setState(() => _checkingReminder = true);
    try {
      final granted = await widget.attendanceReminderService
          .requestRequiredPermissions();
      if (!mounted) return false;
      setState(() {
        _reminderPermissionsReady = granted;
        _checkingReminder = false;
      });
      if (!granted || showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? 'Reminder ki permission mil gayi.'
                  : 'Reminder ke liye notification aur alarm permission chahiye.',
            ),
          ),
        );
      }
      return granted;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _checkingReminder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(error, fallback: 'Reminder on nahi ho paya.'),
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _showReminderSettings() async {
    if (_checkingReminder) return;
    final reminderTime = _reminderTime;
    final timeLabel = reminderTime == null
        ? 'Set nahi hai'
        : TimeOfDay(
            hour: reminderTime.hour,
            minute: reminderTime.minute,
          ).format(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Attendance reminder'),
              subtitle: Text(
                reminderTime == null ? 'Abhi band hai' : 'On - $timeLabel',
              ),
            ),
            SwitchListTile(
              key: const ValueKey<String>('reminder-toggle'),
              secondary: const Icon(Icons.toggle_on_outlined),
              title: const Text('Reminder on/off'),
              value: reminderTime != null,
              onChanged: (value) {
                Navigator.of(sheetContext).pop();
                if (value) {
                  _turnReminderOn();
                } else {
                  _disableReminder();
                }
              },
            ),
            ListTile(
              key: const ValueKey<String>('reminder-time-tile'),
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Time badlo'),
              subtitle: Text(
                reminderTime == null
                    ? 'Reminder on karke time chuno'
                    : 'Abhi $timeLabel par aata hai',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _setReminderTime();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _turnReminderOn() async {
    if (!_reminderPermissionsReady) {
      final granted = await _enableReminderPermissions(
        showSuccessMessage: false,
      );
      if (!granted || !mounted) return;
    }
    await _enableReminder();
  }

  Future<void> _enableReminder() async {
    final reminderTime = _lastReminderTime ?? _defaultReminderTime;
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _checkingReminder = true);
    try {
      await widget.attendanceReminderService.scheduleDailyReminder(
        widget.user.id,
        reminderTime,
      );
      if (!mounted) return;
      setState(() {
        _reminderTime = reminderTime;
        _lastReminderTime = reminderTime;
        _checkingReminder = false;
      });
      final formattedTime = TimeOfDay(
        hour: reminderTime.hour,
        minute: reminderTime.minute,
      ).format(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance reminder $formattedTime par on ho gaya.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingReminder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(error, fallback: 'Reminder on nahi ho paya.'),
          ),
        ),
      );
    }
  }

  Future<void> _disableReminder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey<String>('disable-reminder-dialog'),
        title: const Text('Reminder band karna hai?'),
        content: const Text(
          'Roz ka attendance reminder band ho jayega. Baad me settings se '
          'dobara on kar sakte ho.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('On rakho'),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm-disable-reminder'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Band karo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _checkingReminder = true);
    try {
      await widget.attendanceReminderService.cancelDailyReminder(
        widget.user.id,
      );
      if (!mounted) return;
      setState(() {
        _lastReminderTime = _reminderTime;
        _reminderTime = null;
        _checkingReminder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance reminder band ho gaya.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingReminder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(error, fallback: 'Reminder band nahi ho paya.'),
          ),
        ),
      );
    }
  }

  Future<void> _setReminderTime() async {
    if (_checkingReminder) return;
    if (!_reminderPermissionsReady) {
      final granted = await _enableReminderPermissions(
        showSuccessMessage: false,
      );
      if (!granted || !mounted) return;
    }
    final initialTime = _reminderTime == null
        ? TimeOfDay(
            hour: (_lastReminderTime ?? _defaultReminderTime).hour,
            minute: (_lastReminderTime ?? _defaultReminderTime).minute,
          )
        : TimeOfDay(hour: _reminderTime!.hour, minute: _reminderTime!.minute);
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Attendance reminder ka time chuno',
    );
    if (selected == null || !mounted) return;

    final reminderTime = AttendanceReminderTime(
      hour: selected.hour,
      minute: selected.minute,
    );
    setState(() => _checkingReminder = true);
    try {
      await widget.attendanceReminderService.scheduleDailyReminder(
        widget.user.id,
        reminderTime,
      );
      if (!mounted) return;
      setState(() {
        _reminderTime = reminderTime;
        _lastReminderTime = reminderTime;
        _checkingReminder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance reminder ${selected.format(context)} par set ho gaya.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _checkingReminder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(error, fallback: 'Reminder set nahi hua.'),
          ),
        ),
      );
    }
  }

  Future<void> _openMonth() async {
    if (_openingMonth) return;
    setState(() => _openingMonth = true);
    try {
      final existing = await widget.repository.getMonthlyRecord(
        _selectedYear,
        _selectedMonth,
      );
      if (!mounted) return;
      if (existing != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MonthlyRecordScreen(
              repository: widget.repository,
              initialRecord: existing,
              viewOnly: true,
            ),
          ),
        );
        return;
      }

      // The dialog and the next screen show their own progress state, so the
      // home button no longer needs to keep its loading spinner running behind
      // a modal route.
      setState(() => _openingMonth = false);
      final setup = await showDialog<IncomeSetupResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const IncomeSetupDialog(),
      );
      if (setup == null || !mounted) return;

      final recurring = await widget.repository.listRecurringExpenses();
      if (!mounted) return;
      final record = MonthlyRecord(
        id: monthlyRecordId(_selectedYear, _selectedMonth),
        year: _selectedYear,
        month: _selectedMonth,
        incomes: setup.incomes,
        expenses: activeRecurringExpenses(recurring),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MonthlyRecordScreen(
            repository: widget.repository,
            initialRecord: record,
            viewOnly: false,
            isNewRecord: true,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(
              error,
              fallback: 'Mahina khul nahi paya. Phir koshish karo.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingMonth = false);
    }
  }

  void _pushPage(Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _openDrawerPage(Widget page) {
    Navigator.of(context).pop();
    _pushPage(page);
  }

  void _openSavedRecords() {
    _openDrawerPage(
      SavedRecordsScreen(
        repository: widget.repository,
        pdfReportService: widget.pdfReportService,
      ),
    );
  }

  void _openRecurringExpenses() {
    _openDrawerPage(RecurringExpensesScreen(repository: widget.repository));
  }

  void _openDailyServicesFromDrawer() {
    _openDrawerPage(DailyServicesScreen(repository: widget.repository));
  }

  void _openDailyServices() {
    _pushPage(DailyServicesScreen(repository: widget.repository));
  }

  void _openPaymentPeople() {
    _openDrawerPage(PaymentPeopleScreen(repository: widget.repository));
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(Icons.logout),
            SizedBox(width: 10),
            Text('Logout karna hai?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Kya is account se sign out karna hai?'),
            const SizedBox(height: 14),
            Text(
              widget.user.email.isEmpty
                  ? 'Email nahi mila'
                  : widget.user.email,
              key: const ValueKey<String>('logout-account-email'),
              style: Theme.of(
                dialogContext,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await widget.authService.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(error, fallback: 'Logout nahi ho paya.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _showAppInfo() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(Icons.info_outline),
            SizedBox(width: 10),
            Text('Hisaab Book ke baare me'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Ghar ke mahine ka income, kharch, recurring payment aur '
                'tuition-doodh ka hisaab ek jagah rakhne wali app.',
              ),
              const SizedBox(height: 20),
              const _AppInfoRow(
                icon: Icons.person_outline,
                label: 'Banane wale',
                value: 'Dhiraj Kumar Jha',
              ),
              const SizedBox(height: 14),
              const _AppInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: 'djha6638@gmail.com',
                selectable: true,
              ),
              const SizedBox(height: 14),
              _AppInfoRow(
                icon: Icons.apps_outlined,
                label: 'Version',
                value: _appVersion.isEmpty ? '—' : _appVersion,
              ),
              const SizedBox(height: 20),
              const Text(
                'Har mahina alag record me save hota hai. Purane record, '
                'payment log aur tuition-doodh attendance apne rate par '
                'lock rehte hain.',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Band karo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = availableYears();
    final reminderEnabled = _reminderTime != null;
    return Scaffold(
      drawer: HomeDrawer(
        displayName: widget.user.displayName,
        onOpenSavedRecords: _openSavedRecords,
        onOpenRecurringExpenses: _openRecurringExpenses,
        onOpenDailyServices: _openDailyServicesFromDrawer,
        onOpenPaymentPeople: _openPaymentPeople,
      ),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.account_balance_wallet_outlined),
            SizedBox(width: 10),
            Text('Hisaab Book'),
          ],
        ),
        actions: <Widget>[
          Tooltip(
            message: 'Attendance reminder settings',
            child: InkResponse(
              key: const ValueKey<String>('attendance-reminder-button'),
              onTap: _checkingReminder ? null : _showReminderSettings,
              onLongPress: _checkingReminder ? null : _setReminderTime,
              radius: 24,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _checkingReminder
                    ? const SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : AnimatedContainer(
                        key: const ValueKey<String>(
                          'attendance-reminder-icon-cover',
                        ),
                        duration: const Duration(milliseconds: 180),
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: reminderEnabled
                              ? Colors.blue.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: reminderEnabled
                              ? Border.all(
                                  color: Colors.blue.withValues(alpha: 0.32),
                                )
                              : null,
                        ),
                        child: Icon(
                          reminderEnabled
                              ? Icons.notifications_rounded
                              : Icons.notifications_none_rounded,
                          color: reminderEnabled ? Colors.blue : null,
                        ),
                      ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'App ke baare me',
            onPressed: _showAppInfo,
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: AppContent(
          maxWidth: 820,
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait(<Future<void>>[
                _loadAttendanceBanner(),
                _checkForUpdate(force: true),
              ]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Namaste',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.user.displayName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mahina chuno aur apna hisaab dekho ya update karo.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (_availableUpdate != null) ...<Widget>[
                  AppUpdateCard(
                    update: _availableUpdate!,
                    downloading: _updateDownloading,
                    progress: _updateProgress,
                    onUpdate: _installUpdate,
                    onDismiss: _dismissUpdate,
                  ),
                  const SizedBox(height: 16),
                ],
                AppSurface(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const AppSectionHeader(
                        title: 'Mahine ka hisaab',
                        subtitle:
                            'Purana record kholo ya naya mahina shuru karo.',
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 460;
                          final monthField = DropdownButtonFormField<int>(
                            key: const ValueKey<String>('home-month-field'),
                            initialValue: _selectedMonth,
                            decoration: const InputDecoration(
                              labelText: 'Mahina',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            items: List<DropdownMenuItem<int>>.generate(
                              12,
                              (index) => DropdownMenuItem<int>(
                                value: index + 1,
                                child: Text(monthNames[index]),
                              ),
                            ),
                            onChanged: _openingMonth
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _selectedMonth = value);
                                  },
                          );
                          final yearField = DropdownButtonFormField<int>(
                            key: const ValueKey<String>('home-year-field'),
                            initialValue: _selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Saal',
                              prefixIcon: Icon(Icons.event_outlined),
                            ),
                            items: <DropdownMenuItem<int>>[
                              for (final year in years)
                                DropdownMenuItem<int>(
                                  value: year,
                                  child: Text('$year'),
                                ),
                            ],
                            onChanged: _openingMonth
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _selectedYear = value);
                                  },
                          );
                          if (compact) {
                            return Column(
                              children: <Widget>[
                                monthField,
                                const SizedBox(height: 12),
                                yearField,
                              ],
                            );
                          }
                          return Row(
                            children: <Widget>[
                              Expanded(child: monthField),
                              const SizedBox(width: 12),
                              Expanded(child: yearField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _openingMonth ? null : _openMonth,
                        icon: _openingMonth
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                        label: const Text('Mahina kholo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSurface(
                  padding: EdgeInsets.zero,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: const ValueKey<String>('home-tuition-milk'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: _openDailyServices,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.fact_check_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Tuition & Milk',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Daily attendance aur amount',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_attendanceCheckError != null) ...<Widget>[
                  AppSurface(
                    color: const Color(0xfffff7ed),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.cloud_off_outlined, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_attendanceCheckError!)),
                        TextButton(
                          onPressed: _loadAttendanceBanner,
                          child: const Text('Phir try karo'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_showAttendanceBanner)
                  AppSurface(
                    key: const ValueKey<String>('today-attendance-banner'),
                    color: const Color(0xfffff7ed),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.pending_actions_outlined,
                              color: Color(0xff9a5b00),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Aaj ki attendance baaki hai',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Tuition & Milk ka hisaab aaj tak nahi '
                                    'bhara. Abhi bhar do.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 420;
                            final fillButton = FilledButton.icon(
                              key: const ValueKey<String>(
                                'today-attendance-button',
                              ),
                              onPressed: _openTodayAttendance,
                              icon: const Icon(Icons.fact_check_outlined),
                              label: const Text('Attendance bharo'),
                            );
                            final skipButton = OutlinedButton(
                              key: const ValueKey<String>(
                                'skip-today-attendance',
                              ),
                              onPressed: _skipTodayAttendance,
                              child: const Text('Aaj skip karo'),
                            );
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  fillButton,
                                  const SizedBox(height: 8),
                                  skipButton,
                                ],
                              );
                            }
                            return Row(
                              children: <Widget>[
                                Expanded(child: fillButton),
                                const SizedBox(width: 10),
                                Expanded(child: skipButton),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppInfoRow extends StatelessWidget {
  const _AppInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              if (selectable)
                SelectableText(value, style: valueStyle)
              else
                Text(value, style: valueStyle),
            ],
          ),
        ),
      ],
    );
  }
}
