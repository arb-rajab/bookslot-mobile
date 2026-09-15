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

  Future<void> scheduleForAppointment({
    required String appointmentId,
    required String serviceName,
    required DateTime startsAt,
    Duration leadTime = const Duration(hours: 2),
  }) async {
    final fireAt = startsAt.subtract(leadTime);
    if (fireAt.isBefore(DateTime.now())) {
      return;
    }

    await _plugin.zonedSchedule(
      _notificationId(appointmentId),
      'Upcoming appointment',
      '$serviceName is coming up soon.',
      tz.TZDateTime.from(fireAt, tz.local),
      const NotificationDetails(
        android: _androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelForAppointment(String appointmentId) =>
      _plugin.cancel(_notificationId(appointmentId));
}
