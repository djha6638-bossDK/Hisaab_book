import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

tz.Location resolveReminderTimeZone(String deviceTimeZone) {
  const aliases = <String, String>{
    'asia/calcutta': 'Asia/Kolkata',
    'asia/culcutta': 'Asia/Kolkata',
  };
  final normalizedTimeZone = deviceTimeZone.trim();
  final timeZoneName =
      aliases[normalizedTimeZone.toLowerCase()] ?? normalizedTimeZone;

  try {
    return tz.getLocation(timeZoneName);
  } catch (_) {
    // The app is India-specific, so an invalid device-provided ID must not
    // prevent a daily reminder from being scheduled.
    return tz.getLocation('Asia/Kolkata');
  }
}

class AttendanceReminderTime {
  const AttendanceReminderTime({required this.hour, required this.minute});

  final int hour;
  final int minute;
}

abstract class AttendanceReminderService {
  Future<void> initialize();

  Future<bool> hasRequiredPermissions();

  Future<bool> requestRequiredPermissions();

  Future<AttendanceReminderTime?> getReminderTime(String userId);

  Future<void> scheduleDailyReminder(
    String userId,
    AttendanceReminderTime time,
  );

  Future<void> cancelDailyReminder(String userId);
}

class LocalAttendanceReminderService implements AttendanceReminderService {
  LocalAttendanceReminderService({
    FlutterLocalNotificationsPlugin? notifications,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 4101;
  static const _channelId = 'daily_attendance_reminder';
  static const _channelName = 'Daily attendance reminders';
  static const _channelDescription =
      'Reminds you to fill tuition and milk attendance.';

  final FlutterLocalNotificationsPlugin _notifications;
  late final SharedPreferences _preferences;
  bool _initialized = false;
  Future<void>? _initialization;

  String _timeKey(String userId) => 'attendance-reminder-time:$userId';

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    final activeInitialization = _initialization;
    if (activeInitialization != null) {
      await activeInitialization;
      return;
    }
    final initialization = _initialize();
    _initialization = initialization;
    await initialization;
  }

  Future<void> _initialize() async {
    _preferences = await SharedPreferences.getInstance();
    tz.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(resolveReminderTimeZone(localTimezone));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_attendance_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(settings);
    _initialized = true;
  }

  @override
  Future<bool> hasRequiredPermissions() async {
    await initialize();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;
    final notificationsEnabled =
        await android.areNotificationsEnabled() ?? false;
    final exactAlarmsEnabled =
        await android.canScheduleExactNotifications() ?? false;
    return notificationsEnabled && exactAlarmsEnabled;
  }

  @override
  Future<bool> requestRequiredPermissions() async {
    await initialize();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true;

    final notificationsEnabled =
        await android.requestNotificationsPermission() ??
        await android.areNotificationsEnabled() ??
        false;
    if (!notificationsEnabled) return false;

    final exactAlarmsEnabled =
        await android.requestExactAlarmsPermission() ??
        await android.canScheduleExactNotifications() ??
        false;
    return exactAlarmsEnabled;
  }

  @override
  Future<AttendanceReminderTime?> getReminderTime(String userId) async {
    await initialize();
    final value = _preferences.getString(_timeKey(userId));
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return AttendanceReminderTime(hour: hour, minute: minute);
  }

  @override
  Future<void> scheduleDailyReminder(
    String userId,
    AttendanceReminderTime time,
  ) async {
    await initialize();
    if (!await hasRequiredPermissions()) {
      throw StateError('Notification permissions are not enabled.');
    }

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        icon: 'ic_attendance_notification',
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _notifications.zonedSchedule(
      _notificationId,
      'Attendance reminder',
      'Tuition and milk attendance fill karna baaki hai.',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    await _preferences.setString(
      _timeKey(userId),
      '${time.hour}:${time.minute}',
    );
  }

  @override
  Future<void> cancelDailyReminder(String userId) async {
    await initialize();
    await _notifications.cancel(_notificationId);
    await _preferences.remove(_timeKey(userId));
  }
}

class MemoryAttendanceReminderService implements AttendanceReminderService {
  MemoryAttendanceReminderService({
    this.permissionsGranted = false,
    this.permissionRequestResult = true,
  });

  bool permissionsGranted;
  bool permissionRequestResult;
  AttendanceReminderTime? reminderTime;
  int permissionRequestCount = 0;
  int scheduleCount = 0;
  int cancelCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasRequiredPermissions() async => permissionsGranted;

  @override
  Future<bool> requestRequiredPermissions() async {
    permissionRequestCount++;
    permissionsGranted = permissionRequestResult;
    return permissionsGranted;
  }

  @override
  Future<AttendanceReminderTime?> getReminderTime(String userId) async =>
      reminderTime;

  @override
  Future<void> scheduleDailyReminder(
    String userId,
    AttendanceReminderTime time,
  ) async {
    if (!permissionsGranted) {
      throw StateError('Notification permissions are not enabled.');
    }
    reminderTime = time;
    scheduleCount++;
  }

  @override
  Future<void> cancelDailyReminder(String userId) async {
    reminderTime = null;
    cancelCount++;
  }
}
