# Backlog

Ordered roughly by what would most increase real confidence in this app,
not by ease.

1. **Run `integration_test/booking_flow_test.dart` for real**, against a
   booted Android emulator or iOS simulator (`flutter test integration_test`
   or `flutter drive`). Written and statically clean, never executed — no
   device was available in this session's environment. This is the single
   biggest gap between "looks right" and "proven right" in this repo right
   now.
2. **Self-service cancellation** — needs a real customer-facing cancel
   endpoint on bookslot's side (e.g. `POST /bookings/{token}/cancel` under
   the existing `manage_booking` signed-token mechanism, mirroring how
   `confirm-payment` already reuses a token class). This app's
   `MyBookingsScreen` already has the UI slot ready; it just has nothing
   real to call. Out of this session's scope (read-only access to
   bookslot).
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
6. **App icon / branding.** Ships with Flutter's default launcher icon.
   Cosmetic, not functional — lowest priority.
7. **Timezone-aware slot display polish.** `SlotPickerScreen` converts
   slot times to the device's local timezone for display, which is correct
   for a customer physically near the tenant but could be confusing for a
   demo reviewer in a very different timezone than `demo-studio`'s
   `America/Toronto`. Worth a small "times shown in studio's local time"
   affordance if this becomes a real point of confusion in review.
