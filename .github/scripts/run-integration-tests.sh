#!/usr/bin/env bash
# Runs integration_test/ on the booted emulator, with
# allow-permission-dialogs.sh answering any runtime-permission prompt the
# app raises. One script rather than inline workflow lines, because
# android-emulator-runner runs each `script:` line as its own shell, so a
# background helper can't outlive its line there.
set -euo pipefail

"$(dirname "$0")/allow-permission-dialogs.sh" &
helper=$!
trap 'kill "$helper" 2>/dev/null || true' EXIT

flutter test integration_test -d emulator-5554 --reporter expanded
