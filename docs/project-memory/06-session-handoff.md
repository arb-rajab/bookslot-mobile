# Session Handoff

## Session 1 — 2026-09-15 — initial build

**Objective:** stand up this repository from nothing: read bookslot's real
current API surface, identify/confirm a demo tenant, scaffold a real
Flutter app implementing browse → book → deposit → view/cancel, set up
CI, write real tests, and get it merged.

**What was verified before building anything:** bookslot's
`docs/project-memory/12-session-handoff.md` Session 20 amendment (the most
recent at the time of this session), `routes/api.php`, and every public
controller under `app/Http/Controllers/Api/*.php` (`BookingController`,
`ManageBookingController`, `PaymentConfirmationController`,
`AvailabilityController`, `ServiceController`, `MandateController`) plus
`app/Mandates/MandateRenderer.php` for exact response field names, and
`database/seeders/DatabaseSeeder.php` for the demo tenant. This session had
read-only access to the `bookslot` repository — no changes were made there.

**Demo tenant:** `demo-studio` ("Demo Tattoo Studio"), already seeded by
bookslot's own `DatabaseSeeder` (added Session 17). Not created new this
session — identified and reused. See `04-decisions.md` D-02.

**What was built, end to end and real:**
- Full browse → slot pick → customer details + mandate acceptance → Stripe
  PaymentSheet deposit → server-side confirmation → local "my bookings"
  record → local reminder notification flow, against bookslot's real
  request/response shapes.
- `MyBookingsScreen` showing live status per booking (refetched from
  bookslot on each visit) with an honest, non-functional-by-design Cancel
  action (see `01-scope-and-non-goals.md` and `04-decisions.md` D-06 for
  why: bookslot has no customer-facing cancel endpoint).
- CI (`dart format`, `flutter analyze`, `flutter test --coverage`) —
  passing clean, zero analyzer warnings/errors (one info-level style
  suggestion left as-is; see the environment notes below for why).
- Unit tests (models, API client against realistic fixtures, local
  storage), widget tests (services list, booking form validation), one
  integration test (written, never executed — see `05-backlog.md` #1).

**Environment notes for whoever picks this up next:**
- No Flutter SDK was preinstalled in this session's container — it was
  installed fresh via `git clone --depth 1 -b stable
  https://github.com/flutter/flutter.git` into `/opt/flutter`. If a future
  session's container also lacks it, the same approach works; don't
  assume `flutter`/`dart` are on `PATH` without checking first.
- No Android emulator, iOS simulator, or connected device was available —
  `integration_test/` could not actually be executed, only written and
  statically analyzed. See `05-backlog.md` #1.
- `flutter analyze` reports exactly one info-level lint
  (`use_null_aware_elements` on a conditional map entry in
  `bookslot_api_client.dart`) that was investigated and deliberately left:
  the suggested `?key: value` null-aware rewrite doesn't actually apply to
  a conditionally-*included* map entry (only to a possibly-null *value*),
  and attempting it produces a real type error. Don't "fix" this again
  without re-deriving that same finding.

**PR/CI status, Dependabot:** see the top-level session summary handed
back to the portfolio coordinator for current numbers — not duplicated
here to avoid this file going stale the moment CI re-runs.

**Next recommended session:** `05-backlog.md` #1 (run the integration test
for real) and #2 (a real customer cancel endpoint, which needs a
bookslot-side session with push access to that repo, not this one).

## Session 2 — 2026-09-15 — wire self-service cancellation to bookslot's real endpoint

**Objective:** bookslot shipped D-0052 (`POST
/bookings/manage/{token}/cancel`, `ManageBookingController::cancel()`) —
wire this app's previously-stubbed `MyBookingsScreen` Cancel action to it.

**What was verified before building anything:** this session had `read`
access to `arb-rajab/bookslot` (added via `add_repo`, not assumed) and
read `routes/api.php` and `ManageBookingController.php` directly rather
than trusting this task prompt's description of the endpoint. Confirmed:
route is `POST bookings/manage/{token}/cancel` under
`resolve.tenant.token:manage_booking` (the same middleware as the
existing `show()` lookup — no new token class); success response is the
same shape as the existing `GET .../manage/{token}` status response
(`appointment_id`, `status`, `starts_at`, `ends_at`); a terminal-status
booking (already `cancelled`/`completed`/`no_show`) returns 409 with
`{"error": "INVALID_STATUS_TRANSITION"}`; an invalid/expired token returns
404 with `{"error": "INVALID_OR_EXPIRED_TOKEN"}` (same as `show()`).

