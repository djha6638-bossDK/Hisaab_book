import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/user_error.dart';
import 'firebase_options.dart';
import 'repositories/firestore_ledger_repository.dart';
import 'services/app_update_service.dart';
import 'services/attendance_reminder_service.dart';
import 'services/auth_service.dart';
import 'services/daily_attendance_prompt_store.dart';
import 'services/pdf_report_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<_AppDependencies> _initialization = _initialize();

  Future<_AppDependencies> _initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final firestore = FirebaseFirestore.instance;
    final promptStore =
        await SharedPreferencesDailyAttendancePromptStore.create();
    final reminderService = LocalAttendanceReminderService();
    return _AppDependencies(
      authService: FirebaseAuthService(
        auth: FirebaseAuth.instance,
        firestore: firestore,
      ),
      repositoryFactory: (userId) =>
          FirestoreLedgerRepository(firestore: firestore, userId: userId),
      dailyAttendancePromptStore: promptStore,
      attendanceReminderService: reminderService,
      pdfReportService: PdfReportService(),
      appUpdateService: AppUpdateService(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppDependencies>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupFailureApp(error: snapshot.error!);
        }
        final dependencies = snapshot.data;
        if (dependencies == null) return const _StartupApp();
        return HisaabBookApp(
          authService: dependencies.authService,
          repositoryFactory: dependencies.repositoryFactory,
          dailyAttendancePromptStore: dependencies.dailyAttendancePromptStore,
          attendanceReminderService: dependencies.attendanceReminderService,
          pdfReportService: dependencies.pdfReportService,
          appUpdateService: dependencies.appUpdateService,
        );
      },
    );
  }
}

class _AppDependencies {
  const _AppDependencies({
    required this.authService,
    required this.repositoryFactory,
    required this.dailyAttendancePromptStore,
    required this.attendanceReminderService,
    required this.pdfReportService,
    required this.appUpdateService,
  });

  final AuthService authService;
  final LedgerRepositoryFactory repositoryFactory;
  final DailyAttendancePromptStore dailyAttendancePromptStore;
  final AttendanceReminderService attendanceReminderService;
  final PdfReportService pdfReportService;
  final AppUpdateService appUpdateService;
}

class _StartupApp extends StatelessWidget {
  const _StartupApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b3a)),
        scaffoldBackgroundColor: const Color(0xfff4f7f5),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 56,
                color: Color(0xff176b3a),
              ),
              SizedBox(height: 18),
              Text(
                'Hisaab Book',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 18),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Hisaab Book start nahi ho paya.\n\n'
              '${friendlyError(error, fallback: 'App dobara kholo ya internet check karo.')}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
