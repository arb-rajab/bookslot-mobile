import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Schedules a local, on-device reminder notification ahead of an
/// appointment's start time.
///
/// bookslot's own backend already runs a real, RabbitMQ-backed reminder
/// pipeline server-side (Session 19, D-0046) — this app deliberately does
/// NOT duplicate that with a second, parallel push channel. Scheduling a
/// local notification from the booking's own `starts_at` is enough to
/// demonstrate the reminder UX end-to-end without standing up real push
/// infrastructure (APNs/FCM credentials) for a portfolio demo app. See the
/// repo's backlog for the tradeoffs of ever adding real push.
class ReminderScheduler {
  ReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _androidDetails = AndroidNotificationDetails(
    'appointment_reminders',
    'Appointment reminders',
    channelDescription: 'Reminds you ahead of an upcoming bookslot appointment',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  /// Notification IDs are derived from the appointment id's hash so
  /// rescheduling or cancelling the same appointment's reminder is
  /// idempotent without a separate id-mapping table.
  int _notificationId(String appointmentId) =>
      appointmentId.hashCode & 0x7fffffff;

  /// Schedules the reminder and returns whether the user will actually see
  /// it: `false` only when the OS reported notifications as disabled
  /// (declined POST_NOTIFICATIONS). The reminder is still scheduled in that
  /// case, and Android silently suppresses its display, so callers use this
  /// to tell the user. Returns `true` when notifications are enabled, when
  /// the state is unknown (iOS, where the Android permission API doesn't
  /// apply), or when there was nothing to schedule.
  Future<bool> scheduleForAppointment({
    required String appointmentId,
    required String serviceName,
    required DateTime startsAt,
    Duration leadTime = const Duration(hours: 2),
  }) async {
    final fireAt = startsAt.subtract(leadTime);
    if (fireAt.isBefore(DateTime.now())) {
      return true;
    }

    // Android 13+ shows no notifications until the user grants
    // POST_NOTIFICATIONS, and nothing else in the app asks for it. Ask
    // here, the first time there's a reminder worth showing. Once the user
    // has answered, this returns without prompting. It's a no-op on older
    // Android, and null (skipped) on iOS.
    final notificationsEnabled = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin.zonedSchedule(
      _notificationId(appointmentId),
      'Upcoming appointment',
      '$serviceName is coming up soon.',
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(
        android: _androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact on purpose. Exact alarms need SCHEDULE_EXACT_ALARM, which
      // Android 14 no longer pre-grants and the user must enable in
      // Settings (without it zonedSchedule throws
      // `exact_alarms_not_permitted`), or USE_EXACT_ALARM, which Play
      // reserves for alarm-clock/calendar apps. This isn't just "not to
      // the second": measured worst-case delivery is up to ~1 hour after
      // the scheduled time (AlarmManager's inexact window is capped at
      // 1 hour, and real-elapsed trials landed delivery at the far edge
      // of that window, not near the front). Accepted as a platform
      // constraint rather than adding the exact-alarm permission prompt.
      // See 04-decisions.md D-10, D-12, D-13, D-14 and backlog #11.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return notificationsEnabled != false;
  }

  Future<void> cancelForAppointment(String appointmentId) =>
      _plugin.cancel(_notificationId(appointmentId));
}
