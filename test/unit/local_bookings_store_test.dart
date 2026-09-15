import 'package:bookslot_mobile/models/booking.dart';
import 'package:bookslot_mobile/services/local_bookings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'add() then all() round-trips a booking and sorts by start time',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LocalBookingsStore(prefs);

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

      final all = store.all();
      expect(all.map((b) => b.appointmentId), ['apt-1', 'apt-2']);
    },
  );

  test('remove() drops only the matching booking', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalBookingsStore(prefs);

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

    expect(store.all().map((b) => b.appointmentId), ['apt-2']);
  });

  test('all() returns an empty list when nothing has been stored', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalBookingsStore(prefs);

    expect(store.all(), isEmpty);
  });
}
