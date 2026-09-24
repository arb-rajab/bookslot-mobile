import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking.dart';

/// Persists the manage tokens for bookings made on this device.
///
/// bookslot's public booking API is deliberately unauthenticated (D-0009)
/// and has no "list my bookings" endpoint — the manage token issued at
/// booking time is the only way to look a booking up again. This store is
/// this app's entire notion of "my bookings"; it is per-device, not
/// per-account, and is lost if the app is uninstalled or the device
/// changes — a real, named limitation, not an oversight (see the repo's
/// backlog).
///
/// The `manage_token` itself is a bearer capability token (whoever holds it
/// can view and cancel the booking, no other auth required), so it's kept
/// out of the plaintext `SharedPreferences` blob entirely and written to
/// `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences on
/// Android) instead, keyed by appointment id. Only non-sensitive metadata
/// (appointment id, service name, start time) lives in `SharedPreferences`.
class LocalBookingsStore {
  LocalBookingsStore(this._prefs, [FlutterSecureStorage? secureStorage])
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _key = 'local_bookings_v1';
  static const _tokenKeyPrefix = 'manage_token_';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  Future<List<LocalBooking>> all() async {
    final raw = _prefs.getStringList(_key) ?? const [];
    final bookings = <LocalBooking>[];
    for (final entry in raw) {
      final json = jsonDecode(entry) as Map<String, dynamic>;
      final appointmentId = json['appointment_id'] as String;
      final manageToken =
          await _secureStorage.read(key: _tokenKey(appointmentId)) ?? '';
      bookings.add(
        LocalBooking(
          appointmentId: appointmentId,
          manageToken: manageToken,
          serviceName: json['service_name'] as String,
          startsAt: DateTime.parse(json['starts_at'] as String),
        ),
      );
    }
    bookings.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return bookings;
  }

  Future<void> add(LocalBooking booking) async {
    final raw = _prefs.getStringList(_key) ?? <String>[];
    raw.add(jsonEncode(_metadataJson(booking)));
    await _prefs.setStringList(_key, raw);
    await _secureStorage.write(
      key: _tokenKey(booking.appointmentId),
      value: booking.manageToken,
    );
  }

  Future<void> remove(String appointmentId) async {
    final raw = _prefs.getStringList(_key) ?? const [];
    final remaining = raw
        .map((entry) => jsonDecode(entry) as Map<String, dynamic>)
        .where((json) => json['appointment_id'] != appointmentId)
        .map(jsonEncode)
        .toList();
    await _prefs.setStringList(_key, remaining);
    await _secureStorage.delete(key: _tokenKey(appointmentId));
  }

  String _tokenKey(String appointmentId) => '$_tokenKeyPrefix$appointmentId';

  Map<String, dynamic> _metadataJson(LocalBooking booking) => {
    'appointment_id': booking.appointmentId,
    'service_name': booking.serviceName,
    'starts_at': booking.startsAt.toIso8601String(),
  };
}
