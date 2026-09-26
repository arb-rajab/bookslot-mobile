#!/usr/bin/env bash
# Plays the user for Android runtime-permission prompts during
# integration_test: whenever the system's permission dialog has focus, tap
# its "Allow" button. integration_test can only drive Flutter widgets, not
# this platform-owned dialog, so without this a test that makes the app ask
# for a permission (e.g. POST_NOTIFICATIONS) would hang on the prompt.
#
# It never grants anything itself (no `pm grant`). A permission the app
# doesn't request stays denied, so tests still catch a missing request.
# Only looks at the UI while a GrantPermissionsActivity is focused, to keep
# uiautomator off the screen the rest of the time. Runs until killed.
set -u

while true; do
  if adb shell dumpsys window 2>/dev/null | grep mCurrentFocus | grep -q GrantPermissionsActivity; then
    adb shell uiautomator dump /sdcard/window.xml >/dev/null 2>&1
    bounds=$(adb shell cat /sdcard/window.xml 2>/dev/null \
      | grep -o 'resource-id="[a-z.]*permissioncontroller:id/permission_allow_button"[^>]*' \
      | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | head -1)
    if [ -n "$bounds" ]; then
      read -r x1 y1 x2 y2 <<<"$(echo "$bounds" | grep -o '[0-9]\+' | tr '\n' ' ')"
      adb shell input tap $(((x1 + x2) / 2)) $(((y1 + y2) / 2))
      echo "allow-permission-dialogs: tapped Allow at $(((x1 + x2) / 2)),$(((y1 + y2) / 2))"
    fi
  fi
  sleep 1
done
