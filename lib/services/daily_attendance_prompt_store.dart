import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_service_attendance.dart';

abstract class DailyAttendancePromptStore {
  Future<bool> hasHandled(String userId, DateTime date);

  Future<void> markHandled(String userId, DateTime date);
}

class SharedPreferencesDailyAttendancePromptStore
    implements DailyAttendancePromptStore {
  SharedPreferencesDailyAttendancePromptStore(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesDailyAttendancePromptStore> create() async {
    return SharedPreferencesDailyAttendancePromptStore(
      await SharedPreferences.getInstance(),
    );
  }

  String _key(String userId, DateTime date) =>
      'daily-attendance-prompt:$userId:${dailyAttendanceId(date)}';

  @override
  Future<bool> hasHandled(String userId, DateTime date) async =>
      _preferences.getBool(_key(userId, date)) ?? false;

  @override
  Future<void> markHandled(String userId, DateTime date) async {
    await _preferences.setBool(_key(userId, date), true);
  }
}

class MemoryDailyAttendancePromptStore implements DailyAttendancePromptStore {
  final Set<String> _handled = <String>{};

  String _key(String userId, DateTime date) =>
      '$userId:${dailyAttendanceId(date)}';

  @override
  Future<bool> hasHandled(String userId, DateTime date) async =>
      _handled.contains(_key(userId, date));

  @override
  Future<void> markHandled(String userId, DateTime date) async {
    _handled.add(_key(userId, date));
  }
}
