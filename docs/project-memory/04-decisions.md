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
*Follow-up (backlog #9 session): PR #5's two Android fixes were re-checked
against their CI logs. Both were reproduced as failures before the fix
landed, so no new regression tests were needed. See D-10 and the
handoff.*

**D-10. Android reminders use inexact alarms and ask for
`POST_NOTIFICATIONS` just in time; CI answers the real permission dialog
instead of pre-granting.** Backlog #9 was reproduced on an API 34 emulator
(`integration_test/reminder_delivery_test.dart`, via `android-native.yml`).
It turned out to be three stacked bugs, each confirmed by its own emulator
run before being fixed:

1. `zonedSchedule(..., exactAllowWhileIdle)` **threw**
   `PlatformException(exact_alarms_not_permitted)`. The backlog note had
   assumed a silent failure. The app never declared `SCHEDULE_EXACT_ALARM`,
   which Android 14 no longer pre-grants anyway. In the app that call runs
   right after a successful deposit payment, inside `DepositPaymentScreen`'s
   catch-all, so on Android 12+ a customer who had just paid would have been
   told "Something went wrong confirming your payment."
2. Nothing ever requested `POST_NOTIFICATIONS`, so on Android 13+
   notifications were disabled (`areNotificationsEnabled() == false`).
3. With both fixed, the alarm fired but nothing received it: the reminder
   stayed in `pendingNotificationRequests()` and never showed, because
   `ScheduledNotificationReceiver` wasn't declared in the app manifest.

Choices made:
- **Inexact (`inexactAllowWhileIdle`), not exact.** The alternatives were
  `SCHEDULE_EXACT_ALARM`, which the user has to switch on in system
  Settings (a poor prompt for a booking app), and `USE_EXACT_ALARM`, which
  Google Play restricts to alarm-clock/calendar apps. A reminder two hours
  before an appointment doesn't need to land to the second. Tradeoff: when
  the device is in Doze, Android may defer it (typically by minutes). That
  deferral is **not** measured: the emulator test fires ~10 s out on an
  awake device.
- **Ask for `POST_NOTIFICATIONS` inside `scheduleForAppointment`,** i.e.
  the first time there's a reminder worth showing, rather than at app
  launch. If the user declines, the reminder is still scheduled but
  Android suppresses it. There's no in-app messaging about that (not
  built; small follow-up if it matters).
- **CI plays the user rather than pre-granting.**
  `.github/scripts/allow-permission-dialogs.sh` taps "Allow" on the real
  system dialog while the emulator tests run, and never calls `pm grant`.
  So the test fails if the app stops *requesting* the permission, not just
  if it stops declaring it.

