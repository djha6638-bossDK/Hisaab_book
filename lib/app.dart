import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'repositories/ledger_repository.dart';
import 'screens/auth_gate.dart';
import 'services/app_update_service.dart';
import 'services/attendance_reminder_service.dart';
import 'services/auth_service.dart';
import 'services/daily_attendance_prompt_store.dart';
import 'services/pdf_report_service.dart';

typedef LedgerRepositoryFactory = LedgerRepository Function(String userId);

class HisaabBookApp extends StatelessWidget {
  const HisaabBookApp({
    required this.authService,
    required this.repositoryFactory,
    required this.pdfReportService,
    this.dailyAttendancePromptStore,
    this.attendanceReminderService,
    this.appUpdateService = const AppUpdateService.disabled(),
    super.key,
  });

  final AuthService authService;
  final LedgerRepositoryFactory repositoryFactory;
  final PdfReportService pdfReportService;
  final DailyAttendancePromptStore? dailyAttendancePromptStore;
  final AttendanceReminderService? attendanceReminderService;
  final AppUpdateService appUpdateService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hisaab Book',
      theme: AppTheme.light,
      home: AuthGate(
        authService: authService,
        repositoryFactory: repositoryFactory,
        dailyAttendancePromptStore:
            dailyAttendancePromptStore ?? MemoryDailyAttendancePromptStore(),
        attendanceReminderService:
            attendanceReminderService ?? MemoryAttendanceReminderService(),
        pdfReportService: pdfReportService,
        appUpdateService: appUpdateService,
      ),
    );
  }
}
