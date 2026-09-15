import 'dart:convert';

import 'package:bookslot_mobile/api/bookslot_api_client.dart';
import 'package:bookslot_mobile/app_services.dart';
import 'package:bookslot_mobile/models/service.dart';
import 'package:bookslot_mobile/models/slot.dart';
import 'package:bookslot_mobile/screens/booking_form_screen.dart';
import 'package:bookslot_mobile/services/local_bookings_store.dart';
import 'package:bookslot_mobile/services/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _service = Service.fromJson({
  'id': 'svc-1',
  'name': 'Small Tattoo Session',
  'duration_minutes': 60,
  'price_amount': 20000,
  'currency': 'usd',
  'deposit_type': 'fixed',
  'deposit_fixed_amount': 5000,
  'deposit_percentage_bps': null,
  'buffer_before_minutes': 0,
  'buffer_after_minutes': 15,
});

final _slot = Slot(
  staffId: 'staff-1',
  startsAt: DateTime.utc(2026, 3, 1, 10),
  endsAt: DateTime.utc(2026, 3, 1, 11),
);

Future<Widget> _wrap(BookslotApiClient api) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return Provider<AppServices>(
    create: (_) => AppServices(
      api: api,
      bookingsStore: LocalBookingsStore(prefs),
      reminders: ReminderScheduler(FlutterLocalNotificationsPlugin()),
    ),
    child: MaterialApp(
      home: BookingFormScreen(service: _service, slot: _slot),
    ),
  );
}

void main() {
  testWidgets('blocks submission until the mandate checkbox is accepted', (
    tester,
  ) async {
    var bookingCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/mandate')) {
        return http.Response(
          jsonEncode({
            'template_version': 'v1',
            'text': 'You are booking a deposit.',
            'balance_amount_disclosed': 15000,
          }),
          200,
        );
      }
      bookingCalls++;
      return http.Response('{}', 201);
    });
    final api = BookslotApiClient(
      baseUrl: 'https://demo.test/api',
      tenantSlug: 'demo-studio',
      httpClient: mock,
    );

    await tester.pumpWidget(await _wrap(api));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('nameField')), 'Alex Rivera');
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'alex@example.test',
    );
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();

    expect(
      find.text('You must accept the deposit terms to continue.'),
      findsOneWidget,
    );
    expect(bookingCalls, 0);
  });

  testWidgets('rejects an invalid email before ever calling the API', (
    tester,
  ) async {
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/mandate')) {
        return http.Response(
          jsonEncode({
            'template_version': 'v1',
            'text': 'mandate text',
            'balance_amount_disclosed': 15000,
          }),
          200,
        );
      }
      fail('booking endpoint should not be called when validation fails');
    });
    final api = BookslotApiClient(
      baseUrl: 'https://demo.test/api',
      tenantSlug: 'demo-studio',
      httpClient: mock,
    );

    await tester.pumpWidget(await _wrap(api));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('nameField')), 'Alex Rivera');
    await tester.enterText(find.byKey(const Key('emailField')), 'not-an-email');
    await tester.tap(find.byKey(const Key('mandateCheckbox')));
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });
}
