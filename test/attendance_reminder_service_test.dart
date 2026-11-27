import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_book/services/attendance_reminder_service.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);

  test('normalizes the invalid Calcutta spelling returned by the device', () {
    expect(resolveReminderTimeZone('Asia/culcutta').name, 'Asia/Kolkata');
  });

  test('falls back to India time for an unsupported device timezone', () {
    expect(resolveReminderTimeZone('Invalid/Timezone').name, 'Asia/Kolkata');
  });
}
