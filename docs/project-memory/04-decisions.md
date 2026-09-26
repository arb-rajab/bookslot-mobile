# Decision Log

**D-01. Consume bookslot's real API contracts, verified from source, not
from stale docs.** Two prior sessions elsewhere in this portfolio were
caught trusting a stale README/task brief about bookslot's state (one said
"Session 8, scaffold only" when the real state was Session 18; another
assumed no frontend existed when one had shipped two sessions earlier).
This session read bookslot's `docs/project-memory/12-session-handoff.md`
Session 20 amendment and the actual `routes/api.php` /
`app/Http/Controllers/Api/*.php` source directly before writing any model
or API client code, rather than trusting a summary.

**D-02. Use bookslot's existing seeded `demo-studio` tenant, not a new
one.** bookslot's `database/seeders/DatabaseSeeder.php` already creates a
`demo-studio` tenant ("Demo Tattoo Studio") with a real service, staff
working hours, and a few demo appointments — added in bookslot Session 17
specifically because "the public booking page ... has no owner dashboard
to create services/staff through yet." That's exactly this app's own need.
Standing up a second, redundant demo tenant would have meant either
duplicating that seeder's work or asking for push access to bookslot to
add one — this session only had read access to bookslot (by design; this
is a separate, public repo), so reusing the existing seed data was both
the simplest and the most honest choice.

**D-03. No state-management framework.** See `02-architecture.md`. Every
screen's data need is one async fetch; `StatefulWidget` + `FutureBuilder`
expresses that directly without a framework's boilerplate.

**D-04. `provider` used only for service-layer DI, not app state.** The
one `Provider<AppServices>` at the widget tree root exists so screens can
`context.read<AppServices>().api` without threading four constructor
parameters through every route. No `ChangeNotifier`/`Consumer` rebuild
pattern is used anywhere — nothing in this app has state that outlives a
single screen's own `setState`.

**D-05. Local, per-device "my bookings," not a server-side account
system.** Forced by bookslot's own API shape (D-0009: the public booking
flow is deliberately unauthenticated). Building a customer account system
on bookslot's backend to support this would be a change to bookslot itself
— explicitly out of scope for a session with only read access to that
repo. See `01-scope-and-non-goals.md`'s "no self-service cancellation"
note for the same constraint applied to cancellation.

**D-06. Cancellation UI is honest about not working, not removed and not
faked.** Considered three options: (a) omit the Cancel button entirely,
(b) wire it to bookslot's owner-only cancel endpoint (this app holds no
owner credentials — would either fail every time or require smuggling
credentials this app should never have), (c) show the action with a clear
explanation of the real limitation. Chose (c): a customer looking for how
to cancel should find the button, and the explanation is genuinely useful
(it tells them to contact the studio directly) rather than either hiding
the need or pretending the app already handles it.

**D-07. flutter_stripe, not a raw Stripe REST integration.** bookslot's
`BookingController` already creates the PaymentIntent server-side and
returns a `client_secret`; the client's only job is presenting Stripe's
own SCA-compliant confirmation UI and reporting back. `flutter_stripe`'s
PaymentSheet does exactly that with Stripe's own maintained, accessible
native UI — reimplementing card collection UI by hand would be strictly
worse and riskier (PCI scope) for zero benefit in a demo app.

