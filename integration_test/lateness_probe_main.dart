import 'package:bookslot_mobile/app_services.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// App entry point for `.github/scripts/reminder-lateness-check.sh`
/// (backlog #11): how late does an inexact reminder actually arrive at a
/// realistic lead-time / booking-horizon scale, not just the ~4 minute scale
/// the reboot check happened to use (D-11)?
///
/// Not a `flutter test` file, for the same reason as `reboot_probe_main.dart`:
/// it needs to outlive `flutter test`'s own process, and, for the large-scale
/// trial, survive the check script advancing the device's system clock,
/// neither of which a Dart test can do.
///
/// Goes through the real `AppServices.bootstrap()` /
/// `ReminderScheduler.scheduleForAppointment`, with the product's real 2-hour
/// lead time. Only [_dueInMinutes] (how far out the alarm is due, i.e. how
/// far ahead of "now" `startsAt - leadTime` falls) is chosen by the caller,
/// via the `DUE_IN_MINUTES` dart-define, so the same probe drives both a
/// moderate real-time trial and a multi-day, clock-advanced one.
const _leadTime = Duration(hours: 2);
const _dueInMinutes = int.fromEnvironment('DUE_IN_MINUTES', defaultValue: 15);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('bookslot lateness probe'))),
    ),
  );

  try {
    final services = await AppServices.bootstrap();
    final startsAt = DateTime.now().add(
      _leadTime + const Duration(minutes: _dueInMinutes),
    );
    await services.reminders.scheduleForAppointment(
      appointmentId: 'apt-lateness-e2e',
      serviceName: 'Small Tattoo Session',
      startsAt: startsAt,
      leadTime: _leadTime,
    );
    final fireAtMs = startsAt.subtract(_leadTime).millisecondsSinceEpoch;
    // The script greps logcat for this exact line.
    debugPrint(
      'LATENESS_PROBE scheduled fireAtMs=$fireAtMs dueInMinutes=$_dueInMinutes',
    );
  } catch (e) {
    debugPrint('LATENESS_PROBE error: $e');
  }
}
