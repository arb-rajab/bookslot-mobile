# Scope and Non-Goals

## In scope (Session 1, this repository's first build session)

- Browse a demo tenant's services (`GET /tenants/{slug}/services`).
- Browse real, derived availability for a chosen service
  (`GET /tenants/{slug}/availability`).
- View the server-rendered deposit mandate before booking
  (`GET /tenants/{slug}/services/{service}/mandate`).
- Create a booking against the real endpoint
  (`POST /tenants/{slug}/bookings`), which returns a Stripe PaymentIntent
  `client_secret`.
- Collect the deposit via Stripe's PaymentSheet, test mode only, then
  confirm server-side (`POST /bookings/{token}/confirm-payment`).
- View a booking's live status via its signed manage token
  (`GET /bookings/manage/{token}`).
- Schedule a local, on-device reminder notification ahead of the
  appointment's start time.

## Deliberately out of scope

- **Any staff/admin functionality.** bookslot already has a Nuxt owner
  dashboard for that (Session 17/20). This app is a pure customer client
  and never authenticates as owner/staff/platform_admin.
- **Real push notifications.** bookslot's backend already runs a real,
  RabbitMQ-backed reminder pipeline server-side (Session 19). Standing up a
  second, parallel push channel (APNs/FCM credentials, a device-token
  registration endpoint bookslot doesn't have) would duplicate that
  infrastructure for a portfolio demo with no real users to reach. Local
  scheduling is the deliberate, permanent choice unless a future session
  finds a concrete reason real push adds demo value beyond this — see
  `05-backlog.md`.
- **Real Stripe network behavior.** Same permanent scope boundary bookslot
  itself drew (D-0036 in bookslot's own decision log): test-mode Stripe
  only, never a live publishable/secret key, for the lifetime of this
  portfolio project.
- **Customer accounts / login.** bookslot's public booking flow is
  deliberately unauthenticated (its own D-0009) — there is no customer
  account system to log into. "My bookings" in this app is therefore
  necessarily per-device (see `02-architecture.md`), not per-account.

## Known, named limitation: no self-service cancellation

bookslot's public API has no customer-initiated cancel endpoint — only an
owner-authenticated `POST /owner/appointments/{id}/cancel` exists (added
bookslot Session 20). This app's "My bookings" screen surfaces a Cancel
action, but it explains this limitation rather than faking a working
cancel call against an endpoint that doesn't exist for customers. This is a
real backend gap, not an oversight in this app — see `05-backlog.md` for
what closing it would require on bookslot's side.
