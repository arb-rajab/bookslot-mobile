import 'package:bookslot_mobile/models/booking.dart';
import 'package:bookslot_mobile/services/local_bookings_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory fake standing in for the platform channel
/// `flutter_secure_storage` normally talks to (Keychain/Keystore), which
/// isn't available in a plain `flutter_test` environment.
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

void main() {
  late FlutterSecureStorage secureStorage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
    secureStorage = const FlutterSecureStorage();
  });

  test(
    'add() then all() round-trips a booking and sorts by start time',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LocalBookingsStore(prefs, secureStorage);

      await store.add(
        LocalBooking(
          appointmentId: 'apt-2',
          manageToken: 't2',
          serviceName: 'Later',
          startsAt: DateTime.utc(2026, 2),
        ),
      );
      await store.add(
        LocalBooking(
          appointmentId: 'apt-1',
          manageToken: 't1',
          serviceName: 'Earlier',
          startsAt: DateTime.utc(2026, 1),
        ),
      );

      final all = await store.all();
      expect(all.map((b) => b.appointmentId), ['apt-1', 'apt-2']);
      expect(all.map((b) => b.manageToken), ['t1', 't2']);
    },
  );

  test('remove() drops only the matching booking', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalBookingsStore(prefs, secureStorage);

    await store.add(
      LocalBooking(
        appointmentId: 'apt-1',
        manageToken: 't1',
        serviceName: 'A',
        startsAt: DateTime.utc(2026, 1),
      ),
    );
    await store.add(
      LocalBooking(
        appointmentId: 'apt-2',
        manageToken: 't2',
        serviceName: 'B',
        startsAt: DateTime.utc(2026, 2),
      ),
    );

    await store.remove('apt-1');

    expect((await store.all()).map((b) => b.appointmentId), ['apt-2']);
  });

  test('all() returns an empty list when nothing has been stored', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalBookingsStore(prefs, secureStorage);

    expect(await store.all(), isEmpty);
  });

  test(
    'the manage token is not readable via the old plaintext SharedPreferences '
    'mechanism — only non-sensitive metadata lives there',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LocalBookingsStore(prefs, secureStorage);

      await store.add(
        LocalBooking(
          appointmentId: 'apt-1',
          manageToken: 'super-secret-capability-token',
          serviceName: 'A',
          startsAt: DateTime.utc(2026, 1),
        ),
      );

      // Simulate the old, plaintext-at-rest read path: inspect raw
      // SharedPreferences contents directly, the way anything with
      // filesystem/backup access to the app's prefs file could.
      final rawPrefsContents = prefs.getStringList('local_bookings_v1') ?? [];
      for (final entry in rawPrefsContents) {
        expect(entry, isNot(contains('super-secret-capability-token')));
      }

      // The token is still readable through the store's own API, which now
      // goes via secure storage.
      final all = await store.all();
      expect(all.single.manageToken, 'super-secret-capability-token');
    },
  );
}
