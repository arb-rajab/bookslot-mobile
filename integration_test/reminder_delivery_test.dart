import 'package:bookslot_mobile/services/reminder_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;

/// Backlog #9: does a reminder scheduled through the app's real
/// `ReminderScheduler` ever actually show up on Android?
///
/// No fakes: this goes through the real `flutter_local_notifications`
/// plugin, AlarmManager and NotificationManager, so it only means anything
/// on a device or emulator (see `.github/workflows/android-native.yml`).
/// It uses the production code path, lead-time maths included, with the
/// appointment placed so the reminder is due a few seconds from now, then
/// polls the notification shade via `getActiveNotifications()`.
///
/// If the app asks for the POST_NOTIFICATIONS runtime permission, the
/// workflow's `.github/scripts/allow-permission-dialogs.sh` taps "Allow" on
/// the real system dialog, the way a user would. Nothing grants it behind
/// the app's back.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a reminder scheduled for a booking is actually shown', (
    tester,
  ) async {
    tz.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    final reminders = ReminderScheduler(plugin);
    await reminders.initialize();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    await plugin.cancelAll();

    Future<String> diagnostics() async {
      final pending = await plugin.pendingNotificationRequests();
      return 'notificationsEnabled=${await android.areNotificationsEnabled()}, '
          'canScheduleExact=${await android.canScheduleExactNotifications()}, '
          'stillPending=${pending.map((p) => p.id).toList()}';
    }

    debugPrint(
      'reminder diagnostics before scheduling: ${await diagnostics()}',
    );

    // On Android 13+ this waits for the POST_NOTIFICATIONS prompt to be
    // answered. Fail with diagnostics rather than hang if nobody answers it.
    const leadTime = Duration(hours: 2);
    await reminders
        .scheduleForAppointment(
          appointmentId: 'apt-reminder-e2e',
          serviceName: 'Small Tattoo Session',
          startsAt: DateTime.now().add(leadTime + const Duration(seconds: 10)),
          leadTime: leadTime,
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () async => fail(
            'scheduleForAppointment did not complete within 60s; was the '
            'permission prompt shown and answered? (${await diagnostics()})',
          ),
        );

    ActiveNotification? shown;
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (shown == null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final active = await android.getActiveNotifications();
      shown = active
          .where((n) => n.title == 'Upcoming appointment')
          .firstOrNull;
    }

    final after = await diagnostics();
    debugPrint('reminder diagnostics after waiting: $after');
    await plugin.cancelAll();

    expect(
      shown,
      isNotNull,
      reason: 'no reminder notification appeared within 90s ($after)',
    );
    expect(shown!.body, 'Small Tattoo Session is coming up soon.');
  });
}
