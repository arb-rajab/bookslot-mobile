#!/usr/bin/env bash
# Runs integration_test/ on the booted emulator, with
# allow-permission-dialogs.sh answering any runtime-permission prompt the
# app raises. One script rather than inline workflow lines, because
# android-emulator-runner runs each `script:` line as its own shell, so a
# background helper can't outlive its line there.
#
# A hung run fails after 15 minutes (a normal one takes ~3) and prints the
# focused window plus filtered logcat, instead of sitting until the job's
# 60-minute timeout with nothing to diagnose.
set -euo pipefail

# A locked or sleeping screen would keep permission prompts from showing.
adb shell svc power stayon true || true
adb shell wm dismiss-keyguard || true

"$(dirname "$0")/allow-permission-dialogs.sh" &
helper=$!
trap 'kill "$helper" 2>/dev/null || true' EXIT

status=0
timeout 15m flutter test integration_test -d emulator-5554 --reporter expanded || status=$?

if [ "$status" -ne 0 ]; then
  echo "::group::Emulator diagnostics (flutter test exit $status; 124 = timed out)"
  adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' || true
  adb logcat -d -v time \
    | grep -iE 'bookslot|flutter|permissioncontroller|AndroidRuntime|FATAL|ActivityTaskManager: (START|Displayed)|dexterous' \
    | tail -200 || true
  echo "::endgroup::"
fi
exit "$status"
