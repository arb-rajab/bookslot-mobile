# bookslot-mobile

A Flutter customer app for booking appointments and paying deposits
against [`bookslot`](https://github.com/arb-rajab/bookslot)'s real,
production-shaped public booking API — pointed at a seeded demo tenant, not
real business data. This is the public, portfolio-demo half of a
private/public repo pair; see
[`docs/project-memory/00-project-brief.md`](docs/project-memory/00-project-brief.md)
for the full story.

## What it does

- Browse a demo studio's services and real, derived availability.
- Book an appointment and pay a deposit via Stripe (**test mode only**).
- View your bookings and their live status on this device.
- Get a local reminder notification ahead of your appointment.

See [`docs/project-memory/01-scope-and-non-goals.md`](docs/project-memory/01-scope-and-non-goals.md)
for what it deliberately does not do (no admin features, no real push, no
live Stripe credentials, no self-service cancellation yet — bookslot has
no customer-facing cancel endpoint).

## Running it

```sh
flutter pub get
flutter run \
  --dart-define=BOOKSLOT_API_BASE_URL=https://your-bookslot-instance/api \
  --dart-define=BOOKSLOT_TENANT_SLUG=demo-studio \
  --dart-define=BOOKSLOT_STRIPE_PUBLISHABLE_KEY=pk_test_...
```

All three `--dart-define` values default to the public demo configuration
(see `lib/config/env.dart`) if omitted.

## Testing

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --coverage
```

`integration_test/booking_flow_test.dart` needs a booted emulator/simulator
or connected device (`flutter test integration_test`) — it is not run in
CI. See [`docs/project-memory/03-testing-strategy.md`](docs/project-memory/03-testing-strategy.md).

## Documentation

Full project memory — architecture, scope, decisions, testing strategy,
backlog, session handoffs — lives in
[`docs/project-memory/`](docs/project-memory/).

## License

MIT — see [`LICENSE`](LICENSE).
