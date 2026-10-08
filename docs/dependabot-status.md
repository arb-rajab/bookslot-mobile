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

## Time-limited exemptions

- None.

## Notes

- There is no dedicated group for the Kotlin Gradle plugins; they are covered only by `minor-and-patch`. This is a known, deliberately deferred item.
- The native Android build runs only in `.github/workflows/android-native.yml` (pull_request or manual dispatch), not on push to main; dispatch it manually to verify native-side bumps.

## Deferred (not re-raised each pass)

- Ignored major versions are listed in `.github/dependabot.yml` with the reason for each.
- Re-check exemptions before their `effectiveUntil` date (2026-11-15) and drop them once upstream fixes ship.
