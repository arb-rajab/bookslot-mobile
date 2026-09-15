import 'dart:convert';

import 'package:bookslot_mobile/api/bookslot_api_client.dart';
import 'package:bookslot_mobile/app_services.dart';
import 'package:bookslot_mobile/models/booking.dart';
import 'package:bookslot_mobile/screens/my_bookings_screen.dart';
import 'package:bookslot_mobile/services/local_bookings_store.dart';
import 'package:bookslot_mobile/services/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `ReminderScheduler` wraps `FlutterLocalNotificationsPlugin`, whose
/// platform channel isn't registered in a plain widget-test environment
/// (no `initialize()`, no real platform binding) — calling through to it
/// throws `LateInitializationError`. This fake stands in so the cancel
/// flow's `reminders.cancelForAppointment` call can be exercised without
/// that platform dependency; it's not what's under test here.
class _FakeReminderScheduler extends ReminderScheduler {
  _FakeReminderScheduler() : super(FlutterLocalNotificationsPlugin());

  final cancelledAppointmentIds = <String>[];

  @override
  Future<void> cancelForAppointment(String appointmentId) async {
    cancelledAppointmentIds.add(appointmentId);
  }
}

Future<Widget> _wrap(
  BookslotApiClient api, {
  ReminderScheduler? reminders,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = LocalBookingsStore(prefs);
  await store.add(
    LocalBooking(
      appointmentId: 'apt-1',
      manageToken: 'manage-token-1',
      serviceName: 'Small Tattoo Session',
      startsAt: DateTime.utc(2026, 3, 1, 10),
    ),
  );

  return Provider<AppServices>(
    create: (_) => AppServices(
      api: api,
      bookingsStore: store,
      reminders: reminders ?? _FakeReminderScheduler(),
    ),
    child: const MaterialApp(home: MyBookingsScreen()),
  );
}

http.Response _statusResponse(String status) => http.Response(
  jsonEncode({
    'appointment_id': 'apt-1',
    'status': status,
    'starts_at': '2026-03-01T10:00:00Z',
    'ends_at': '2026-03-01T11:00:00Z',
  }),
  200,
);

void main() {
  testWidgets(
    'cancelling a booking calls the real cancel endpoint and updates status '
    'live',
    (tester) async {
      final mock = MockClient((request) async {
        if (request.method == 'POST') {
          expect(
            request.url.path,
            '/api/bookings/manage/manage-token-1/cancel',
          );
          return _statusResponse('cancelled');
        }
        return _statusResponse('confirmed');
      });
      final api = BookslotApiClient(
        baseUrl: 'https://demo.test/api',
        tenantSlug: 'demo-studio',
        httpClient: mock,
      );
      final reminders = _FakeReminderScheduler();

      await tester.pumpWidget(await _wrap(api, reminders: reminders));
      await tester.pumpAndSettle();

      expect(find.textContaining('confirmed'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cancelled'), findsOneWidget);
      expect(reminders.cancelledAppointmentIds, ['apt-1']);
    },
  );

  testWidgets(
    'a 409 from the cancel endpoint surfaces a clear message and does not '
    'mark the booking cancelled',
    (tester) async {
      final mock = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'error': 'INVALID_STATUS_TRANSITION'}),
            409,
          );
        }
        return _statusResponse('confirmed');
      });
      final api = BookslotApiClient(
        baseUrl: 'https://demo.test/api',
        tenantSlug: 'demo-studio',
        httpClient: mock,
      );

      await tester.pumpWidget(await _wrap(api));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();

      expect(find.text('Cancellation failed'), findsOneWidget);
      expect(
        find.textContaining('already cancelled or otherwise'),
        findsOneWidget,
      );
    },
  );
}
