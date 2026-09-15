import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/booking.dart';
import '../models/mandate.dart';
import '../models/service.dart';
import '../models/slot.dart';

/// Thrown for any non-2xx response from bookslot's API. Carries the
/// machine-readable `error` code bookslot's controllers return (e.g.
/// `SLOT_ALREADY_BOOKED`, `INVALID_OR_EXPIRED_TOKEN`) so screens can react
/// to specific, known failure modes instead of showing a generic message.
class BookslotApiException implements Exception {
  BookslotApiException(this.statusCode, this.errorCode, [this.message]);

  final int statusCode;
  final String? errorCode;
  final String? message;

  @override
  String toString() =>
      'BookslotApiException($statusCode, $errorCode, $message)';
}

/// Thin wrapper over bookslot's public, unauthenticated customer-facing API
/// (`routes/api.php`'s `tenants/{slug}` group plus the token-based
/// `bookings/*` routes). Deliberately does not touch any owner/staff/admin
/// endpoint — those require authentication this app never holds, per this
/// app's customer-only scope.
class BookslotApiClient {
  BookslotApiClient({
    required this.baseUrl,
    required this.tenantSlug,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String tenantSlug;
  final http.Client _http;

  Uri _tenantUri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/tenants/$tenantSlug/$path')
          .replace(queryParameters: query);

  Uri _uri(String path) => Uri.parse('$baseUrl/$path');

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw BookslotApiException(
      response.statusCode,
      body['error'] as String?,
      body['message'] as String?,
    );
  }

  Future<List<Service>> fetchServices() async {
    final response = await _http.get(_tenantUri('services'));
    final body = _decodeOrThrow(response);
    final services = body['services'] as List<dynamic>;
    return services
        .map((s) => Service.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<Mandate> fetchMandate(String serviceId) async {
    final response = await _http.get(_tenantUri('services/$serviceId/mandate'));
    return Mandate.fromJson(_decodeOrThrow(response));
  }

  /// [from]/[to] are `YYYY-MM-DD` calendar dates in the tenant's own
  /// timezone, matching bookslot's `AvailabilityController` contract.
  ///
  /// The conditional `staff_id` map entry below suppresses
  /// `use_null_aware_elements`: that lint's suggested `?'staff_id':
  /// staffId` rewrite doesn't apply to a conditionally-*included* map
  /// entry (only to a possibly-null *value*), and produces a real type
  /// error (`String?` not assignable to `Map<String, String>`'s value
  /// type) if tried — verified by trying it.
  Future<List<Slot>> fetchAvailability({
    required String serviceId,
    required DateTime from,
    required DateTime to,
    String? staffId,
  }) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final response = await _http.get(
      _tenantUri('availability', {
        'service_id': serviceId,
        'from': fmt(from),
        'to': fmt(to),
        // ignore: use_null_aware_elements
        if (staffId != null) 'staff_id': staffId,
      }),
    );
    final body = _decodeOrThrow(response);
    final slots = body['slots'] as List<dynamic>;
    return slots.map((s) => Slot.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<BookingCreationResult> createBooking({
    required String serviceId,
    required String staffId,
    required DateTime startsAt,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    required String mandateTemplateVersion,
  }) async {
    final response = await _http.post(
      _tenantUri('bookings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': serviceId,
        'staff_id': staffId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'customer': {
          'name': customerName,
          'email': customerEmail,
          'phone': customerPhone,
        },
        'mandate_accepted': true,
        'mandate_template_version': mandateTemplateVersion,
      }),
    );
    return BookingCreationResult.fromJson(_decodeOrThrow(response));
  }

  /// Confirms the deposit PaymentIntent server-side after the Stripe
  /// PaymentSheet has completed client-side confirmation. Safe to call more
  /// than once (bookslot re-checks Stripe each call while still
  /// `pending_payment`).
  Future<Map<String, dynamic>> confirmPayment(
    String paymentConfirmationToken,
  ) async {
    final response = await _http.post(
      _uri('bookings/$paymentConfirmationToken/confirm-payment'),
    );
    return _decodeOrThrow(response);
  }

  Future<BookingStatus> fetchBookingStatus(String manageToken) async {
    final response = await _http.get(_uri('bookings/manage/$manageToken'));
    return BookingStatus.fromJson(_decodeOrThrow(response));
  }
}