**What was built:**
- `BookslotApiClient.cancelBooking()` — `POST` to the token-based cancel
  route, parses the same `BookingStatus` shape `fetchBookingStatus` uses.
- `MyBookingsScreen`: real confirm-dialog → cancel → live status update
  flow, replacing the old "not available yet" dialog. A 409 is shown as a
  clear "already cancelled" message, never retried or treated as success.
  On success, `ReminderScheduler.cancelForAppointment` is called so a
  cancelled booking's local reminder notification doesn't still fire.
- Unit tests for `cancelBooking` (success + 409), a new widget test suite
  (`test/widget/my_bookings_screen_test.dart`) covering both the success
  and 409 paths, and a second `integration_test/booking_flow_test.dart`
  scenario driving the same flow through the real widget tree (pre-seeded
  local booking, since Stripe can't be driven by `integration_test` — see
  that file's existing docblock).
- `flutter analyze`: "No issues found!" `flutter test --coverage`: all 19
  tests passing.

**Not genuinely verified this session (same environment constraint as
Session 1):** no Android emulator / iOS simulator / device was available,
so `integration_test/` (including the new cancel scenario) is written and
statically clean but has never actually been executed. Also not verified:
real on-device behavior of `flutter_local_notifications`'
`FlutterLocalNotificationsPlugin.cancel()` actually suppressing an
already-scheduled OS-level notification — this session confirmed the call
is made (widget test asserts `ReminderScheduler.cancelForAppointment` is
invoked with the right id via a fake scheduler, since the real plugin's
platform channel isn't available in a plain `flutter_test` environment —
see the new CLAUDE.md note), not that the OS actually drops the alarm.
Dependabot alerts: this session's toolset had no dependabot-alerts-listing
tool available (searched, found none) — **not verified**, not reported as
clean.

**PR/CI status:** see the top-level session summary handed back to the
coordinator for current numbers.

**Next recommended session:** `05-backlog.md` #1 (run integration_test for
real — now doubly valuable since it also covers cancellation) and #3
(contract verification against a live bookslot instance, which would also
catch drift on this endpoint).

## Session 3 — 2026-09-26 — flutter_stripe 11→14 upgrade, reached 13

**Objective:** pick up a prior session's deferred `flutter_stripe` 11→14
upgrade (real risk had been flagged at each major boundary: Freezed v3 at
v12, `SetupPaymentSheetParameters`/customer-sheet deprecations at v12.2,
`confirm()`'s return shape at v13, AGP 9 at v14) with a full budget
dedicated to it.

**What was verified before building anything:** this session did not trust
the prior session's risk summary as still accurate — it re-read
`flutter_stripe`'s actual `CHANGELOG.md` from its GitHub repo
(`flutter-stripe/flutter_stripe`, `packages/stripe/CHANGELOG.md`) end to
end across all four majors, and separately grepped this app's own
`lib/screens/deposit_payment_screen.dart` for exactly which Stripe SDK
calls it makes. Also re-added read access to `arb-rajab/bookslot`
(`add_repo`, since a fresh container starts with none of that state) and
read `PaymentConfirmationController.php`/`BookingController.php` directly
to confirm the `client_secret`/`payment_confirmation_token`/`status`
contract this app depends on is unchanged and is entirely server-side —
not something a client SDK version bump could affect.

**What was found:** three of the prior session's four flagged risks did
not hold up against the real changelog and this app's actual usage (see
`04-decisions.md` D-09 for the full breakdown — the short version: this
app doesn't use `CustomerSheet`, doesn't call `collectBankAccountForPayment`/
`verifyPaymentIntentWithMicrodeposits`, and doesn't call a Stripe SDK
`confirm()` method at all). Only the Freezed v3 requirement (v12) and the
AGP 9 requirement (v14) were confirmed accurate — and Freezed v3 turned
out to be irrelevant to this app's own build (no own freezed codegen).

**What was built:** `flutter_stripe` bumped 11.3.0 → 12.6.0 → 13.1.0,
incrementally, with `flutter pub get` / `dart format --set-exit-if-changed`
/ `flutter analyze` / `flutter test --coverage` (all 20 tests) re-run and
confirmed clean at every step. Zero application code changes were needed
at any step — `pubspec.yaml`/`pubspec.lock` only.