iOS was deliberately not touched (no iOS build or run exists; see backlog
#1).
*Follow-up (reboot session): reminders survive a reboot, verified on the
emulator with no app change (D-11). That run also showed an inexact
reminder landing at the end of its window, late by about 75% of the time
that was left until it was due, so the "typically by minutes" above holds only for short leads.
See backlog #11.*


**D-11. Reminders survive a reboot: verified on an emulator, no app
change needed. The on-device check stays in CI.** After backlog #9, it was
an open question whether a scheduled reminder still exists after a
restart. Android drops all alarms on reboot, so something has to re-arm
them. The pieces were already in place:
- `flutter_local_notifications` saves every scheduled notification to
  SharedPreferences (`scheduled_notifications`).
- Its `ScheduledNotificationBootReceiver` reloads that list on
  `BOOT_COMPLETED` and calls AlarmManager again.
- PR #6 (D-10) had declared that receiver and `RECEIVE_BOOT_COMPLETED` in
  the app manifest, because since v16 the plugin no longer declares them.

That was only a prediction from reading the code, so it was checked on an
API 34 emulator with `.github/scripts/reboot-reminder-check.sh` (backlog
#10). The script launches a probe build once. The probe
(`integration_test/reboot_probe_main.dart`) schedules a reminder, due in
5 minutes, through the real `AppServices`/`ReminderScheduler`. The script
confirms the app's alarm is in `dumpsys alarm` and runs `adb reboot`.
Then, **without reopening the app**, it polls `dumpsys alarm` and
`dumpsys notification`. Run `36273855772` (`2fd2161`):
- The emulator rebooted in 30 s.
- The alarm was back in AlarmManager 18 s after boot completed, due at
  its original time (`origWhen` unchanged).
- The reminder was shown 183 s after its scheduled time.

The negative control removed the boot receiver from the manifest and
changed nothing else (run `36275027018`, `8a69102`, reverted in
`fe7e733`). The same check then **failed**. The alarm was in AlarmManager
before the reboot. The emulator rebooted in 38 s. After boot, no app alarm
ever came back, and no reminder was shown even 480 s past its time. So
the check does detect a reminder lost to a reboot, and in this build the
boot receiver is what prevents that.

Choices made:
- **No app code change.** The plugin's persistence and boot receiver
  already do the job. A custom receiver would duplicate them.
- **The check stays in `android-native.yml` on every relevant PR**, not
  as a one-off. Removing that manifest entry, or a plugin upgrade that
  changes the mechanism, would otherwise go unnoticed. It adds ~8 minutes
  to the emulator step.
- **Shell-driven, not a `flutter test`.** A Dart test can't span a reboot.
  Also, when `flutter test` finishes it force-stops the app (see
  `integration_test_device.dart` in `flutter_tools`), which cancels the
  app's alarms and blocks `BOOT_COMPLETED` until the next launch. The
  post-boot checks must not open the app either, since a customer's
  reminder has to come back without that.

**The 183 s lateness is the inexact alarm's window, not the reboot.**
AlarmManager reported the window before the reboot (`window=+3m41s` for a
reminder ~290 s out) and after re-arming (`window=+3m3s`, ~242 s out),
i.e. about 75% of the time remaining. Delivery came right at the end of
the second window. D-10 assumed inexact deferral would be "typically
minutes". It isn't measured for a real reminder scheduled hours or days
ahead, so it's tracked separately (backlog #11) and not changed here.

**D-12. Measured inexact-reminder lateness at product scale (backlog
#11): AlarmManager's window is capped, not proportional without bound —
this does not look like a real customer-facing problem, but only two
data points exist at the large scale.** D-11 found a ~75%-of-remaining
window at a ~4 minute scale and flagged that, if that ratio scaled
unboundedly, a "2 hours before" reminder booked days ahead could arrive
much later than promised (in principle tens of hours late). This
session measured it directly on an API 34 emulator
(`integration_test/lateness_probe_main.dart` +
`.github/scripts/reminder-lateness-check.sh`, dispatched by a new,
dispatch-only `reminder-lateness-probe.yml`, briefly also wired to
`pull_request` to get this PR's own first run — see that workflow's
`on:` history), scheduling through the real
`AppServices`/`ReminderScheduler` with the product's real 2-hour lead
time throughout; only how far out the alarm was due was varied.

Two trial types, three trials total, all in run `36307134341`:

- **Real elapsed wait, ~15 minute scale (2 trials, no simulation of any
  kind — full real wall-clock time, moderately larger than D-11's ~4
  minute case).** Both trials show the same ~75% window AlarmManager
  reported at the ~4 minute scale, holding almost exactly at ~15 minutes
  too:
  - Trial 1: interval 886s, window `+11m8s688ms` (668.7s, 75.5% of the
    interval). Reminder shown 512s after its scheduled time — 57.8% of
    the interval, i.e. inside the window but not at its far edge.
  - Trial 2: interval 892s, window `+11m12s363ms` (672.4s, 75.4%).
    Reminder shown 592s late — 66.4% of the interval.
  So the ~75% *window* ratio replicates cleanly at ~4x the scale D-11
  measured it at, but actual delivery lateness varies within that
  window (57.8% and 66.4% here, not "always at the very end" as D-11's
  single data point suggested) — call it "somewhere in the back half of
  the window," not a fixed point.
- **Clock-jumped, ~70 hour scale (1 trial only — see limitations
  below).** A reminder scheduled with `startsAt` ~3 days out (a genuine
  "booked days ahead" shape, 251991s/~70h from scheduling to due, lead
  time still the product's real 2 hours) got, immediately after
  scheduling and **before any clock manipulation**, a real,
  un-simulated AlarmManager reading of `window=+1h0m0s0ms` — exactly one
  hour, not ~75% of the 70 hour interval (which would have been ~52
  hours). This is the key finding: **the window does not grow without
  bound as the interval grows; it's capped, and the cap looks like
  exactly one hour.** After jumping the device clock forward 69 hours
  (via `adb root` + `adb shell date`, confirmed to actually take effect)
  to leave 600s of real time before the reminder was due, AlarmManager
  recalculated the alarm and still reported the same `window=+1h0m0s0ms`
  cap (`maxWhenElapsed` about 70 minutes past the jump point). The
  reminder was actually shown only **180s (3 minutes) after its
  scheduled time** in the real elapsed time that followed the jump —
  well inside the capped window, near its front rather than its back.

**What this does and doesn't show.** The two ~15-minute trials are
uncomplicated real-elapsed-time evidence: nothing was simulated, and
they replicate D-11's ratio almost exactly at a larger scale. The ~70
hour trial's AlarmManager *window* reading (the 1-hour cap) is equally
real and un-simulated — it's what AlarmManager reported immediately
after a normal, real `zonedSchedule` call, before the clock was touched.
Its *delivery* reading (180s late) is not on the same footing: getting
there required skipping ~69 hours of wall-clock time with `adb shell
date` rather than actually waiting it out, so it does not exercise
whatever Android would normally do with the device over a real 3-day
span — Doze/App Standby bucket transitions depend on real elapsed idle
time, screen state, charging, and motion, none of which happened here.
An abrupt system clock jump is also not a normal event from
AlarmManager's point of view (it did visibly trigger a full alarm
recalculation, which is itself informative, but that recalculation path
may not be identical to letting the same 69 hours elapse for real).
Treat "the alarm survived the jump and delivered promptly afterward" as
a positive sign, not as confirmation that a genuine multi-day wait would
behave identically — that full real-time confirmation is still not
done, and would cost roughly 3 days of a CI job to get.

**Does this look like a real customer-facing problem at 2-hour/days-ahead
scale?** Based on what was measured: **no, not obviously** — the
1-hour cap, if it holds in general (only one trial reached this scale),
bounds the worst case to roughly an hour of lateness, not the tens of
hours the unbounded-75%-extrapolation in backlog #11 worried about, and
the one large-scale trial that was run delivered promptly (3 minutes
late) rather than near the theoretical worst case. But this rests on a
single large-scale trial with a clock-jump for the wait portion, not a
repeated or fully real-time-confirmed one. Whether an up-to-~1-hour
worst case is acceptable for a "2 hours before" promise, and whether
it's worth spending more CI time (or a real multi-day run, or repeat
trials) to firm up the cap finding before deciding, is a product call —
not made here. See backlog #11.

**D-13. Two real-elapsed trials (no clock jump) confirm the ~1-hour
AlarmManager window cap from D-12, but show actual delivery landing at
the far edge of that window, not near the front as D-12's single
clock-jumped trial suggested.** D-12's ~70-hour-scale trial got its
delivery reading (180s/3min late) by jumping the emulator's clock
forward for the wait, which the D-12 write-up flagged as weaker
evidence than a real wait: a clock jump skips whatever Doze/App Standby
bucket transitions a real idle device goes through over that span. This
session tried to close that gap with a genuine real-elapsed wait at
product scale (real `AppServices`/`ReminderScheduler`, real 2-hour lead
time, API 34 emulator), reusing `lateness_probe_main.dart` /
`reminder-lateness-check.sh` with a new `long_real_*` trial mode added
to `reminder-lateness-probe.yml` for this measurement.

**A genuine ~70-hour real-elapsed wait does not fit in one CI job.**
GitHub Actions hard-caps a GitHub-hosted runner job at 6 hours of
execution time regardless of `timeout-minutes`; spanning a real ~70-hour
wait across multiple jobs/days was out of scope for this one-off
measurement. The longest due-time scale that reliably fits one job
alongside build/boot/grace overhead is a few hours — well short of
D-12's ~70-hour clock-jumped scale, but still a real, un-simulated wait
many times longer than D-11/D-12's ~15-minute real-elapsed trials.

Two trials, both scheduled with the real 2-hour lead time and waited
out entirely in real elapsed time (no clock manipulation at all):

- **Run `36356883865`, due time 180 min (~3h) out, grace 7200s (2h) —
  clean, exact reading.** Scheduled at 2026-09-27T23:04:40Z, due at
  2026-09-28T02:04:33Z (10788s/~3h interval). AlarmManager's window
  immediately after scheduling: `window=+1h0m0s0ms` — the same 1-hour
  cap D-12 found at the ~70-hour scale, now confirmed at a ~3-hour
  scale too (`whenElapsed=+2h59m47s89ms maxWhenElapsed=+3h59m47s89ms`).
  The reminder was shown at 2026-09-28T03:04:33Z — **exactly 3600s (60
  min) after its scheduled time, ±2s polling: 33.4% of the 10788s
  scheduling-to-due interval, and 100% of the 3600s window.** Delivery
  landed at the very far edge of the capped window, not somewhere
  inside it.
- **Run `36337821897`, due time 240 min (~4h) out, grace 3600s (1h) —
  corroborating but not exact.** Scheduled with a 14384s (~4h) interval,
  due at 2026-09-27T21:50:18Z, same `window=+1h0m0s0ms` cap reading.
  This trial's grace period was set to exactly 3600s (the window's own
  width), with no buffer past it, so the check's polling loop hit its
  deadline and logged `FAIL: no reminder shown, 3600 s past its
  scheduled time` before ever seeing it appear. The diagnostics dump
  taken immediately afterward (within ~1s of the FAIL), however, shows
  the reminder notification *had* posted by then
  (`NotificationRecord(...channel=appointment_reminders...seen=true)`).
  So real delivery in this trial was also at essentially the 3600s/100%-
  of-window mark — consistent with the second run's exact reading — but
  not pinned to a precise second, because the grace period left no
  margin to catch the actual moment. (This run's own grace-sizing
  mistake is fixed for future use: `long_real_grace_seconds` should
  always be set well past the expected window, not equal to it.)

**Compared with D-12's clock-jumped ~70h trial (window `+1h0m0s0ms`,
delivered 180s/3min late — about 5% into the window, near its front
edge):** both real-elapsed trials here found the same window cap, but
landed at the *opposite* end of it — essentially 100% of the window
used (~3600s/1h late) rather than ~5%. That is a real, material
divergence, not noise: it shows up consistently across both real-
elapsed trials (one exact, one corroborating), at two different
due-time scales (3h and 4h), both landing at the same ~3600s mark
rather than scattering. The most direct explanation is that a real
idle device (screen off, unplugged, no motion — Doze territory) delays
inexact-alarm delivery toward the far edge of whatever window
AlarmManager grants it, an effect a clock jump cannot reproduce because
it skips the real idle time Doze/App Standby transitions depend on.

