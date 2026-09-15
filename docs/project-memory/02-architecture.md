# Architecture

## Stack

Flutter 3.47 (stable channel), Dart 3.13. `provider` for dependency
injection of service-layer singletons (not app state management — this app
has no complex shared state beyond what each screen's own `FutureBuilder`
holds). `http` for the API client, `shared_preferences` for local booking
records, `flutter_local_notifications` + `timezone` for reminders,
`flutter_stripe` for the deposit PaymentSheet.

## Layout

```
lib/
  config/env.dart          # API base URL, demo tenant slug, Stripe publishable key
  models/                  # Service, Slot, Mandate, Booking* — plain fromJson() classes
  api/bookslot_api_client.dart   # the entire HTTP surface this app uses
  services/
    local_bookings_store.dart    # per-device "my bookings" (see below)
    reminder_scheduler.dart      # local notification scheduling
  app_services.dart        # bundles the above into one Provider value
  screens/                 # one file per screen, StatefulWidget + FutureBuilder
  widgets/money.dart        # minor-units currency formatting shared by screens
```

No BLoC/Riverpod/state-management framework was introduced — every screen's
data need is a single async fetch plus local form state, which
`StatefulWidget` + `FutureBuilder` expresses directly. Introducing a
framework for that would be exactly the kind of premature abstraction this
portfolio's own conventions warn against.

## The booking flow, end to end

1. `ServicesListScreen` — `GET /tenants/{slug}/services`.
2. `SlotPickerScreen` — `GET /tenants/{slug}/availability` for the next 14
   days, grouped by local calendar day.
3. `BookingFormScreen` — `GET /tenants/{slug}/services/{id}/mandate` for the
   server-rendered consent text, customer name/email/phone form, then
   `POST /tenants/{slug}/bookings`. This step never sends mandate *text* —
   only `mandate_accepted: true` and the `mandate_template_version` the
   mandate endpoint returned, matching bookslot's D-0015(b) contract
   exactly.
4. `DepositPaymentScreen` — Stripe PaymentSheet against the
   `client_secret` the booking response carried, then
   `POST /bookings/{token}/confirm-payment` to make bookslot's own DB state
   agree with what Stripe actually did (bookslot's `PaymentConfirmationController`
   re-checks Stripe itself; this app's confirm-payment call is not
   optional set-dressing).
5. On confirmed success: the booking's `manage_token` +
   `appointment_id` are saved locally (`LocalBookingsStore`) and a local
   reminder notification is scheduled from the appointment's own
   `starts_at`.

## Why "my bookings" is per-device, not per-account

bookslot's public booking API is deliberately unauthenticated (bookslot's
own D-0009) and has no "list my bookings" endpoint — the signed
`manage_token` issued at booking time is the *only* way to look a booking
up again (`GET /bookings/manage/{token}`). This app's "My bookings" screen
is therefore just a local list of tokens this device has seen, refreshed
against bookslot's real status endpoint. It is lost on uninstall or device
change — a real, stated limitation of bookslot's own API shape, not a
shortcut taken by this app. See `05-backlog.md`.

## Reminders are local-only, by design

See `01-scope-and-non-goals.md` for the reasoning. Mechanically: on
successful deposit confirmation, `ReminderScheduler.scheduleForAppointment`
schedules one `flutter_local_notifications` `zonedSchedule` call, keyed by
a stable hash of the appointment id so re-scheduling or cancelling the same
appointment's reminder is idempotent.

## Two Stripe-touching calls, matching bookslot's own transaction boundary

bookslot's `BookingController`/`PaymentConfirmationController` deliberately
keep the Stripe call outside any open database transaction (their own
D-0027/D-0033). This app's job is simpler but has the same shape: never
assume the PaymentSheet completing means bookslot's own appointment/payment
rows are updated — always call `confirm-payment` and read its `status`
back, since that's the only source of truth bookslot's own backend
considers authoritative.

## Configuration

`lib/config/env.dart` reads three `--dart-define` values (API base URL,
tenant slug, Stripe publishable key), defaulting to the public demo tenant.
No secret ever lives in this repo — the Stripe key baked into a release
build is a `pk_test_...` publishable key, safe to ship client-side by
Stripe's own design.