**Where it stopped, and why:** at 13.1.0, one boundary short of the
latest (14.1.0). 14.1.0 itself also passed the full clean-analyze/clean-test
check with zero code changes, and this project's Android Gradle config was
*already* on AGP 9.1.0 before this session touched anything (a Flutter
3.47.5 template default, unrelated to `flutter_stripe`). The stopping
reason is that this session attempted to actually provision an Android SDK
(`commandlinetools` from `dl.google.com`) to run a real `flutter build apk
--debug` and prove the AGP-9 pairing compiles — not just that Dart
analysis is clean — and hit a confirmed, structural block: this sandbox's
egress proxy denies `dl.google.com` (a genuine 403/organization-policy
response, not a flaky network error — see `/root/.ccr/README.md`'s own
documented failure class for this). That denial also blocks Gradle's own
resolution of the Android Gradle Plugin and AndroidX artifacts from
Google's Maven repo, so there was no way to route around it within this
container. Per this task's own instruction to stop at the last version
before an unverifiable native-build-tooling boundary rather than force it
through, `pubspec.yaml` was reverted from 14.1.0 back to 13.1.0. See
`04-decisions.md` D-09 and `05-backlog.md` #8.

**Also checked, per this task's explicit requirements:**
- Test-mode-only Stripe constraint (bookslot's own D-0036,
  `01-scope-and-non-goals.md`): untouched. `lib/config/env.dart` still
  defaults `stripePublishableKey` to `pk_test_placeholder` and its doc
  comment still states the constraint; nothing in this session's diff
  touches that file.
- Interaction with self-service cancellation (D-0052/D-08, Session 2):
  `ReminderScheduler.cancelForAppointment` and the cancel flow don't touch
  Stripe at all (bookslot's cancel endpoint doesn't call Stripe either, per
  `ManageBookingController::cancel()`), so there's no interaction to check
  beyond confirming `test/widget/my_bookings_screen_test.dart` (the test
  that exercises this path) still passes — it does, at every step.

**Not genuinely verified this session, same standing gap as Sessions 1/2,
now confirmed as a hard environment limitation rather than assumed:** a
real end-to-end run of the deposit PaymentSheet flow against a live
backend. This needs three things this sandbox structurally lacks: (1) a
booted Android emulator/iOS simulator/device — no KVM (`/dev/kvm` absent,
no CPU virtualization exposed) and no Android SDK reachable at all, so not
even a software-rendered emulator is feasible here; (2) a live bookslot
instance — `Env.apiBaseUrl`'s default,
`https://demo.bookslot.example/api`, is an RFC 2606 reserved
non-resolving domain (confirmed: proxy returns a CONNECT failure, not a
real host), meaning this app has never had a real deployed backend to hit,
in any session; (3) live Stripe test-mode API credentials, which don't
exist in this repository or its `.env` conventions (a `pk_test_...`
publishable key is safe to ship, but was never provided as a real,
working one). This is the same category of gap `03-testing-strategy.md`
already documents for `integration_test/` and PaymentSheet failure-path
coverage — this session's contribution is confirming *why*, concretely,
rather than leaving it as "no device was available."

**PR/CI status:** see the top-level session summary handed back to the
coordinator for current numbers.

**Next recommended session:** `05-backlog.md` #8 (finish 13→14 once a
native Android build is actually verifiable) — a small, mechanical step at
that point, not a re-investigation. `05-backlog.md` #1 and #3 remain the
two gaps most worth closing before any of this app's "real Stripe" or
"real device" language should be taken at face value.

## 2026-09-26 (later session) — flutter_stripe v14/AGP-9 blocker re-check: still blocked, no code change

**Objective:** before re-attempting `05-backlog.md` #8 (13.1.0 → 14.1.0),
check whether Session 3's blocker still holds. The task said: proceed with
the upgrade only if the blocker is gone, and never bump the pin without a
real native build *plus* real-device/credible-emulator confirmation.

