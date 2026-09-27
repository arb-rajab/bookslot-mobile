#!/usr/bin/env bash
# How late does an inexact reminder actually arrive, at a scale closer to
# the real product's "2 hours before, booked days ahead" than the ~4 minute
# case D-11 happened to measure? Backlog #11. Run on the emulator by
# reminder-lateness-probe.yml (a separate, dispatch-only workflow: this is a
# one-off measurement, not a per-PR gate — a "jump" trial's real-time tail
# alone can take longer than this repo's normal PR checks should).
#
# Two modes, both scheduling through the real ReminderScheduler (real
# 2-hour lead time; only how-far-out the alarm is due varies):
#
#   real  - waits in real elapsed wall time for the reminder to fire. Only
#           practical for a due-time up to some tens of minutes out.
#   jump  - for a due time hours or days out (i.e. an appointment booked
#           that far ahead). Schedules the alarm normally, immediately
#           records AlarmManager's assigned window with the real remaining
#           time (no waiting needed for that reading), then uses `adb root`
#           + `adb shell date` to jump the device's wall clock forward to
#           shortly before the reminder is due, and waits out the rest in
#           real elapsed time. This is NOT equivalent to actually letting
#           that many real hours/days pass: it skips whatever Android would
#           have done with the device over that span (Doze/idle-standby
#           bucket transitions depend on real elapsed idle time, motion,
#           charging state, etc. — none of which happen during a clock
#           jump), and an abrupt system-clock change is itself an unusual
#           event AlarmManager doesn't see in normal operation. If the clock
#           jump doesn't take (no root, or `date` refused), the script
#           still reports the immediate post-schedule AlarmManager window
#           (a real, un-simulated data point) but does not claim a delivery
#           observation for that trial.
#
# Repeats internally (a TRIALS count), rather than the workflow looping over
# separate lines: android-emulator-runner's `script:` input runs each line
# as its own separate shell, so a multi-line `for`/`do`/`done` there breaks
# (see run-integration-tests.sh's own header for the same reason a
# background helper can't outlive its line). A loop inside this one script
# file is a single shell process throughout, so it's fine here.
set -uo pipefail

APK=${1:?usage: reminder-lateness-check.sh <probe apk> <real|jump> <trials> [jump_leeway_seconds]}
MODE=${2:?usage: reminder-lateness-check.sh <probe apk> <real|jump> <trials> [jump_leeway_seconds]}
TRIALS=${3:?usage: reminder-lateness-check.sh <probe apk> <real|jump> <trials> [jump_leeway_seconds]}
JUMP_LEEWAY_S=${4:-600}
PKG=com.bookslot.bookslot_mobile
TITLE='Upcoming appointment'
# 480s (the reboot check's own grace) turned out too short here: at a ~15
# minute due-time scale the AlarmManager window itself is ~11 minutes (see
# backlog #11), so maxWhenElapsed can land well past due+480s. 1800s covers
# that comfortably without costing much extra when delivery is on time.
GRACE_S=1800

log() { echo "lateness-check[$MODE #$trial]: $*"; }
summary() {
  log "$*"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "- ($MODE #$trial) $*" >>"$GITHUB_STEP_SUMMARY"; fi
}
device_now() {
  local t
  t=$(adb shell date +%s 2>/dev/null | tr -d '\r' || true)
  echo "${t:-$(date +%s)}"
}
app_alarms() { adb shell dumpsys alarm 2>/dev/null | tr -d '\r' | grep -A6 "Alarm{.*$PKG" || true; }
reminder_shown() {
  local records
  records=$(adb shell dumpsys notification --noredact 2>/dev/null | tr -d '\r' \
    | grep -A40 "NotificationRecord(.*pkg=$PKG" || true)
  grep -qF "android.title=String ($TITLE)" <<<"$records"
}
diagnostics() {
  echo "::group::Lateness check diagnostics ($MODE #$trial)"
  log "app alarms now:"; app_alarms
  log "app notifications now:"
  adb shell dumpsys notification --noredact 2>/dev/null | tr -d '\r' | grep -A12 "NotificationRecord(.*pkg=$PKG" || true
  echo "::endgroup::"
}

