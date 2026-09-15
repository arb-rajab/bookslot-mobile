/// Runtime configuration for the public demo build.
///
/// This app ships pointed at bookslot's seeded `demo-studio` tenant
/// (see bookslot's `database/seeders/DatabaseSeeder.php`) — never at a real
/// tenant's data. Override at build time for local development against a
/// different backend, e.g.:
///   flutter run --dart-define=BOOKSLOT_API_BASE_URL=http://10.0.2.2:8000/api
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'BOOKSLOT_API_BASE_URL',
    defaultValue: 'https://demo.bookslot.example/api',
  );

  static const String tenantSlug = String.fromEnvironment(
    'BOOKSLOT_TENANT_SLUG',
    defaultValue: 'demo-studio',
  );

  /// Stripe test-mode publishable key only (pk_test_...). This app never
  /// holds a secret key or live credentials — see bookslot's D-0036.
  static const String stripePublishableKey = String.fromEnvironment(
    'BOOKSLOT_STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_placeholder',
  );
}
