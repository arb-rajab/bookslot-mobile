import 'package:bookslot_mobile/app_services.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// App entry point for `.github/scripts/reboot-reminder-check.sh`: does a
/// scheduled reminder survive a device reboot?
///
/// This is not a `flutter test` file (there's no `_test.dart` suffix, so
/// `flutter test integration_test` skips it). A Dart test can't span a
/// reboot, and `flutter test` force-stops the app when it finishes. A
/// force-stop cancels the app's alarms and blocks BOOT_COMPLETED until the
/// next launch, so the test would break the thing it's checking. Instead, CI
/// builds this file as its own debug APK (`flutter build apk -t`), launches
/// it once with adb and reboots. It then checks AlarmManager and the
/// notification shade from the shell without reopening the app.
///
/// It goes through the app's real `AppServices.bootstrap()` and
/// `ReminderScheduler`, lead-time maths included. Only the appointment time
/// is chosen here: the reminder is due [_dueIn] from now, long enough for
/// the emulator to finish rebooting first.
const _dueIn = Duration(minutes: 5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('bookslot reboot probe'))),
    ),
  );

  try {
    final services = await AppServices.bootstrap();
    const leadTime = Duration(hours: 2);
    final startsAt = DateTime.now().add(leadTime + _dueIn);
    // Waits for the POST_NOTIFICATIONS prompt, which the script's
    // allow-permission-dialogs.sh answers.
    await services.reminders.scheduleForAppointment(
      appointmentId: 'apt-reboot-e2e',
      serviceName: 'Small Tattoo Session',
      startsAt: startsAt,
      leadTime: leadTime,
    );
    final fireAtMs = startsAt.subtract(leadTime).millisecondsSinceEpoch;
    // The script greps logcat for this exact line.
    debugPrint('REBOOT_PROBE scheduled fireAtMs=$fireAtMs');
  } catch (e) {
    debugPrint('REBOOT_PROBE error: $e');
  }
}
