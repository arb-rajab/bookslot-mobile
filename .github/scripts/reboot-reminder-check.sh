#!/usr/bin/env bash
# Does a scheduled reminder survive a reboot? On-device check, run on the
# emulator by android-native.yml after the integration tests.
#
# 1. Install the probe APK built from integration_test/reboot_probe_main.dart
#    (a clean install) and launch it once. It schedules a reminder through the
#    real ReminderScheduler, due in 5 minutes. allow-permission-dialogs.sh
#    answers the POST_NOTIFICATIONS prompt.
# 2. Check that AlarmManager holds an alarm for the app. This proves the
#    check below can see one.
# 3. `adb reboot`, then wait for a new boot to complete.
# 4. Without reopening the app, poll AlarmManager and the notification
#    shade until the reminder is shown or the deadline passes. Print when the
#    alarm came back and how far from the scheduled time the reminder
#    appeared.
#
# Passes only if the reminder is shown after the reboot. Notifications don't
# survive a reboot themselves, so a reminder in the shade then was posted
# after boot, from a re-armed alarm.
set -euo pipefail

APK=${1:?usage: reboot-reminder-check.sh <probe apk>}
PKG=com.bookslot.bookslot_mobile
TITLE='Upcoming appointment'
# How long after the scheduled time to keep waiting. The alarm is inexact,
# so Android may deliver it late; this is generous for an awake emulator.
GRACE_S=480

log() { echo "reboot-check: $*"; }
summary() {
  log "$*"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "- $*" >>"$GITHUB_STEP_SUMMARY"; fi
}
# Device clock, the one the probe's due time is on. Host clock if adb blips.
device_now() {
  local t
  t=$(adb shell date +%s 2>/dev/null | tr -d '\r' || true)
  echo "${t:-$(date +%s)}"
}
boot_id() { adb shell cat /proc/sys/kernel/random/boot_id 2>/dev/null | tr -d '\r'; }
# Pending AlarmManager entries owned by the app.
app_alarms() { adb shell dumpsys alarm 2>/dev/null | tr -d '\r' | grep -A6 "Alarm{.*$PKG" || true; }
# Whether the app's reminder is in the notification shade. Captured first
# rather than piped into `grep -q`, whose early exit would fail the pipe
# under pipefail.
reminder_shown() {
  local records
  records=$(adb shell dumpsys notification --noredact 2>/dev/null | tr -d '\r' \
    | grep -A40 "NotificationRecord(.*pkg=$PKG" || true)
  grep -qF "android.title=String ($TITLE)" <<<"$records"
}
diagnostics() {
  echo "::group::Reboot check diagnostics"
  log "app alarms now:"; app_alarms
  log "every dumpsys alarm line naming the app:"
  adb shell dumpsys alarm 2>/dev/null | tr -d '\r' | grep -n "$PKG" | head -40 || true
  log "app notifications now:"
  adb shell dumpsys notification --noredact 2>/dev/null | tr -d '\r' | grep -A12 "NotificationRecord(.*pkg=$PKG" || true
  log "logcat since boot (filtered):"
  adb logcat -d -v time 2>/dev/null \
    | grep -iE 'bookslot|flutter|dexterous|BOOT_COMPLETED|AndroidRuntime|FATAL' | tail -150 || true
  echo "::endgroup::"
}
fail() {
  summary "FAIL: $*"
  diagnostics
  exit 1
}

adb shell svc power stayon true || true
adb shell wm dismiss-keyguard || true

# --- 1. Schedule through the app -------------------------------------------
adb uninstall "$PKG" >/dev/null 2>&1 || true
adb install -r "$APK"
adb logcat -c

"$(dirname "$0")/allow-permission-dialogs.sh" &
helper=$!
trap 'kill "$helper" 2>/dev/null || true' EXIT

adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null \
  || fail "could not launch the probe app"
line=""
for _ in $(seq 1 120); do
  line=$(adb logcat -d -s flutter 2>/dev/null | tr -d '\r' | grep -m1 -E 'REBOOT_PROBE (scheduled|error)' || true)
  [ -n "$line" ] && break
  sleep 1
done
kill "$helper" 2>/dev/null || true
log "probe said: ${line:-<nothing within 120 s>}"
case "$line" in
  *'REBOOT_PROBE scheduled fireAtMs='*) ;;
  *) fail "the probe app did not report a scheduled reminder" ;;
esac
fire_at=$((${line##*fireAtMs=} / 1000))

# Leave the app in the background, as a customer would. Don't force-stop it:
# that cancels its alarms and blocks BOOT_COMPLETED until the next launch.
adb shell input keyevent KEYCODE_HOME
sleep 5

# --- 2. Before the reboot ---------------------------------------------------
before=$(app_alarms)
log "app alarms before reboot:"; echo "$before"
[ -n "$before" ] || fail "no alarm for $PKG in AlarmManager before the reboot, so this check can't tell anything"
if reminder_shown; then fail "the reminder was already shown before the reboot"; fi
now=$(device_now)
log "reminder due at $(date -u -d "@$fire_at" +%T) UTC, $((fire_at - now)) s from now; rebooting"

# --- 3. Reboot --------------------------------------------------------------
old_boot=$(boot_id)
reboot_at=$(date +%s)
adb reboot
booted=""
for _ in $(seq 1 100); do
  sleep 3
  adb wait-for-device >/dev/null 2>&1 || true
  if [ "$(boot_id)" != "$old_boot" ] \
    && [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; then
    booted=1
    break
  fi
done
[ -n "$booted" ] || fail "the emulator did not finish rebooting within 5 minutes"
now=$(device_now)
summary "emulator rebooted in $(($(date +%s) - reboot_at)) s; reminder due $((fire_at - now)) s after boot completed"
adb shell svc power stayon true || true

# --- 4. After the reboot, without opening the app ---------------------------
deadline=$((fire_at + GRACE_S))
alarm_seen=""
shown_at=""
while [ "$(device_now)" -le "$deadline" ]; do
  if [ -z "$alarm_seen" ] && [ -n "$(app_alarms)" ]; then
    alarm_seen=$(device_now)
    log "app alarm back in AlarmManager at $(date -u -d "@$alarm_seen" +%T) UTC:"
    app_alarms
  fi
  if reminder_shown; then
    shown_at=$(device_now)
    break
  fi
  sleep 2
done

if [ -n "$alarm_seen" ]; then
  summary "after reboot: app alarm re-registered $((fire_at - alarm_seen)) s before it was due"
else
  summary "after reboot: no pending app alarm seen by polling"
fi
[ -n "$shown_at" ] || fail "no reminder shown after the reboot, $GRACE_S s past its scheduled time"
summary "PASS: reminder shown after reboot, $((shown_at - fire_at)) s after its scheduled time (±2 s polling; negative is early)"