**What this does and doesn't show.** These two trials are real,
un-simulated evidence for delivery landing at the back edge of the
1-hour cap at the 3-4 hour scale — a materially worse practical result
than D-12's single clock-jumped data point (3 min late) suggested, even
though the *window* cap itself (1 hour) is unchanged and still well
below the tens-of-hours worst case the original backlog #11 concern
was about. Still open: whether this same back-edge pattern holds, gets
worse, or changes at the true ~70-hour/multi-day scale that motivated
backlog #11 in the first place — neither trial here reached that scale
(the 6-hour CI job cap is the reason), and D-12's own ~70-hour data
point used a clock jump, so no real-elapsed trial has yet reached
anywhere near that scale. Doze state itself was not independently
confirmed via `dumpsys deviceidle` or similar during either wait — the
inference that Doze is the mechanism rests on elapsed idle time and the
window-edge timing pattern, not a direct measurement of the device's
idle bucket.

**Is the evidence now strong enough to support a decision?** More than
before, but not complete. What's now known: the 1-hour window cap
replicates from a ~3-hour real-elapsed scale up through D-12's
~70-hour clock-jumped scale, and — new in this session — real-elapsed
delivery (not clock-jumped) consistently lands at the far edge of that
window rather than near the front, in both trials that measured it.
What's still missing: a real-elapsed trial at the actual multi-day
scale that motivated backlog #11 (blocked by the CI job's 6-hour hard
cap in this environment), repeat trials at the 3-4 hour scale to rule
out this being a two-data-point coincidence, and direct Doze-state
confirmation. Whether a worst-case ~1-hour-late "2 hours before"
reminder — now looking like the *typical* real-elapsed outcome rather
than a rare tail case — is acceptable, or whether this new evidence
tips the balance toward `setWindow`/exact alarms, is a product call —
not made here. See backlog #11.