**Checkout:** `git fetch origin main`; the working branch was at
`origin/main` = `2c144a8` (merge of PR #4), the repo's default branch.

**Network, checked with `curl` through this container's egress proxy:**

| Endpoint | Result |
|---|---|
| `dl.google.com` (Android SDK `repository2-3.xml`; Google Maven `dl/android/maven2/.../gradle/9.1.0/gradle-9.1.0.pom` and `maven-metadata.xml`) | **Blocked**: proxy answers `403` to CONNECT (also listed under `recentRelayFailures` in `$HTTPS_PROXY/__agentproxy/status`) |
| `maven.google.com` (AGP 9.1.0 pom, AGP metadata, an AndroidX pom) | Reachable, but only as a **`301` redirect to `dl.google.com`**, so it's blocked in practice. Gradle's `google()` repo resolves from `dl.google.com` anyway. |
| `dl-ssl.google.com`, `redirector.gvt1.com/edgedl/android/...` (other SDK download hosts) | **Blocked** (CONNECT failure) |
| `services.gradle.org`, `plugins.gradle.org` | `200`, reachable |
| `storage.googleapis.com` (Flutter infra), `pub.dev` | `200`, reachable |
| `repo.maven.apache.org` | `429` (rate-limited, not denied) |

Net effect: the Gradle wrapper and Gradle plugin portal work, but you still
can't get the Android SDK (platforms, build-tools) or AGP/AndroidX
artifacts. So `flutter build apk` can't run here at any `flutter_stripe`
version. That's the same structural block Session 3 recorded.

**Device/emulator:** none. `/dev/kvm` is absent and `/proc/cpuinfo`
exposes no `vmx`/`svm` flags, so no hardware-accelerated emulator can run.
No `adb`, `emulator`, or `sdkmanager` on `PATH`. `ANDROID_HOME` and
`ANDROID_SDK_ROOT` are unset. There's no `/dev/bus/usb`, so no USB device
can be attached. An emulator image would come from `dl.google.com`
anyway. The container has 4 CPUs, 15 GB RAM, JDK 21 and Gradle 8.14.3
(under `/opt`). None of those is the limiting factor.

**Outcome:** stopped at the check, per the task's step 2. `pubspec.yaml` is
still `flutter_stripe: ^13.1.0`. Nothing was bumped, built or run. No new
verification of the v14/AGP-9 pairing exists. Everything in D-09 and
backlog #8 still stands exactly as written.

**What would actually unblock it** (for whoever sets up the next attempt):
either (a) this cloud environment's network access is widened to allow
`dl.google.com` (environment settings → Network access). That enables
`flutter build apk --debug`, but there's still no KVM, so device
confirmation would still be missing. Or (b) run the verification off this
sandbox. GitHub-hosted `ubuntu-latest` runners are documented to ship an
Android SDK, and to support hardware-accelerated Android emulators, so a
CI job (e.g. `flutter build apk --debug` plus an emulator-backed
`integration_test` run) could provide both the native build and the
emulator evidence. That's unverified from here: worth confirming against
GitHub's current runner-image docs before relying on it. Neither path
covers backlog #1/#3 (a live bookslot backend and real Stripe test-mode
keys). A true end-to-end PaymentSheet run needs those too.

### Same session, continued: native evidence via GitHub Actions

The user asked for a GitHub Actions workflow to get native evidence from
GitHub's runners instead: an Android SDK, Google Maven access and KVM
are all available there. What was added and found, in commit order:

1. **`1ace642`** added `.github/workflows/android-native.yml` (see
   `03-testing-strategy.md` § CI) and
   `integration_test/android_startup_test.dart`. The test runs the real
   `main()` and `Stripe.instance.applySettings()` with no fakes. App config
   was deliberately left unchanged so CI would show what actually fails.
   **Result:** both matrix rows failed the first-ever native build at
   `:app:checkDebugAarMetadata`: `flutter_local_notifications` requires core
   library desugaring.
2. **`79725db`** enabled desugaring. **Result:** the native build passed
   on both rows. The APK installed on the emulator and
   `booking_flow_test.dart` passed 2/2, its first real execution ever. Both
   `android_startup_test` cases failed with `PlatformException(flutter_stripe
   initialization failed … MainActivity is not a subclass
   FlutterFragmentActivity)`. The second was thrown from `main.dart:15`,
   so **the real app has never been able to start on Android**, at the
   13.1.0 pin, independent of v14. The cause, from `stripe_android`'s
   source: `StripeAndroidPlugin.onAttachedToActivity` records an
   initialization error for any non-`FlutterFragmentActivity` host, and
   `onMethodCall` then rejects every call, including `initialise`.
3. **`b24dacc`** switched `MainActivity` to `FlutterFragmentActivity` and
   moved the launch/normal themes to AppCompat/MaterialComponents parents,
   mirroring flutter_stripe's own example app. **Result:** both rows were
   green. Native build passed, and all 4 emulator integration tests passed
   at 13.1.0 and at 14.1.0.

**Verified (on GitHub's `ubuntu-latest` + API 34 x86_64 emulator, not in
this sandbox):**
- 14.1.0 compiles against this project's AGP 9.1.0 / Kotlin 2.4.0 /
  `builtInKotlin=false` setup. The 13.1.0 build warns that stripe_android
  applies KGP, which future Flutter versions will reject; 14.1.0 doesn't
  apply KGP on AGP 9.
- Stripe's native SDK initialises and the real `main()` reaches `runApp`
  at both versions.

