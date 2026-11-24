#!/bin/sh
# Lock with the Quickshell Matrix lockscreen (~/.config/quickshell/matrix-lock).
# - flock: one locker at a time (hypridle can call lock_cmd again while locked)
# - writes the lock start time (idle-suspend.sh) and the qs pid (lock-watchdog.sh)
# - after a LONG sleep the running qs stops drawing (seen at 3 h and 6 h; short
#   sleeps are fine) while a freshly started locker renders fine. So when the
#   watchdog kills it (SIGTERM -> rc 143) start a fresh qs once; if that fails too,
#   or qs is missing/crashes, hand over to hyprlock. Hyprland lets a new locker
#   take over (misc:allow_session_lock_restore = true).
run="${XDG_RUNTIME_DIR:-/tmp}"
lockfile="$run/matrix-lock.flock"

if command -v qs >/dev/null 2>&1 && [ -f "$HOME/.config/quickshell/matrix-lock/shell.qml" ]; then
	# keep the lock's log on disk (runtime logs in /run vanish on a forced power-off)
	logdir="${XDG_CACHE_HOME:-$HOME/.cache}/matrix-lock"
	mkdir -p "$logdir"
	attempt=0
	while :; do
		attempt=$((attempt + 1))
		flock -n -E 75 "$lockfile" sh -c '
			[ -f "$3/last.log" ] && mv -f "$3/last.log" "$3/prev.log"
			echo $$ > "$2"; [ -s "$1" ] || date +%s > "$1"   # keep the original lock time on restart
			{ date "+lock start %F %T"; exec qs -c matrix-lock; } > "$3/last.log" 2>&1' \
			sh "$run/matrix-lock.since" "$run/matrix-lock.pid" "$logdir"
		rc=$?
		[ "$rc" -eq 75 ] && exit 0    # already locked by a running instance
		rm -f "$run/matrix-lock.pid" "$run/matrix-lock.heartbeat"
		if [ "$rc" -eq 143 ] && [ "$attempt" -lt 2 ]; then
			logger -t matrix-lock "restarting the quickshell lock (watchdog: stopped drawing)"
			continue
		fi
		rm -f "$run/matrix-lock.since"
		[ "$rc" -eq 0 ] && exit 0     # unlocked normally
		logger -t matrix-lock "quickshell lock exited with $rc (attempt $attempt), falling back to hyprlock"
		break
	done
fi

pidof hyprlock >/dev/null || exec hyprlock
