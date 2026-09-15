import 'dart:convert';

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
class LocalBookingsStore {
  LocalBookingsStore(this._prefs);

  static const _key = 'local_bookings_v1';

  final SharedPreferences _prefs;

  List<LocalBooking> all() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw
        .map(
          (s) => LocalBooking.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  Future<void> add(LocalBooking booking) async {
    final raw = _prefs.getStringList(_key) ?? <String>[];
    raw.add(jsonEncode(booking.toJson()));
    await _prefs.setStringList(_key, raw);
  }

  Future<void> remove(String appointmentId) async {
    final remaining = all()
        .where((b) => b.appointmentId != appointmentId)
        .map((b) => jsonEncode(b.toJson()))
        .toList();
    await _prefs.setStringList(_key, remaining);
  }
}
