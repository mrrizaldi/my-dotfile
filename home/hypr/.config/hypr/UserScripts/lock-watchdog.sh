#!/bin/sh
# Run by hypridle's after_sleep_cmd. A few seconds after resume, check that the
# Quickshell lock is still drawing frames (heartbeat written by the lock itself).
# If not, kill it: matrix-lock.sh starts a fresh qs (which renders fine after a
# long sleep), and this checks that one too; a second failure -> hyprlock.
#   lock-watchdog.sh [delay_s=8] [max_stale_s=6]     DRY=1: only report
run="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
delay=${1:-8}
max=${2:-6}

for round in 1 2; do
	sleep "$delay"
	pid=$(cat "$run/matrix-lock.pid" 2>/dev/null) || exit 0     # not locked by quickshell (anymore)
	kill -0 "$pid" 2>/dev/null || exit 0

	last=$(cat "$run/matrix-lock.heartbeat" 2>/dev/null)
	last=${last:-0}
	age=$(( ($(date +%s%3N) - last) / 1000 ))

	if [ "$age" -le "$max" ]; then
		[ -n "$DRY" ] && echo "ok: last frame ${age}s ago"
		exit 0
	fi
	msg="round $round: no frame for ${age}s after resume, restarting the lock"
	[ -n "$DRY" ] && { echo "would act: $msg"; exit 0; }
	logger -t matrix-lock "watchdog: $msg"
	kill "$pid"
	delay=6   # give the fresh instance time to draw its first frames
done
