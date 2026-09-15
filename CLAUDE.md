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

## Don't fight `flutter analyze`'s `use_null_aware_elements` info lint on
`lib/api/bookslot_api_client.dart`'s conditional `staff_id` map entry

It's real but the suggested `?'staff_id': staffId` rewrite doesn't apply
here — that syntax is for a possibly-null *value* in a list, not a
conditionally-*included* map entry, and using it produces an actual type
error (`String?` not assignable to `Map<String, String>`'s value type).
This was verified by trying it. Leave the `if (staffId != null) 'staff_id':
staffId` form as-is; it's correct.

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
