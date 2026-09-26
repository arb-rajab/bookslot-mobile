# Backlog

Ordered roughly by what would most increase real confidence in this app,
not by ease.

1. ~~**Run `integration_test/` for real**~~: **closed on Android,
   2026-09-26.** `android-native.yml` runs it on a KVM emulator on every
   relevant PR. The first run found the app couldn't start on Android at
   all (see `06-session-handoff.md`'s latest entry). **iOS is still never
   built or run.**
2. ~~**Self-service cancellation**~~ — **closed, Session 2.** bookslot
   shipped `POST /bookings/manage/{token}/cancel` (D-0052); this app's
   `MyBookingsScreen` now calls it for real, including the 409
   already-terminal case and local reminder cancellation. See
   `04-decisions.md` D-08.
3. **Contract verification against a live bookslot instance.** This
   session's API fixtures were hand-copied from reading bookslot's
   controller source, not verified against a running backend (none was
   available). A contract test suite (e.g. Pact, or a scheduled CI job
   that hits a real bookslot staging deployment's demo tenant) would catch
   drift automatically instead of silently going stale.
4. **Stripe PaymentSheet failure-path coverage.** `DepositPaymentScreen`'s
   handling of a declined card, a cancelled sheet, and a `confirm-payment`
   response that comes back non-`confirmed` (bookslot's own documented
   retry-with-a-different-card flow, J2) is implemented but only verified
   by reading the code — PaymentSheet itself can't be driven by
   `flutter_test`/`integration_test`.
5. **Real push notifications — only if a concrete reason emerges.**
   Evaluated and deliberately deferred this session (see
   `01-scope-and-non-goals.md`); local scheduling already demonstrates the
   reminder UX. Revisit only if a specific demo scenario needs a
   notification to arrive while the app is fully closed and the device has
   since rebooted (the one case local scheduling genuinely can't cover).
   *Correction, 2026-09-26: a reboot is not that case. A reminder scheduled
   before a reboot is re-armed and shown afterwards without opening the app
   (#10, D-11). Still out of reach for local scheduling: reminders for
   bookings made on another device, and changes made server-side.*
6. **App icon / branding.** Ships with Flutter's default launcher icon.
   Cosmetic, not functional — lowest priority.
7. **Timezone-aware slot display polish.** `SlotPickerScreen` converts
   slot times to the device's local timezone for display, which is correct
   for a customer physically near the tenant but could be confusing for a
   demo reviewer in a very different timezone than `demo-studio`'s
   `America/Toronto`. Worth a small "times shown in studio's local time"
   affordance if this becomes a real point of confusion in review.
8. ~~**Finish the `flutter_stripe` 13→14 step once a real native Android
   build can be verified.**~~ **Closed 2026-09-26: pin bumped to `^14.1.0`**
   on the maintainer's go-ahead, after the native evidence below. The
   history is kept as-is below. See `04-decisions.md` D-09. Code-level signals
   are good (14.1.0 passes `flutter analyze`/`flutter test` with zero
   changes, and this project's `android/app/build.gradle.kts` is already
   on AGP 9.1.0, which is v14's only real breaking change), but no session
   in this portfolio has ever actually run `flutter build apk` here — this
   session tried, and confirmed the blocker is structural: this sandbox's
   egress policy denies `dl.google.com`, so the Android SDK and Google's
   Maven repo (AGP/AndroidX artifacts) are both unreachable. A future
   session with a container that allows that host (or a pre-provisioned
   Android SDK) should bump `flutter_stripe` to `^14.1.0` in `pubspec.yaml`
   and run `flutter build apk --debug` before calling it verified — this
   is a small, mechanical step at that point, not a re-investigation.
   **Update, 2026-09-26 (same later session): native evidence now exists,
   from CI rather than the sandbox.** On `android-native.yml` (commit
   `b24dacc`), the `14.1.0` candidate row passed both the native build
   (AGP 9.1.0, `android.builtInKotlin=false`) and all 4 emulator
   integration tests. That includes the real `main()` and Stripe native
   initialisation. So did the pinned 13.1.0 row. **Still unverified at
   either version:** `initPaymentSheet`/`presentPaymentSheet` against a
   real PaymentIntent. That needs a live bookslot backend and real Stripe
   test keys (#3, #4). The bump itself (`^14.1.0` in `pubspec.yaml`, after
   which the candidate row can go) is now a decision for the maintainer,
   not an environment blocker. The original re-check note follows.
   **Re-checked 2026-09-26 (later session): still blocked.** `dl.google.com`
   is still denied (403 on CONNECT), `maven.google.com` only 301-redirects
   there, and there's still no KVM, `adb`, or device. The pin was left at
   13.1.0 with no code change. See `06-session-handoff.md`'s latest entry
   for the exact probes and two concrete ways to unblock it (allow
   `dl.google.com` in this environment's network settings, or verify on a
   GitHub-hosted runner with an Android SDK and emulator).
9. ~~**Scheduled reminders probably never fire on Android.**~~ **Closed
   2026-09-26: reproduced on an emulator, fixed, and confirmed on the
   emulator.** The note was right that reminders never showed, but wrong
   that nothing failed loudly. `integration_test/reminder_delivery_test.dart`
   (real plugin, no fakes, API 34) reproduced three stacked bugs, one
   `android-native.yml` run each:
   (1) `zonedSchedule` **threw** `exact_alarms_not_permitted` (run
   `36265520078`), which in the app would surface right after a successful
   payment as "Something went wrong confirming your payment";
   (2) `POST_NOTIFICATIONS` was never requested;
   (3) once both were fixed, the alarm fired but nothing received it,
   because the manifest had no `ScheduledNotificationReceiver`. The reminder
   stayed pending and was never shown (run `36266184239`).
   After switching to inexact alarms, requesting the permission and
   declaring the receivers, the reminder was shown ~7 s after scheduling
   and the test passed (run `36266823630`). See `04-decisions.md` D-10.
   **Still unverified:** Doze deferral of the inexact alarm, the
   permission-declined path, API levels other than 34, and iOS. (Re-arming
   after a reboot was verified later: #10.)
10. ~~**Does a scheduled reminder survive a device reboot?**~~ **Closed
   2026-09-26: yes. Verified on an emulator; no app change needed.**
   Android clears alarms on reboot. The plugin saves scheduled reminders
   to SharedPreferences, and its `ScheduledNotificationBootReceiver` (in
   the manifest since PR #6) re-arms them on `BOOT_COMPLETED`.
   `.github/scripts/reboot-reminder-check.sh` now checks this in
   `android-native.yml` on every relevant PR. It schedules a reminder
   through the real `ReminderScheduler`, runs `adb reboot`, and then,
   without opening the app, watches AlarmManager and the notification
   shade. In run `36273855772` the alarm was back 18 s after boot
   completed and the reminder was shown, 183 s after its scheduled time
   (the inexact window; see #11). With the boot receiver removed, the same
   check *(negative-control result pending)*. See `04-decisions.md` D-11.
   **Still unverified:** a physical device; API levels other than 34;
   OEM builds that restrict boot receivers or background starts; a device
   that stays off past the reminder's time (the plugin re-arms a past
   time, which AlarmManager normally fires at once, but this wasn't run);
   a force-stopped app (Android cancels its alarms and holds back
   `BOOT_COMPLETED` until the next launch, by design); Doze; iOS.
11. **Inexact reminders can arrive well after their scheduled time.** Found
   while verifying #10: on an awake API 34 emulator, AlarmManager gave the
   reminder a delivery window of about 75% of the time left until it was
   due. It delivered at the very end of that window (183 s late for a
   reminder ~4 min out). If that scales, a "2 hours before" reminder
   booked days ahead could arrive much closer to the appointment than 2
   hours. AOSP may cap that window, but this wasn't checked. D-10 chose
   inexact alarms assuming "typically minutes" of deferral. **Not
   measured:** a real multi-hour lead. The fix options have tradeoffs
   (e.g. `setWindow` with a bounded window, or exact alarms with their
   permission costs, per D-10), so this is left for a decision rather than
   changed here.
