# Testing Strategy

## Layers

- **Unit tests** (`test/unit/`): pure model logic
  (`Service.estimatedDepositAmount()`, cross-checked against bookslot's own
  `MandateRenderer` formula) and `LocalBookingsStore` (add/remove/sort
  against a real `SharedPreferences` mock). `BookslotApiClient` is tested
  against `package:http/testing.dart`'s `MockClient` with fixtures shaped
  exactly like bookslot's real controller responses (field names and
  status codes copied from reading bookslot's own controller source, not
  guessed) — including the `SLOT_ALREADY_BOOKED` 409 mapping.
- **Widget tests** (`test/widget/`): `ServicesListScreen`'s success/error
  states, and `BookingFormScreen`'s validation (mandate checkbox required,
  invalid email rejected) with an assertion that the API is never called
  when client-side validation fails.
- **Integration tests** (`integration_test/`), run on a KVM-accelerated
  Android emulator by `.github/workflows/android-native.yml`:
  `booking_flow_test.dart` walks the widget tree from the services list
  through slot selection and the booking form, stopping at the Stripe
  handoff (see below for why it stops there). `android_startup_test.dart`
  uses no fakes: it runs the real `main()` and `Stripe.instance
  .applySettings()` through the real native plugins, so it catches
  Android host misconfiguration that Dart-only tests can't see.

## What's NOT tested, and why

- **Stripe's PaymentSheet itself.** It's a native, platform-owned UI
  surface outside the Flutter widget tree; neither `flutter_test` nor
  `integration_test` can drive it. `DepositPaymentScreen`'s logic around
  it (what happens on `StripeException`, what happens when
  `confirm-payment` returns a non-`confirmed` status) is exercised by
  reading the code, not by an automated test — a real gap, tracked in
  `05-backlog.md`.
- **iOS.** Nothing iOS-native has ever been built or run (no macOS
  runner in CI, no simulator in the Claude sandbox). The Android emulator
  job says nothing about iOS host configuration.
- **Contract tests against bookslot's real API.** This app's fixtures are
  hand-copied from reading bookslot's controller source in this session,
  not generated from or verified against a live bookslot instance (no
  running bookslot backend was available in this session either). If
  bookslot's public API shape changes, this app's tests would keep passing
  against stale fixtures. Tracked in `05-backlog.md`.
- **Native Android anywhere but GitHub Actions.** The Claude cloud
  sandbox still can't run Gradle or an emulator (`dl.google.com` denied,
  no KVM; see `CLAUDE.md`). Native evidence comes only from
  `android-native.yml`, so a session that changes `android/**` has to push
  and read that workflow's results; it can't check locally.

## CI

- `.github/workflows/ci.yml` runs `dart format --set-exit-if-changed`,
  `flutter analyze` and `flutter test --coverage` on every push/PR.
- `.github/workflows/android-native.yml` runs `flutter build apk --debug`,
  then `flutter test integration_test` on an API 34 x86_64 emulator. It runs
  on PRs touching `pubspec*`, `android/**`, `integration_test/**`,
  `lib/main.dart` or the workflow itself, and on `workflow_dispatch`.
- Its matrix rows are `flutter_stripe` versions. `pinned` (as committed)
  gates the PR, and on PRs it's the only row. Candidate rows, added via
  dispatch, may fail without failing their job. **Read a candidate's job summary, not its check
  colour.**
- To try other versions, dispatch it with `stripe_versions`, e.g.
  `["pinned", "14.2.0"]`.
