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
  `reminder_delivery_test.dart` also uses no fakes. It schedules a
  reminder through the real `ReminderScheduler`, due ~10 s out, and polls
  `getActiveNotifications()` until it appears (backlog #9, D-10). It prints
  permission, exact-alarm and pending-request diagnostics, so a failure
  says which layer broke.
- **Reboot check** (`.github/scripts/reboot-reminder-check.sh`), run on
  the same emulator after the integration tests, because it reboots it.
  It isn't a `flutter test`: a Dart test can't span a reboot, and `flutter
  test` force-stops the app when it finishes, which cancels its alarms.
  CI builds `integration_test/reboot_probe_main.dart` as a separate debug
  APK. The script launches it once, and it schedules a reminder due in
  5 minutes through the real `AppServices`/`ReminderScheduler`. The script
  then confirms the app's alarm is in `dumpsys alarm`, runs `adb reboot`,
  and, without reopening the app, polls `dumpsys alarm` and `dumpsys
  notification` until the reminder is shown (backlog #10, D-11). It prints
  when the alarm came back and how late the reminder was. A negative
  control (boot receiver removed) made it fail.
- **Permission prompts in emulator tests.** `integration_test` can't tap
  platform-owned UI, so `android-native.yml` runs the suite through
  `.github/scripts/run-integration-tests.sh`. That script runs
  `allow-permission-dialogs.sh` in the background, which taps "Allow"
  whenever the system permission dialog has focus. It never `pm grant`s
  anything, so a permission the app forgets to *request* still fails the
  test. Only "Allow" is ever exercised: the decline path isn't tested.

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
- **Reminder edge cases on Android.** The emulator covers two cases, both
  on API 34 with the device awake: a reminder due in seconds, and one that
  has to survive a reboot. Not covered: Doze/idle deferral of the inexact
  alarm, a real multi-hour lead (backlog #11), a device that stays off
  past the reminder's time, a force-stopped app, the user declining the
  notification permission, other API levels, and physical/OEM devices.
- **Native Android anywhere but GitHub Actions.** The Claude cloud
  sandbox still can't run Gradle or an emulator (`dl.google.com` denied,
  no KVM; see `CLAUDE.md`). Native evidence comes only from
  `android-native.yml`, so a session that changes `android/**` has to push
  and read that workflow's results; it can't check locally.

## CI

- `.github/workflows/ci.yml` runs `dart format --set-exit-if-changed`,
  `flutter analyze` and `flutter test --coverage` on every push/PR.
- `.github/workflows/android-native.yml` runs `flutter build apk --debug`,
  builds the reboot probe APK, then runs `flutter test integration_test`
  and the reboot check on an API 34 x86_64 emulator. It runs
  on PRs touching `pubspec*`, `android/**`, `integration_test/**`,
  `lib/main.dart`, `lib/services/reminder_scheduler.dart`, `.github/scripts/**`
  or the workflow itself, and on `workflow_dispatch`.
- Its matrix rows are `flutter_stripe` versions. `pinned` (as committed)
  gates the PR, and on PRs it's the only row. Candidate rows, added via
  dispatch, may fail without failing their job. **Read a candidate's job summary, not its check
  colour.**
- To try other versions, dispatch it with `stripe_versions`, e.g.
  `["pinned", "14.2.0"]`.
