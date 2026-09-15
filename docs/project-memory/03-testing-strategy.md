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
- **Integration test** (`integration_test/booking_flow_test.dart`): a real
  widget-tree walk from the services list through slot selection and the
  booking form, stopping at the Stripe handoff — see below for why it
  stops there, and its own docblock for the full reasoning.

## What's NOT tested, and why

- **Stripe's PaymentSheet itself.** It's a native, platform-owned UI
  surface outside the Flutter widget tree; neither `flutter_test` nor
  `integration_test` can drive it. `DepositPaymentScreen`'s logic around
  it (what happens on `StripeException`, what happens when
  `confirm-payment` returns a non-`confirmed` status) is exercised by
  reading the code, not by an automated test — a real gap, tracked in
  `05-backlog.md`.
- **A real device/emulator run of `integration_test/`.** This session's
  environment had no Android emulator, iOS simulator, or connected device
  available (same category of gap bookslot's own Session 16/17/19 hit for
  its frontend, and Session 20 eventually resolved by finding a
  pre-installed Chromium — no Flutter-capable equivalent was available
  here). The integration test is written and analyzed clean, but has never
  actually executed. See `05-backlog.md`.
- **Contract tests against bookslot's real API.** This app's fixtures are
  hand-copied from reading bookslot's controller source in this session,
  not generated from or verified against a live bookslot instance (no
  running bookslot backend was available in this session either). If
  bookslot's public API shape changes, this app's tests would keep passing
  against stale fixtures. Tracked in `05-backlog.md`.

## CI

`.github/workflows/ci.yml` runs `dart format --set-exit-if-changed`,
`flutter analyze`, and `flutter test --coverage` on every push/PR.
`integration_test/` is deliberately excluded from CI (no emulator on a
plain `ubuntu-latest` runner) rather than silently attempted and ignored.
