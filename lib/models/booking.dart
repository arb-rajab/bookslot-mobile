/// Result of `POST /tenants/{slug}/bookings` (bookslot's `BookingController`).
class BookingCreationResult {
  const BookingCreationResult({
    required this.appointmentId,
    required this.status,
    required this.depositAmount,
    required this.depositCurrency,
    required this.clientSecret,
    required this.manageToken,
    required this.paymentConfirmationToken,
  });

  factory BookingCreationResult.fromJson(Map<String, dynamic> json) {
    final deposit = json['deposit'] as Map<String, dynamic>;
    return BookingCreationResult(
      appointmentId: json['appointment_id'] as String,
      status: json['status'] as String,
      depositAmount: deposit['amount'] as int,
      depositCurrency: deposit['currency'] as String,
      clientSecret: deposit['client_secret'] as String,
      manageToken: json['manage_token'] as String,
      paymentConfirmationToken: json['payment_confirmation_token'] as String,
    );
  }

  final String appointmentId;
  final String status;
  final int depositAmount;
  final String depositCurrency;
  final String clientSecret;
  final String manageToken;
  final String paymentConfirmationToken;
}

/// Result of `GET /bookings/manage/{token}` (bookslot's
/// `ManageBookingController`) — the only public, unauthenticated view of an
/// existing booking's current status.
class BookingStatus {
  const BookingStatus({
    required this.appointmentId,
    required this.status,
    required this.startsAt,
    required this.endsAt,
  });

  factory BookingStatus.fromJson(Map<String, dynamic> json) {
    return BookingStatus(
      appointmentId: json['appointment_id'] as String,
      status: json['status'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
    );
  }

  final String appointmentId;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;

  bool get isUpcoming =>
      startsAt.isAfter(DateTime.now()) && status != 'cancelled';
}

/// A booking this device made, kept locally so "My Bookings" can look it up
/// again via its manage token. bookslot's public API has no
/// list-my-bookings endpoint (it's deliberately unauthenticated, D-0009) —
/// each booking is only reachable again via the signed token issued at
/// creation time, so the app is the only place that can remember which
/// bookings belong to this device.
class LocalBooking {
  const LocalBooking({
    required this.appointmentId,
    required this.manageToken,
    required this.serviceName,
    required this.startsAt,
  });

  factory LocalBooking.fromJson(Map<String, dynamic> json) {
    return LocalBooking(
      appointmentId: json['appointment_id'] as String,
      manageToken: json['manage_token'] as String,
      serviceName: json['service_name'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
    );
  }

  final String appointmentId;
  final String manageToken;
  final String serviceName;
  final DateTime startsAt;

  Map<String, dynamic> toJson() => {
    'appointment_id': appointmentId,
    'manage_token': manageToken,
    'service_name': serviceName,
    'starts_at': startsAt.toIso8601String(),
  };
}
