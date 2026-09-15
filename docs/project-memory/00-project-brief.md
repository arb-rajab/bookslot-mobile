# Project Brief

## What this is

`bookslot-mobile` is a Flutter customer-facing companion app for
[`bookslot`](https://github.com/arb-rajab/bookslot), a private Laravel
booking-and-deposits backend for appointment-based service businesses. This
repository is the **public** half of that pairing — a portfolio skill-demo
that consumes bookslot's real, production-shaped public booking API against
a seeded demo tenant, without exposing bookslot's actual business or tenant
data.

## Why a separate repo, and why public

`bookslot` itself stays private — it's a real commercial project. This app
demonstrates the same booking domain from the customer's side, built
against bookslot's actual API contracts rather than a mock, and is safe to
publish because it only ever talks to a fake, seeded "Demo Tattoo Studio"
tenant (`demo-studio`) that bookslot's own `DatabaseSeeder` creates for
exactly this purpose (see bookslot's `database/seeders/DatabaseSeeder.php`,
added Session 17/20).

## Who this is for

Two audiences: a portfolio reviewer evaluating Flutter/mobile skill against
a real backend contract, and (secondarily) an honest reference for what a
minimal customer booking client for bookslot's real API actually needs.

## Relationship to bookslot

This app is a pure HTTP client of bookslot's public, unauthenticated
customer-facing routes (`routes/api.php`'s `tenants/{slug}` group and the
signed-token `bookings/*` routes) as they existed as of bookslot Session 20
(2026-09-13). It never touches an owner/staff/admin endpoint, never holds
Laravel/Sanctum session credentials, and never talks to Stripe outside test
mode. See `02-architecture.md` for the exact endpoint list this app
depends on, and `03-testing-strategy.md`/`05-backlog.md` for what happens
if bookslot's API changes underneath it (there is no contract test yet —
a named, tracked gap).

## Illustrative vertical

Same as bookslot: appointment-based service businesses, illustrated with a
tattoo studio (the seeded demo tenant), per bookslot's own
`00-project-brief.md`.
