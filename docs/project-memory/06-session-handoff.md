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
