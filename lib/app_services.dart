import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/bookslot_api_client.dart';
import 'config/env.dart';
import 'services/local_bookings_store.dart';
import 'services/reminder_scheduler.dart';

/// Bundles the app's service-layer singletons so they can be built once in
/// `main()` and handed down via `Provider`. Kept as one plain class rather
/// than several `Provider`s because every screen in this small app needs
/// all three together, and this avoids a `MultiProvider` of one-line
/// wrappers for no real benefit.
class AppServices {
  AppServices({
    required this.api,
    required this.bookingsStore,
    required this.reminders,
  });

  static Future<AppServices> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final reminders = ReminderScheduler(FlutterLocalNotificationsPlugin());
    await reminders.initialize();

    return AppServices(
      api: BookslotApiClient(
        baseUrl: Env.apiBaseUrl,
        tenantSlug: Env.tenantSlug,
      ),
      bookingsStore: LocalBookingsStore(prefs),
      reminders: reminders,
    );
  }

  final BookslotApiClient api;
  final LocalBookingsStore bookingsStore;
  final ReminderScheduler reminders;
}
