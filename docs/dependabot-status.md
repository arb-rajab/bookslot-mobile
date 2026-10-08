# Dependabot status

_Last updated: 2026-10-08. Maintained during the Dependabot clean-up pass; update when the state changes._

## Configuration

- Ecosystems covered: pub (`/`), gradle (`/android`), github-actions (`/`).
- Grouping: `minor-and-patch` for every ecosystem (open-PR limit 5 each).
- Schedule: weekly.
- Ignore rules: none.

## State at last update

- Open Dependabot PRs: 0 (each merged or closed only after reading its checks).
- Default-branch CI: green at last check.
- Last full rescan: 2026-10-08. Checked open PRs, default-branch and scheduled CI, Dependabot update jobs, ecosystem coverage against the manifests in the repo, Actions pins, exemption expiry dates, stray branches, and (new this pass) a local full-history gitleaks 8.28.0 scan. No new gaps. The scheduled Security run's two failures (2026-10-05) are covered by `.gitleaksignore`; the local scan is clean with it and finds exactly the ignored finding without it.

## Time-limited exemptions

- None.

## Notes

- There is no dedicated group for the Kotlin Gradle plugins; they are covered only by `minor-and-patch`. This is a known, deliberately deferred item.
- The native Android build runs only in `.github/workflows/android-native.yml` (pull_request or manual dispatch), not on push to main; dispatch it manually to verify native-side bumps.
- `.gitleaksignore` (added 2026-10-08 in #29): one fingerprint, the fake Stripe client secret `pi_123_secret_456` in `test/widget/deposit_payment_screen_test.dart` (commit 0ee3433a). The scheduled Security run scans full history and failed on it (run 37308814491); push runs only scan new commits, so they stay green.
- Every workflow declares a top-level `permissions: contents: read` (added 2026-10-08, rescan cycle 3). Jobs that need more, such as CodeQL's `security-events: write`, declare it at job level.
- The intermittent `android-native.yml` emulator hang recurred on 2026-10-08 (PR #31); evidence is in `docs/project-memory/06-session-handoff.md`. Root cause not established.
- Merge policy (deliberate choice by the repo owner, 2026-10-08): every PR, major-version dependency bumps included, is merged as soon as all of its required checks are green, confirmed per PR. This repo is a code showcase with no business or sensitive dependency, so green checks are the only gate. Red, pending or conflicted PRs are fixed or closed instead.

## Deferred (not re-raised each pass)

- Ignored major versions are listed in `.github/dependabot.yml` with the reason for each.
- Re-check exemptions before their `effectiveUntil` date (2026-11-15) and drop them once upstream fixes ship.