run_trial() {
  local helper line fire_at_ms fire_at before_epoch t0 t1 root_ok target set_str now_after
  local deadline alarm_seen shown_at lateness pct interval

  adb shell svc power stayon true || true
  adb shell wm dismiss-keyguard || true

  adb uninstall "$PKG" >/dev/null 2>&1 || true
  adb install -r "$APK" || { summary "FAIL: could not install $APK"; return 1; }
  adb logcat -c

  "$(dirname "$0")/allow-permission-dialogs.sh" &
  helper=$!
  trap 'kill "$helper" 2>/dev/null || true' RETURN

  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null \
    || { summary "FAIL: could not launch the probe app"; return 1; }
  line=""
  for _ in $(seq 1 120); do
    line=$(adb logcat -d -s flutter 2>/dev/null | tr -d '\r' | grep -m1 -E 'LATENESS_PROBE (scheduled|error)' || true)
    [ -n "$line" ] && break
    sleep 1
  done
  kill "$helper" 2>/dev/null || true
  log "probe said: ${line:-<nothing within 120 s>}"
  case "$line" in
    *'LATENESS_PROBE scheduled fireAtMs='*) ;;
    *) summary "FAIL: the probe app did not report a scheduled reminder"; diagnostics; return 1 ;;
  esac
  fire_at_ms=$(echo "$line" | grep -oE 'fireAtMs=[0-9]+' | cut -d= -f2)
  fire_at=$((fire_at_ms / 1000))

  adb shell input keyevent KEYCODE_HOME
  sleep 5

  before_epoch=$(device_now)
  summary "scheduled: due at $(date -u -d "@$fire_at" +'%Y-%m-%dT%H:%M:%SZ'), $((fire_at - before_epoch)) s from now"
  t0=$(app_alarms)
  if [ -z "$t0" ]; then
    summary "FAIL: no alarm for $PKG in AlarmManager right after scheduling"
    diagnostics
    return 1
  fi
  summary "AlarmManager entry immediately after scheduling (real, unsimulated reading):"
  log "$t0"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    { echo '  ```'; echo "$t0"; echo '  ```'; } >>"$GITHUB_STEP_SUMMARY"
  fi

  if [ "$MODE" = jump ]; then
    root_ok=""
    if adb root >/tmp/adb_root.log 2>&1; then
      sleep 2
      adb wait-for-device >/dev/null 2>&1 || true
      root_ok=1
    fi
    if [ -z "$root_ok" ] || grep -qi "cannot run as root" /tmp/adb_root.log 2>/dev/null; then
      summary "clock jump not available (adb root refused: $(cat /tmp/adb_root.log 2>/dev/null || true)); no delivery observation for this trial, only the AlarmManager reading above"
      return 0
    fi
    target=$((fire_at - JUMP_LEEWAY_S))
    set_str=$(date -u -d "@$target" +%m%d%H%M%Y.%S)
    adb shell date -u "$set_str" >/tmp/adb_date.log 2>&1 || true
    sleep 2
    now_after=$(device_now)
    if [ $((now_after - target)) -gt 30 ] || [ $((now_after - target)) -lt -30 ]; then
      summary "clock jump did not take (wanted @$target, device now reports @$now_after: $(cat /tmp/adb_date.log 2>/dev/null || true)); no delivery observation for this trial, only the AlarmManager reading above"
      return 0
    fi
    summary "device clock jumped forward from @$before_epoch to @$now_after ($(( (now_after - before_epoch) / 3600 ))h skipped), leaving ${JUMP_LEEWAY_S}s of real elapsed time before the reminder is due"
    t1=$(app_alarms)
    summary "AlarmManager entry right after the clock jump (recalculated, not a fresh schedule):"
    log "$t1"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
      { echo '  ```'; echo "${t1:-<no alarm entry found after the jump>}"; echo '  ```'; } >>"$GITHUB_STEP_SUMMARY"
    fi
  fi

  # --- Wait in real elapsed time for the rest -------------------------------
  deadline=$((fire_at + GRACE_S))
  alarm_seen=""
  shown_at=""
  while [ "$(device_now)" -le "$deadline" ]; do
    if [ -z "$alarm_seen" ] && [ -n "$(app_alarms)" ]; then
      alarm_seen=$(device_now)
    fi
    if reminder_shown; then
      shown_at=$(device_now)
      break
    fi
    sleep 2
  done

  if [ -z "$shown_at" ]; then
    summary "FAIL: no reminder shown, $GRACE_S s past its scheduled time (real elapsed wait from here on)"
    diagnostics
    return 1
  fi
  lateness=$((shown_at - fire_at))
  pct=""
  if [ "$MODE" = real ]; then
    interval=$((fire_at - before_epoch))
    if [ "$interval" -gt 0 ]; then
      pct=$(awk -v l="$lateness" -v i="$interval" 'BEGIN{printf "%.1f", (l/i)*100}')
    fi
  fi
  summary "PASS: reminder shown $lateness s after its scheduled time (real elapsed wait${pct:+, ${pct}% of the ${interval}s scheduling-to-due interval}; +/-2 s polling; negative is early)"
  return 0
}

overall=0
for trial in $(seq 1 "$TRIALS"); do
  echo "::group::$MODE trial $trial/$TRIALS"
  if ! run_trial; then overall=1; fi
  echo "::endgroup::"
done
exit "$overall"
