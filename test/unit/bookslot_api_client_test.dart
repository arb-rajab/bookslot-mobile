import 'dart:convert';

import 'package:bookslot_mobile/api/bookslot_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('BookslotApiClient', () {
    test('fetchServices parses the real bookslot response shape', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/tenants/demo-studio/services');
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

      final client = BookslotApiClient(
        baseUrl: 'https://demo.test/api',
        tenantSlug: 'demo-studio',
        httpClient: mock,
      );
      final services = await client.fetchServices();

      expect(services, hasLength(1));
      expect(services.single.name, 'Small Tattoo Session');
    });

    test(
      'createBooking maps SLOT_ALREADY_BOOKED (409) to a typed exception',
      () async {
        final mock = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'SLOT_ALREADY_BOOKED'}),
            409,
          );
        });

        final client = BookslotApiClient(
          baseUrl: 'https://demo.test/api',
          tenantSlug: 'demo-studio',
          httpClient: mock,
        );

        await expectLater(
          client.createBooking(
            serviceId: 'svc-1',
            staffId: 'staff-1',
            startsAt: DateTime.utc(2026, 1, 1, 10),
            customerName: 'Alex',
            customerEmail: 'alex@example.test',
            mandateTemplateVersion: 'v1',
          ),
          throwsA(
            isA<BookslotApiException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.errorCode, 'errorCode', 'SLOT_ALREADY_BOOKED'),
          ),
        );
      },
    );

    test(
      'createBooking sends the exact request shape BookingController validates',
      () async {
        late Map<String, dynamic> sentBody;
        final mock = MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'appointment_id': 'apt-1',
              'status': 'pending_payment',
              'deposit': {
                'amount': 5000,
                'currency': 'usd',
                'client_secret': 'pi_secret',
              },
              'manage_token': 'manage-token',
              'payment_confirmation_token': 'confirm-token',
            }),
            201,
          );
        });

        final client = BookslotApiClient(
          baseUrl: 'https://demo.test/api',
          tenantSlug: 'demo-studio',
          httpClient: mock,
        );
        final result = await client.createBooking(
          serviceId: 'svc-1',
          staffId: 'staff-1',
          startsAt: DateTime.utc(2026, 1, 1, 10),
          customerName: 'Alex Rivera',
          customerEmail: 'alex@example.test',
          mandateTemplateVersion: 'v1',
        );

        expect(sentBody['service_id'], 'svc-1');
        expect(sentBody['staff_id'], 'staff-1');
        expect(sentBody['mandate_accepted'], true);
        expect(sentBody['mandate_template_version'], 'v1');
        expect(sentBody['customer'], {
          'name': 'Alex Rivera',
          'email': 'alex@example.test',
          'phone': null,
        });
        expect(result.appointmentId, 'apt-1');
        expect(result.clientSecret, 'pi_secret');
      },
    );

    test('fetchBookingStatus hits the token-based manage endpoint, not a slug route', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/bookings/manage/some-token');
        return http.Response(
          jsonEncode({
            'appointment_id': 'apt-1',
            'status': 'confirmed',
            'starts_at': '2026-01-01T10:00:00Z',
            'ends_at': '2026-01-01T11:00:00Z',
          }),
          200,
        );
      });

      final client = BookslotApiClient(
        baseUrl: 'https://demo.test/api',
        tenantSlug: 'demo-studio',
        httpClient: mock,
      );
      final status = await client.fetchBookingStatus('some-token');

      expect(status.status, 'confirmed');
      expect(status.startsAt, DateTime.utc(2026, 1, 1, 10));
    });
  });
}
