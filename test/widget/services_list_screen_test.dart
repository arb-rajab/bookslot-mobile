import 'dart:convert';

import 'package:bookslot_mobile/api/bookslot_api_client.dart';
import 'package:bookslot_mobile/app_services.dart';
import 'package:bookslot_mobile/screens/services_list_screen.dart';
import 'package:bookslot_mobile/services/local_bookings_store.dart';
import 'package:bookslot_mobile/services/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _wrap(BookslotApiClient api) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return Provider<AppServices>(
    create: (_) => AppServices(
      api: api,
      bookingsStore: LocalBookingsStore(prefs),
      reminders: ReminderScheduler(FlutterLocalNotificationsPlugin()),
    ),
    child: const MaterialApp(home: ServicesListScreen()),
  );
}

void main() {
  testWidgets(
    'shows services returned by the API with formatted price and deposit',
    (tester) async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'services': [
              {
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
              },
            ],
          }),
          200,
        );
      });
      final api = BookslotApiClient(
        baseUrl: 'https://demo.test/api',
        tenantSlug: 'demo-studio',
        httpClient: mock,
      );

      await tester.pumpWidget(await _wrap(api));
      await tester.pumpAndSettle();

      expect(find.text('Small Tattoo Session'), findsOneWidget);
      expect(find.text('60 min · Deposit 50.00 USD'), findsOneWidget);
      expect(find.text('200.00 USD'), findsOneWidget);
    },
  );

  testWidgets('shows a retry button when the services request fails', (
    tester,
  ) async {
    final mock = MockClient((request) async => http.Response('', 500));
    final api = BookslotApiClient(
      baseUrl: 'https://demo.test/api',
      tenantSlug: 'demo-studio',
      httpClient: mock,
    );

    await tester.pumpWidget(await _wrap(api));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
  });
}
