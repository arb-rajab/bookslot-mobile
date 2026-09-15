import 'dart:convert';

import 'package:bookslot_mobile/api/bookslot_api_client.dart';
import 'package:bookslot_mobile/app_services.dart';
import 'package:bookslot_mobile/main.dart';
import 'package:bookslot_mobile/services/local_bookings_store.dart';
import 'package:bookslot_mobile/services/reminder_scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A real, on-device end-to-end walk of the browse -> pick a slot -> fill
/// customer details -> accept the mandate flow, against a fake HTTP
/// transport shaped exactly like bookslot's real responses (same fixture
/// shapes the unit tests use) — a real Stripe PaymentSheet cannot be
/// driven by `integration_test`'s widget-tree interaction (it renders a
/// native, platform-owned sheet outside the Flutter widget tree), so this
/// test stops at the point the app hands off to Stripe.
///
/// **Environment note:** this repository's CI and the sandbox this app was
/// built in have no Android emulator / iOS simulator / connected device
/// available, so this suite has never actually been executed end-to-end —
/// it is written against the real widget tree and API contracts, but is
/// unverified by a real run. Running it for real (`flutter test
/// integration_test` against a booted emulator, or `flutter drive`) is a
/// tracked backlog item, not something this session could complete.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'customer can browse services, pick a slot, and reach the payment step',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final slotStart = DateTime.now()
          .toUtc()
          .add(const Duration(days: 1))
          .copyWith(
            hour: 10,
            minute: 0,
            second: 0,
            microsecond: 0,
            millisecond: 0,
          );

      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/services')) {
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
        }
        if (request.url.path.endsWith('/availability')) {
          return http.Response(
            jsonEncode({
              'slots': [
                {
                  'staff_id': 'staff-1',
                  'starts_at': slotStart.toIso8601String(),
                  'ends_at': slotStart
                      .add(const Duration(hours: 1))
                      .toIso8601String(),
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/mandate')) {
          return http.Response(
            jsonEncode({
              'template_version': 'v1',
              'text': 'You are booking Small Tattoo Session. A deposit of 50.00 USD is due now.',
              'balance_amount_disclosed': 15000,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/bookings') &&
            request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'appointment_id': 'apt-1',
              'status': 'pending_payment',
              'deposit': {
                'amount': 5000,
                'currency': 'usd',
                'client_secret': 'pi_test_secret',
              },
              'manage_token': 'manage-token',
              'payment_confirmation_token': 'confirm-token',
            }),
            201,
          );
        }
        return http.Response('{}', 200);
      });

      final services = AppServices(
        api: BookslotApiClient(
          baseUrl: 'https://demo.test/api',
          tenantSlug: 'demo-studio',
          httpClient: mock,
        ),
        bookingsStore: LocalBookingsStore(prefs),
        reminders: ReminderScheduler(FlutterLocalNotificationsPlugin()),
      );

      await tester.pumpWidget(BookslotMobileApp(services: services));
      await tester.pumpAndSettle();

      expect(find.text('Small Tattoo Session'), findsOneWidget);

      await tester.tap(find.text('Small Tattoo Session'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('10:00').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('nameField')), 'Alex Rivera');
      await tester.enterText(
        find.byKey(const Key('emailField')),
        'alex@example.test',
      );
      await tester.tap(find.byKey(const Key('mandateCheckbox')));
      await tester.tap(find.text('Continue to payment'));
      await tester.pumpAndSettle();

      expect(find.text('Pay deposit'), findsWidgets);
    },
  );
}