**D-14. Accepted the ~1-hour worst-case reminder lateness from D-12/D-13
as an Android platform constraint; corrected customer-facing copy
instead of implementing exact alarms.** D-13's two real-elapsed trials
found actual delivery landing consistently at the far edge of the
~1-hour inexact-alarm window, not near the front — meaning a "2 hours
before" reminder can, in the realistic worst case, arrive with only
about half its promised lead time (roughly 1 hour before the
appointment instead of 2). That's frequent enough (confirmed at two
different due-time scales, 3h and 4h, both real-elapsed) that it isn't
a rare tail case for this backlog item's purposes.

**Decision: accept it, don't implement exact alarms this session.**
Exact alarms (`SCHEDULE_EXACT_ALARM`, or `USE_EXACT_ALARM` which Play
reserves for alarm-clock/calendar apps) would fix the lateness, but
`SCHEDULE_EXACT_ALARM` costs a real permission prompt — user friction,
and possible Play Store policy scrutiny for an app that isn't an
alarm-clock/calendar app — that isn't justified without real usage
data showing customers are actually harmed by a ~1-hour-late reminder.
This stays explicitly deferred pending such a signal; `setWindow` with
a bounded window remains the other option on the table from D-10 if the
call changes later.

**What this session actually changed: an audit of every place the app
states or implies a specific reminder lead time to a user, and a fix
for the internal scheduling-code comment.** Searched `lib/` (all
screens, `app_services.dart`, `reminder_scheduler.dart`), `README.md`,
the Android manifest, and existing widget/integration tests for any
wording that names a lead time. Result: **no customer-facing text in
this app states "2 hours before" or any specific lead time at all.**
`BookingConfirmationScreen` shows only the service name and the
appointment's own start time; the scheduled notification's body is
`'$serviceName is coming up soon.'` (no number); the Android
notification channel description ("Reminds you ahead of an upcoming
bookslot appointment") and `README.md`'s feature bullet ("Get a local
reminder notification ahead of your appointment.") are both already
number-free. No widget or integration test asserts a literal "2 hours
before" (or similar) string as expected UI text either, so none needed
updating. The "2 hours before" figure only ever appeared in this
decision log, the backlog, CI scripts/workflow comments, and one
scheduling-code comment in `reminder_scheduler.dart` — none of which a
user sees. That comment (next to
`androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`)
previously read "A reminder two hours out doesn't need to land to the
second," which understated the actual lateness now measured; it's been
rewritten to state the ~1-hour worst case directly and point at D-10/
D-12/D-13/D-14. `leadTime`'s `Duration(hours: 2)` default itself is
correct as-is (that's the real scheduling offset, unchanged) and needed
no rename — only the surrounding comment was misleading, not the
identifier.

**Not silently missed, but also not found:** the search above covered
this repo (`bookslot-mobile`) only, since this session's scope is
copy/messaging-accuracy in this app. If bookslot's backend (a separate
repo) sends its own confirmation emails/SMS naming a reminder lead
time, that's outside this session's reach and unverified here. Within
this repo, the search was exhaustive over all `.dart` files under
`lib/`, `test/`, and `integration_test/`, plus `README.md` and the
Android manifest — there is no localization/`.arb` file, FAQ screen, or
settings screen in this app at all to have missed. If either is added
later, it must phrase reminder timing as a range ("1-2 hours before" or
equivalent), not a fixed point, per this measurement. See backlog #11.

**D-15. Verified `main`'s required status checks against PR #10 merging
with a failing `android-native.yml` job — confirmed the regression tests
from PR #6/#7 are not enforced, and could not change branch protection
from this session.** PR #10's summary said the android-native check
"isn't required for merge" and merged anyway despite it failing. This
session set out to confirm that from the actual branch-protection
config (not PR wording) and fix it if true.

**What was confirmed, and how.** This session's GitHub access is the
`mcp__github__*` MCP tool set only (direct `gh`/REST API calls are
disallowed by session policy), and that tool set has no branch-protection
or ruleset endpoint — no way to read or write `main`'s required status
checks from here. Branch protection itself could not be inspected
directly. As an indirect check, `pull_request_read get_check_runs` on
PR #10 shows two checks on its head commit: `analyze-and-test`
(`ci.yml`, Dart-only) with `conclusion: "success"`, and
`flutter_stripe pinned` (`android-native.yml`) with
`conclusion: "failure"` — yet the PR shows `merged: true`. GitHub
refuses to merge (without an admin override) when a required check is
failing, so a merge going through on a red `flutter_stripe pinned` is
strong evidence that check is *not* currently a required status check on
`main`. This matches PR #10's own summary; it wasn't describing some
narrower non-blocking sub-step.

**Which job actually carries the regression tests, precisely.**
`android-native.yml` defines one job, `native` (matrix over
`stripe_versions`, default `["pinned"]`), whose check name on a normal
PR is always `flutter_stripe pinned` — the extra "try a future
flutter_stripe version" rows from PR #5 only exist when someone manually
dispatches the workflow with additional versions in `stripe_versions`;
on an ordinary pull request only the `pinned` row ever runs, so the
deliberately-optional evaluation job doesn't appear as a PR check at
all. Both regression tests introduced across PR #6 (backlog #9,
`integration_test/reminder_delivery_test.dart`, reminder scheduling/
delivery) and PR #7 (backlog #10, `.github/scripts/reboot-reminder-check.sh`,
reboot survival) run as steps inside that same single `native` job/
`flutter_stripe pinned` check — via `run-integration-tests.sh` and
`reboot-reminder-check.sh` respectively, both called from the "integration_test
on emulator" step. There is exactly one check name to make required for
both regressions: `flutter_stripe pinned`. `continue-on-error` on that
job's steps is `false` whenever `matrix.stripe == 'pinned'` (true only
for a manually-dispatched candidate version), so a real regression in
either test already fails this check's conclusion — the only miss is
that nothing on `main` currently requires that conclusion to be green
before merging.

