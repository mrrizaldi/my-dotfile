#!/bin/sh
# hypridle on-timeout: suspend (like closing the lid), but only when the screen
# has already been locked for at least $1 seconds - never while you're just idle
# at the desktop.  DRY=1 prints the decision instead of suspending.
need=${1:-540}
run="${XDG_RUNTIME_DIR:-/tmp}"
since=""

if ! flock -n "$run/matrix-lock.flock" true 2>/dev/null; then
	since=$(cat "$run/matrix-lock.since" 2>/dev/null)          # Quickshell lock is held
elif pid=$(pidof -s hyprlock); then
	since=$(( $(date +%s) - $(ps -o etimes= -p "$pid") ))      # fallback locker
fi

if [ -z "$since" ]; then
	[ -n "$DRY" ] && echo "not locked -> stay awake"
	exit 0
fi

age=$(( $(date +%s) - since ))
if [ "$age" -ge "$need" ]; then
	[ -n "$DRY" ] && { echo "locked ${age}s >= ${need}s -> suspend"; exit 0; }
	systemctl suspend
else
	[ -n "$DRY" ] && echo "locked ${age}s < ${need}s -> wait"
fi
