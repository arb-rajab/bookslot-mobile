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
