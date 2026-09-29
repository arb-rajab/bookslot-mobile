import 'dart:convert';

import 'package:bookslot_mobile/api/bookslot_api_client.dart';
import 'package:bookslot_mobile/app_services.dart';
import 'package:bookslot_mobile/models/booking.dart';
import 'package:bookslot_mobile/models/service.dart';
import 'package:bookslot_mobile/models/slot.dart';
import 'package:bookslot_mobile/screens/deposit_payment_screen.dart';
import 'package:bookslot_mobile/services/local_bookings_store.dart';
import 'package:bookslot_mobile/services/reminder_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory stand-in for the `flutter_secure_storage` platform channel,
/// which isn't available in a plain `flutter_test` environment.
class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _values.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_values);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => _values[key] = value;
}

/// Same pattern as `_FakeReminderScheduler` in
/// `booking_confirmation_screen_test.dart`: the real
/// `FlutterLocalNotificationsPlugin` has no registered platform channel in
/// `flutter_test`. Here `scheduleForAppointment` can also be made to throw,
/// standing in for a plugin/platform failure.
class _FakeReminderScheduler extends ReminderScheduler {
  _FakeReminderScheduler({
    this.notificationsEnabled = true,
    this.throwOnSchedule = false,
  }) : super(FlutterLocalNotificationsPlugin());

  final bool notificationsEnabled;
  final bool throwOnSchedule;
  int scheduleCalls = 0;

  @override
  Future<bool> scheduleForAppointment({
    required String appointmentId,
    required String serviceName,
    required DateTime startsAt,
    Duration leadTime = const Duration(hours: 2),
  }) async {
    scheduleCalls++;
    if (throwOnSchedule) {
      throw PlatformException(code: 'schedule_failed');
    }
    return notificationsEnabled;
  }
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

const _booking = BookingCreationResult(
  appointmentId: 'apt-1',
  status: 'pending_payment',
  depositAmount: 2000,
  depositCurrency: 'usd',
  clientSecret: 'pi_123_secret_456',
  manageToken: 'manage-token-1',
  paymentConfirmationToken: 'confirm-token-1',
);

const _notificationsOffMessage =
    "Notifications are off, so you won't get an on-device "
    'reminder for this appointment. You can turn them on in your phone\'s '
    'notification settings.';

const _stripeChannel = MethodChannel(
  'flutter.stripe/payments',
  JSONMethodCodec(),
);

int _stripeKeyCounter = 0;

/// Stubs Stripe's platform channel so `initPaymentSheet` /
/// `presentPaymentSheet` succeed (an empty map is a completed sheet), or
/// `presentPaymentSheet` reports a Stripe failure when [failPresent] is set.
void _stubStripe(WidgetTester tester, {bool failPresent = false}) {
  // A fresh key per test: `Stripe` caches its settings future in the first
  // test's fake-async zone, and re-setting the *same* key is a no-op, so a
  // later test would await that stale future forever.
  Stripe.publishableKey = 'pk_test_dummy_${_stripeKeyCounter++}';
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _stripeChannel,
    (call) async {
      if (call.method == 'presentPaymentSheet' && failPresent) {
        return {
          'error': {
            'code': 'Canceled',
            'message': 'The payment flow has been canceled',
            'localizedMessage': 'The payment flow has been canceled',
          },
        };
      }
      if (call.method == 'initPaymentSheet' ||
          call.method == 'presentPaymentSheet') {
        return <String, dynamic>{};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _stripeChannel,
      null,
    ),
  );
}

Future<Widget> _wrap({
  required ReminderScheduler reminders,
  required String confirmStatus,
}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
  final prefs = await SharedPreferences.getInstance();

  final api = BookslotApiClient(
    baseUrl: 'https://demo.test/api',
    tenantSlug: 'demo-studio',
    httpClient: MockClient((request) async {
      expect(request.url.path, '/api/bookings/confirm-token-1/confirm-payment');
      return http.Response(jsonEncode({'status': confirmStatus}), 200);
    }),
  );

  return Provider<AppServices>(
    create: (_) => AppServices(
      api: api,
      bookingsStore: LocalBookingsStore(prefs),
      reminders: reminders,
    ),
    child: MaterialApp(
      home: DepositPaymentScreen(
        service: _service,
        slot: _slot,
        booking: _booking,
      ),
    ),
  );
}

void main() {
  const failureMessage = 'Something went wrong confirming your payment.';

  testWidgets(
    'lands on Booked! with the notifications-off message when scheduling the '
    'reminder throws after the payment already succeeded',
    (tester) async {
      _stubStripe(tester);
      final reminders = _FakeReminderScheduler(throwOnSchedule: true);
      await tester.pumpWidget(
        await _wrap(reminders: reminders, confirmStatus: 'confirmed'),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(reminders.scheduleCalls, 1);
      expect(find.text(failureMessage), findsNothing);
      expect(find.text('Booked!'), findsOneWidget);
      expect(find.text(_notificationsOffMessage), findsOneWidget);
    },
  );

  testWidgets('lands on Booked! without the message when scheduling succeeds', (
    tester,
  ) async {
    _stubStripe(tester);
    await tester.pumpWidget(
      await _wrap(
        reminders: _FakeReminderScheduler(),
        confirmStatus: 'confirmed',
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Booked!'), findsOneWidget);
    expect(find.text(_notificationsOffMessage), findsNothing);
  });

  testWidgets('shows the notifications-off message when permission is denied', (
    tester,
  ) async {
    _stubStripe(tester);
    await tester.pumpWidget(
      await _wrap(
        reminders: _FakeReminderScheduler(notificationsEnabled: false),
        confirmStatus: 'confirmed',
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Booked!'), findsOneWidget);
    expect(find.text(_notificationsOffMessage), findsOneWidget);
  });

  testWidgets(
    'a Stripe failure still shows the payment error and never schedules',
    (tester) async {
      _stubStripe(tester, failPresent: true);
      final reminders = _FakeReminderScheduler();
      await tester.pumpWidget(
        await _wrap(reminders: reminders, confirmStatus: 'confirmed'),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Payment was cancelled or declined.'), findsOneWidget);
      expect(find.text('Booked!'), findsNothing);
      expect(reminders.scheduleCalls, 0);
    },
  );

  testWidgets('a non-confirmed server status shows the not-completed error', (
    tester,
  ) async {
    _stubStripe(tester);
    final reminders = _FakeReminderScheduler();
    await tester.pumpWidget(
      await _wrap(reminders: reminders, confirmStatus: 'pending_payment'),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      find.text('Payment did not complete. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Booked!'), findsNothing);
    expect(reminders.scheduleCalls, 0);
  });
}