**Not verified:** a real PaymentSheet flow (`initPaymentSheet` /
`presentPaymentSheet` against a real PaymentIntent, which needs a live
bookslot backend and real Stripe test keys: backlog #3/#4); iOS; release
builds (R8/ProGuard rules from flutter_stripe's README step 7 aren't set
up, and don't matter until minify is on); and backlog #9, scheduled
reminders, which reading suggests are broken on Android.

**Pin:** bumped to `^14.1.0` after the maintainer approved it on this
evidence. Only the four Stripe packages changed in `pubspec.lock`, with no
code changes. `android-native.yml`'s default candidate row was dropped,
since 14.1.0 is now `pinned`. Before the bump, 13.1.0 passed the same
native build and 4/4 emulator tests, so a revert target is known-good.

## 2026-09-26 (later session) — PR #5 proof-standard check; backlog #9 reproduced and fixed

**Checkout:** `git fetch origin main`. The working branch
`claude/android-fixes-reminders-uti1nj` started at `origin/main` =
`7291933` (merge of PR #5).

### Part 1: were PR #5's two Android fixes test-proven? Yes, both.

Checked against the actual `android-native.yml` job logs, not the commit
messages:

- **Gradle desugaring (`79725db`).** The gate is the pinned row's
  `flutter build apk --debug` step, which runs on every PR touching
  `android/**`/`pubspec*`. On `1ace642` (run `36260643617`) it failed with
  `Dependency ':flutter_local_notifications' requires core library
  desugaring to be enabled for :app` / `BUILD FAILED`. On `79725db` it
  passed. Reverting the setting would fail that step again.
- **Startup crash (`b24dacc`).** `integration_test/android_startup_test.dart`
  landed in `1ace642`, before the fix. On `79725db` (run `36260925570`)
  both cases failed on the emulator with `PlatformException(flutter_stripe
  initialization failed … MainActivity is not a subclass
  FlutterFragmentActivity)`, the second thrown from `main.dart:15`. From
  `b24dacc` on, both pass; on `5df67cb`, the PR head, 4/4 passed.

No new tests were added for Part 1.

### Part 2: backlog #9, reproduced first, then fixed one layer at a time

`integration_test/reminder_delivery_test.dart` (new) schedules through the
real `ReminderScheduler`, due ~10 s out, and polls
`getActiveNotifications()` for 90 s, printing diagnostics. CI answers the
permission prompt with `.github/scripts/allow-permission-dialogs.sh`, which
taps the real "Allow" button and never `pm grant`s. Each commit was run
with `workflow_dispatch` on the branch (API 34 x86_64 emulator):

| Commit | App change | Emulator result |
|---|---|---|
| `ee307ca` | none (test only) | **Fail:** `PlatformException(exact_alarms_not_permitted)` from `scheduleForAppointment`; before scheduling `notificationsEnabled=false, canScheduleExact=false` (run `36265520078`) |
| `3831aba` | inexact alarm + request `POST_NOTIFICATIONS` | **Fail:** helper `tapped Allow`, `notificationsEnabled=true`, no throw, but no notification after 90 s and `stillPending=[508218634]`: the fired alarm was never received (run `36266184239`; shows "cancelled" because I cancelled just as the step finished, but the log is complete) |
| `2d73d5c` | declare `ScheduledNotificationReceiver`/`BootReceiver` + `RECEIVE_BOOT_COMPLETED` | **Pass:** notification shown ~7 s after the Allow tap, `stillPending=[]`; all 5 integration tests passed (run `36266823630`) |

Worse than the backlog note assumed: step 1 was a *throw*, not a silent
no-op. In the app it would have surfaced right after a successful deposit
payment, through `DepositPaymentScreen`'s catch-all, as "Something went
wrong confirming your payment." That screen wasn't touched (Stripe flow is
out of scope). The throw is gone because `ReminderScheduler` no longer
uses exact alarms. Rationale is in `04-decisions.md` D-10.

**Verified on a real emulator (GitHub `ubuntu-latest`, API 34):** a
reminder scheduled through the production `ReminderScheduler` path is
requested, scheduled without error, received and shown; the app raises
the POST_NOTIFICATIONS prompt itself.

**Not verified:** Doze/idle deferral of the inexact alarm for a real
2-hour lead; re-arming after reboot; the user declining the prompt (no
in-app messaging exists for that); API levels other than 34; the reminder
call's behaviour inside the real post-PaymentSheet flow (needs backlog
#3/#4); iOS (not touched); release builds. Nothing here ran in the Claude
sandbox, which still has no Android SDK or KVM. Dart-side checks (`dart
format`, `flutter analyze`, `flutter test` 20/20) did run locally.