**D-08. Self-service cancellation now calls a real endpoint, superseding
D-06 (Session 2).** bookslot Session 21 shipped D-0052 —
`POST /bookings/manage/{token}/cancel`, reusing the existing
`manage_booking` token, no new token class. This session (which had read
access to bookslot to verify the contract directly from
`routes/api.php`/`ManageBookingController::cancel()`, not just this
prompt's description of it) wired `MyBookingsScreen`'s Cancel action to
it: a 409 `INVALID_STATUS_TRANSITION` response (already
cancelled/completed/no-show) is shown as a clear failure message, never
treated as success; on success the booking's locally-tracked live status
updates immediately and its scheduled local reminder notification is
cancelled via `ReminderScheduler.cancelForAppointment`. D-06's three
options (omit / fake / explain-the-gap) are moot now that a real endpoint
exists — this is simply "wire it for real," the option D-06 itself
called out as preferable once bookslot closed the gap.

**D-09. `flutter_stripe` upgraded 11→13, not 11→14; the AGP-9 boundary
(v14) deferred for a verification reason, not a code reason.** A prior
session flagged four risk points before deferring this upgrade: v12
requiring Freezed v3, v12.2 deprecating `SetupPaymentSheetParameters`/
customer-sheet constructors, v13 changing `confirm()`'s return shape, and
v14 requiring an AGP 9 bump. This session re-read `flutter_stripe`'s real
CHANGELOG.md (from its GitHub repo, not pub.dev's summary) end to end for
all four boundaries and found three of those four claims did not hold up
against what this app's code actually calls:

- v12.0.0 truly does require Freezed v3 — confirmed. Irrelevant to this
  app's own build, though: this app has no `build_runner`/freezed codegen
  of its own (`freezed_annotation` is only a transitive dependency of
  `flutter_stripe`'s own generated types), so `flutter pub get` resolved
  it automatically with zero code changes.
- v12.2.0's actual deprecation is old `CustomerSheet` constructors
  ("Implemented new constructors for customer sheet and deprecated the old
  ones") — not `SetupPaymentSheetParameters`. This app never uses
  `CustomerSheet` at all; `SetupPaymentSheetParameters` is never mentioned
  as deprecated anywhere in the changelog's full history. The prior
  session's claim conflated the two.
- v13.0.0's actual breaking change is `collectBankAccountForPayment` and
  `verifyPaymentIntentWithMicrodeposits` returning a new
  `CollectBankAccountResult` sealed class instead of `PaymentIntent` — a
  bank-debit/microdeposit verification API this app never calls. There is
  no `confirm()` return-shape change in this changelog at all; this app
  doesn't call a Stripe SDK `confirm()` method either — `DepositPaymentScreen`
  uses `initPaymentSheet`/`presentPaymentSheet` (which confirm internally)
  and then calls bookslot's own `confirm-payment` REST endpoint, which is
  this app's HTTP method of the same name, not a Stripe SDK call.
- v14.0.0's actual breaking change ("Breaking: add support for AGP 9") is
  the one claim that held up exactly as described.

Net effect: bumping `flutter_stripe` straight through 12.6.0 → 13.1.0
required zero code changes in this app — `dart format`, `flutter analyze`
("No issues found!"), and the full 20-test suite were all re-verified
clean at each step (see `06-session-handoff.md` Session 3). Stopping at
13.1.0 rather than pushing to 14.1.0 was **not** because 14.1.0 broke
anything: it also passed `flutter analyze`/`flutter test` with zero
changes, and this project's own `android/app/build.gradle.kts` was
already on AGP 9.1.0 before this session touched anything (a byproduct of
`flutter create` on Flutter 3.47.5's default template, unrelated to
`flutter_stripe`'s version) — so there was no actual AGP bump left to
perform. The reason to stop is that this session could not run a real
native Android Gradle build at all, at any `flutter_stripe` version, to
prove that pairing actually compiles: this sandbox's egress policy denies
`dl.google.com` (confirmed via the proxy's own documented 403 failure
class when attempting to fetch Android cmdline-tools — not assumed), which
blocks both fetching the Android SDK and Gradle's own resolution of the
Android Gradle Plugin / AndroidX artifacts from Google's Maven repo. That
gap is not new or specific to v14 — no session (1, 2, or this one) has
ever actually run `flutter build apk` in this portfolio's environment —
but this task explicitly named the AGP-9 boundary as the one to hold at if
its native build tooling proves unverifiable here, rather than shipping a
version bump whose one real risk point (a native build tooling change) was
never actually exercised. See `05-backlog.md` for the follow-up.
*Re-checked 2026-09-26 by a later session: the blocker is unchanged
(`dl.google.com` still denied; no KVM, emulator or device). The decision
stands as written. See `06-session-handoff.md`'s latest entry.*
*Later the same day, `.github/workflows/android-native.yml` supplied the
missing native evidence from a GitHub runner. 14.1.0 builds with this
project's AGP 9.1.0 setup, and passes all emulator integration tests
(including Stripe native init via the real `main()`). The remaining
unverified piece is a real PaymentSheet flow, which is gated on a live
backend and Stripe keys rather than on the SDK version. Two pre-existing
Android bugs surfaced and were fixed along the way. See the handoff.*
*On that evidence the maintainer approved the bump: the pin is now
`^14.1.0`. The PaymentSheet-flow gap noted above still applies (backlog
#3/#4); it's no longer a reason to hold the version.*
