import 'package:flutter/material.dart';

import '../app.dart';
import '../services/app_update_service.dart';
import '../services/attendance_reminder_service.dart';
import '../services/auth_service.dart';
import '../services/daily_attendance_prompt_store.dart';
import '../services/pdf_report_service.dart';
import '../widgets/app_shell.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authService,
    required this.repositoryFactory,
    required this.pdfReportService,
    required this.dailyAttendancePromptStore,
    required this.attendanceReminderService,
    required this.appUpdateService,
    super.key,
  });

  final AuthService authService;
  final LedgerRepositoryFactory repositoryFactory;
  final PdfReportService pdfReportService;
  final DailyAttendancePromptStore dailyAttendancePromptStore;
  final AttendanceReminderService attendanceReminderService;
  final AppUpdateService appUpdateService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: authService.authStateChanges(),
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: AppStatusView(
              icon: Icons.cloud_off_outlined,
              title: 'Login check nahi hua',
              message: 'Internet check karke app dobara kholo.',
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Scaffold(
            body: AppLoadingView(label: 'Account check ho raha hai...'),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(authService: authService);
        }
        return HomeScreen(
          user: user,
          authService: authService,
          repository: repositoryFactory(user.id),
          dailyAttendancePromptStore: dailyAttendancePromptStore,
          attendanceReminderService: attendanceReminderService,
          pdfReportService: pdfReportService,
          appUpdateService: appUpdateService,
        );
      },
    );
  }
}
