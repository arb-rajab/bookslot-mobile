# Dependabot status

_Last updated: 2026-10-09. Maintained during the Dependabot clean-up pass; update when the state changes._

## Configuration

- Ecosystems covered: pub (`/`), gradle (`/android`), github-actions (`/`).
- Grouping: `minor-and-patch` for every ecosystem (open-PR limit 5 each).
- Schedule: weekly.
- Ignore rules: none.

## State at last update

- Open Dependabot PRs: 0 (each merged or closed only after reading its checks).
- Default-branch CI: green at last check. `android-native.yml` dispatched on `main` 2026-10-09 (run 37929614397) passed; the previous `main` run had failed on a corrupt NDK download before the emulator started.
- Last full rescan: 2026-10-09. Checked open PRs (none), default-branch and scheduled CI, Dependabot update jobs, ecosystem coverage (no new manifests since 2026-10-08), Actions pins, exemption expiry dates and stray branches, plus three new dimensions: branch-protection required contexts against the check runs a PR actually produces, the repo's `security_and_analysis` settings, and check-run annotations on `main`. No required context is stale. The annotations showed `ubuntu-latest` moving to Ubuntu 26 from 2026-10-19, so every job is now pinned to `ubuntu-24.04` (see Notes). The full-history gitleaks scan was not repeated: the only commits since 2026-10-08 are docs and CI changes, each scanned by the push-run gitleaks job. Rescan cycle 2 (same day, after those pins merged) repeated every dimension and added one: each repo's `SECURITY.md` and whether GitHub private vulnerability reporting is enabled.

## Time-limited exemptions

- None.

## Notes

- There is no dedicated group for the Kotlin Gradle plugins; they are covered only by `minor-and-patch`. This is a known, deliberately deferred item.
- The native Android build runs only in `.github/workflows/android-native.yml` (pull_request or manual dispatch), not on push to main; dispatch it manually to verify native-side bumps.
- `.gitleaksignore` (added 2026-10-08 in #29): one fingerprint, the fake Stripe client secret `pi_123_secret_456` in `test/widget/deposit_payment_screen_test.dart` (commit 0ee3433a). The scheduled Security run scans full history and failed on it (run 37308814491); push runs only scan new commits, so they stay green.
- Every workflow declares a top-level `permissions: contents: read` (added 2026-10-08, rescan cycle 3; `android-native.yml` later the same day). Jobs that need more, such as CodeQL's `security-events: write`, declare it at job level.
- The `android-native.yml` emulator hang recurred on 2026-10-08: twice on PR #31's runs, while a dispatch on `main` passed. Evidence is in `docs/project-memory/06-session-handoff.md`. Root cause not established, but the block is not it: a dispatch with only the block passed (run 37847762509), and the same hang hit runs without it (2026-09-26 and 2026-10-05). The block was added.
- Merge policy (deliberate choice by the repo owner, 2026-10-08): every PR, major-version dependency bumps included, is merged as soon as all of its required checks are green, confirmed per PR. This repo is a code showcase with no business or sensitive dependency, so green checks are the only gate. Red, pending or conflicted PRs are fixed or closed instead.
- Every Linux job runs on `ubuntu-24.04` (pinned 2026-10-09; it is what `ubuntu-latest` resolved to). GitHub moves `ubuntu-latest` to Ubuntu 26 from 2026-10-19, and an unattended image change could turn every check red at once. Move to `ubuntu-26.04` deliberately, in one PR whose CI has run on it. Dependabot does not bump `runs-on` labels.
- Two stale branches, `ccr-b3cdff3e-r2o28v` and `claude/standing-loop-maintenance-jya4eb` (2026-10-08), carry only the `android-native.yml` permissions change that #32 merged. Deleting them was refused in the 2026-10-09 session, so they are left for the owner.
- `SECURITY.md` added 2026-10-09 (rescan cycle 2: the repo had no security policy). It sends reporters to GitHub private vulnerability reporting, which is disabled here. Enabling it needs the Administration permission on the owner's token; escalation requested 2026-10-09.

## Deferred (not re-raised each pass)

- Ignored major versions are listed in `.github/dependabot.yml` with the reason for each.
- Re-check exemptions before their `effectiveUntil` date (2026-11-15) and drop them once upstream fixes ship.
- Alerts read 2026-10-09 with the repo owner's PAT, run on their machine (Claude sessions still get 403: the proxy sends a GitHub App token instead of `GH_ALERTS_TOKEN`, even a PAT passed explicitly). No open Dependabot or code-scanning alerts.
