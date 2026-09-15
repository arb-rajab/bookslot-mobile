# Working in this repo — quota-reduction notes for future agent sessions

Concrete things that cost real time/tokens building this repo the first
time (Session 1, 2026-09-15). Read this before doing the same work again.

## bookslot's `docs/project-memory/12-session-handoff.md` is huge (1650+
lines, ~62K tokens) — never `Read` it whole

Grep for `## Amendment (Session N` to find the section you actually need,
then `Read` with `offset`/`limit` around just that range. Reading the
whole file once already blew past a single tool call's page cap in this
session. If you need "what's the current real API surface," the answer is
usually in the *most recent* amendment section plus `routes/api.php` and
the relevant controller source directly — the amendment sections are more
reliable than the file's top "State of bookslot" summary block, which is
explicitly left stale on purpose (that file's own stated convention).

## The Flutter SDK is not preinstalled in a fresh container

This session installed it via `git clone --depth 1 -b stable
https://github.com/flutter/flutter.git /opt/flutter` and added it to
`PATH`. That clone + first `flutter pub get` (which downloads the Dart SDK
and the tool itself) takes a few minutes and a few hundred MB. If your
session's container is fresh, budget for this once up front rather than
discovering `flutter: command not found` mid-task. If it's a reused
container, check `which flutter` first — don't reclone.

## `flutter analyze`'s exit code fails CI on info-level lints too, not
just warnings/errors — don't leave any lint unresolved, even "just info"

Session 1 initially left an info-level `use_null_aware_elements` lint on
`lib/api/bookslot_api_client.dart`'s conditional `staff_id` map entry as
"harmless," reasoning that the suggested rewrite was actually wrong (see
below) — but `flutter analyze` still exits nonzero when *any* issue is
reported, severity be damned, which broke CI's first real run. The fix
that's actually in the code now is a targeted `// ignore:
use_null_aware_elements` comment on that line (with the reasoning moved to
the method's doc comment, since a multi-line comment directly before the
flagged line does NOT suppress it — the `// ignore:` comment must be the
line immediately above, nothing else). If you see this lint reappear
elsewhere: the suggested `?'staff_id': staffId` rewrite doesn't apply to a
conditionally-*included* map entry (only to a possibly-null *value*), and
produces a real type error (`String?` not assignable to `Map<String,
String>`'s value type) if tried — verified by trying it, don't re-attempt
it. Before considering `flutter analyze` "clean enough," check its actual
exit code (or just confirm the "No issues found!" line), not just skim
the issue list for severity.

## Verifying API request/response shapes: read bookslot's controller
source directly, not `05-api-contracts.md`

bookslot's own decision log records `05-api-contracts.md` as having known,
tracked staleness in places (e.g. an admin-endpoint wording gap, per its
own Session 5/6 amendments). The controller source
(`app/Http/Controllers/Api/*.php`) and `MandateRenderer.php` are what
actually execute, and are what this app's models/fixtures were built
against. Cross-check `05` for narrative context, but trust the PHP source
for exact field names and status codes.

## Test/analyze output is verbose — always `tail` it

`flutter pub get`, `flutter test`, and `flutter analyze` all print a
"Woah! You appear to be trying to run flutter as root" banner plus tool
chatter before anything useful. Pipe through `tail -N` rather than reading
raw; the useful signal is always at the end.

## `dart format` will reformat nearly every file you hand-write

This session hand-wrote ~20 files and every one needed reformatting (line
wrapping, mostly). Run `dart format lib test integration_test` once near
the end of a batch of edits rather than chasing format compliance file by
file — it's a single fast, safe, idempotent pass.

## Verifying a claim about bookslot's API needs the `bookslot` repo
actually attached to *this* session — it is not in scope by default

Session 2 needed to confirm a new bookslot endpoint (a cancel route) was
real before wiring this app to it. `arb-rajab/bookslot` was not in this
session's starting GitHub scope (only `bookslot-mobile` was) — use
`mcp__Claude_Code_Remote__list_repos` to confirm it's available, then
`add_repo` (owner `arb-rajab`, repo `bookslot`, `access: read` is enough
for verification-only work) and clone it per that tool's own returned
instructions, then `register_repo_root` so its CLAUDE.md loads. Don't
trust a task prompt's description of another repo's endpoint shape
(status codes, error strings, response fields) without doing this — this
session's prompt described the cancel contract close to, but not
byte-for-byte, what `ManageBookingController::cancel()` actually returns/
throws, and the prompt itself explicitly asked for this verification step,
not just described it as optional. Unlike bookslot-mobile's own docs, at
Session 2's clone bookslot's repo was small (~1MB) and `routes/api.php` +
the relevant controller were enough — no need to touch
`12-session-handoff.md` at all for a single-endpoint check like this one;
reserve that file (see the note above) for "what's bookslot's whole
current state" questions, not "does this one route exist and what does it
return."

## Widget/unit tests that exercise `ReminderScheduler` need a fake, not
the real `FlutterLocalNotificationsPlugin`

Calling through to a real `FlutterLocalNotificationsPlugin` (e.g.
`.cancel()`, `.zonedSchedule()`) inside a plain `flutter_test`
environment throws `LateInitializationError` — its platform channel is
never registered without a real platform binding
(`FlutterLocalNotificationsPlugin.initialize()` alone doesn't fix this in
a widget test; the test never even calls it). Existing widget tests before
Session 2 never actually triggered a `ReminderScheduler` call, so this
didn't surface until `MyBookingsScreen`'s cancel flow (which calls
`cancelForAppointment`) got a widget test. Fix: subclass
`ReminderScheduler` in the test file overriding the methods under test
with no-ops/trackers (see `_FakeReminderScheduler` in
`test/widget/my_bookings_screen_test.dart`) rather than constructing a
real `FlutterLocalNotificationsPlugin()` and hoping. `integration_test/`
running on a real device/emulator shouldn't hit this (real platform
channels are registered there) — but that's unverified, per this repo's
running "no emulator available" limitation.