**Change needed, and why this session didn't make it.** `flutter_stripe
pinned` needs to be added to `main`'s required status checks (repo
Settings → Branches → branch protection rule for `main` → "Require
status checks to pass" → add `flutter_stripe pinned`), leaving
`analyze-and-test` as-is and not adding any per-dispatch candidate-stripe
check names (they don't appear on PRs to add anyway). This session
could not make that change itself — no available tool reaches branch
protection, and this session was directed not to fall back to direct
API/CLI access for it — so the repo owner needs to apply it manually via
the settings page above. **Tradeoff to flag once this is required:** the
known Android system-process flakiness in this job (PR #9, PR #10) will
now occasionally block a legitimate merge until a re-run clears it, not
just show a red check that could be ignored. That flakiness is out of
this session's scope to fix (tracked separately) — but an occasional
flaky retry gating merge is the intended tradeoff versus an unenforced
regression check, per this task's own instruction.

**Follow-up, same day: the repo owner applied the change above directly
in GitHub Settings, and also required `analyze-and-test`.** Before this,
`main` had no classic branch protection rule at all — not just a missing
`flutter_stripe pinned` check, but nothing configured, so
`analyze-and-test` (`ci.yml`) wasn't required either. The owner created a
protection rule for `main` with "Require status checks to pass before
merging" and added both `flutter_stripe pinned` and `analyze-and-test`
as required checks. The `analyze-and-test` addition was the owner's own
call, made directly in the GitHub UI, not something this session
determined was in scope or asked for — recorded here for completeness
since it changes `main`'s actual protection state beyond what this
decision's "change needed" section above called for.
