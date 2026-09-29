import 'package:bookslot_mobile/models/service.dart';
import 'package:bookslot_mobile/models/slot.dart';
import 'package:bookslot_mobile/screens/booking_confirmation_screen.dart';
import 'package:bookslot_mobile/services/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same idea as `_FakeReminderScheduler` in `my_bookings_screen_test.dart`:
/// the real `FlutterLocalNotificationsPlugin` has no registered platform
/// channel in `flutter_test`, so this fake stands in for
/// `scheduleForAppointment` and reports whether notifications are enabled.
class _FakeReminderScheduler extends ReminderScheduler {
  _FakeReminderScheduler({required this.notificationsEnabled})
    : super(FlutterLocalNotificationsPlugin());

  final bool notificationsEnabled;

  @override
  Future<bool> scheduleForAppointment({
    required String appointmentId,
    required String serviceName,
    required DateTime startsAt,
    Duration leadTime = const Duration(hours: 2),
  }) async => notificationsEnabled;
}

const _service = Service(
  id: 'svc-1',
  name: 'Small Tattoo Session',
  durationMinutes: 60,
  priceAmount: 10000,
  currency: 'usd',
  depositType: 'fixed',
  bufferBeforeMinutes: 0,
  bufferAfterMinutes: 0,
);

final _slot = Slot(
  staffId: 'staff-1',
  startsAt: DateTime.utc(2026, 3, 1, 10),
  endsAt: DateTime.utc(2026, 3, 1, 11),
);

/// Mirrors what `DepositPaymentScreen` does: capture the scheduler's result
/// and hand it to the confirmation screen.
Future<Widget> _confirmationFor(ReminderScheduler reminders) async {
  final enabled = await reminders.scheduleForAppointment(
    appointmentId: 'apt-1',
    serviceName: _service.name,
    startsAt: _slot.startsAt,
  );
  return MaterialApp(
    home: BookingConfirmationScreen(
      service: _service,
      slot: _slot,
      notificationsEnabled: enabled,
    ),
  );
}

void main() {
  const message =
      "Notifications are off, so you won't get an on-device "
      'reminder for this appointment. You can turn them on in your phone\'s '
      'notification settings.';

  testWidgets('shows a notifications-off message when permission is denied', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _confirmationFor(
        _FakeReminderScheduler(notificationsEnabled: false),
      ),
    );

    expect(find.text(message), findsOneWidget);
    // The booking is still shown as confirmed.
    expect(find.text('Booked!'), findsOneWidget);
    expect(find.text('Small Tattoo Session is confirmed'), findsOneWidget);
  });

  testWidgets('does not show the message when notifications are enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _confirmationFor(
        _FakeReminderScheduler(notificationsEnabled: true),
      ),
    );

    expect(find.text(message), findsNothing);
    expect(find.text('Small Tattoo Session is confirmed'), findsOneWidget);
  });
}
