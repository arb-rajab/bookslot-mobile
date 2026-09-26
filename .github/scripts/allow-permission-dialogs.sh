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
# uiautomator off the screen the rest of the time. Logs every change of
# focused window, so a missed prompt can be diagnosed from the CI log.
# Runs until killed.
set -u

log() { echo "allow-permission-dialogs: $*"; }

last_focus=""
reported_no_button=""
while true; do
  focus=$(adb shell dumpsys window 2>/dev/null | grep -m1 mCurrentFocus | tr -d '\r' | sed 's/^ *//')
  if [ "$focus" != "$last_focus" ]; then
    log "focus: ${focus:-<none>}"
    last_focus=$focus
    reported_no_button=""
  fi
  case "$focus" in
    *GrantPermissionsActivity*)
      if adb shell uiautomator dump /sdcard/window.xml >/dev/null 2>&1; then
        xml=$(adb shell cat /sdcard/window.xml 2>/dev/null)
        # Match by resource id first; fall back to the button's text.
        node=$(printf '%s' "$xml" | grep -o '<node [^>]*permission_allow_button[^>]*>' | head -1)
        [ -n "$node" ] || node=$(printf '%s' "$xml" | grep -o '<node [^>]*text="Allow"[^>]*>' | head -1)
        bounds=$(printf '%s' "$node" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"')
        if [ -n "$bounds" ]; then
          read -r x1 y1 x2 y2 <<<"$(echo "$bounds" | grep -o '[0-9]\+' | tr '\n' ' ')"
          adb shell input tap $(((x1 + x2) / 2)) $(((y1 + y2) / 2))
          log "tapped Allow at $(((x1 + x2) / 2)),$(((y1 + y2) / 2))"
        elif [ -z "$reported_no_button" ]; then
          log "permission dialog focused but no Allow button in the UI dump"
          reported_no_button=1
        fi
      elif [ -z "$reported_no_button" ]; then
        log "permission dialog focused but uiautomator dump failed"
        reported_no_button=1
      fi
      ;;
  esac
  sleep 1
done
