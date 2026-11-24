#!/bin/bash
# Emergency unlock path for the Quickshell Matrix lockscreen.
# If the lockscreen ever hangs or won't accept your password:
#   1. Ctrl+Alt+F3, log in on the text console (NOT the power button: logs live in RAM)
#   2. run: ~/.config/hypr/UserScripts/lock-rescue.sh
#   3. go back with Ctrl+Alt+F1 and unlock in hyprlock
# It first saves the lock/compositor logs to ~/lock-debug-<time>/ for diagnosis.
# Works because misc:allow_session_lock_restore = true lets a new locker take over.
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
inst=$(hyprctl instances -j | jq -r 'sort_by(.time) | .[0]')
export HYPRLAND_INSTANCE_SIGNATURE=$(jq -r .instance <<<"$inst")
export WAYLAND_DISPLAY=$(jq -r .wl_socket <<<"$inst")
[ -n "$WAYLAND_DISPLAY" ] && [ "$WAYLAND_DISPLAY" != null ] || { echo "no running Hyprland found"; exit 1; }

dbg="$HOME/lock-debug-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$dbg"
cp "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log" "$dbg/" 2>/dev/null
for d in "$XDG_RUNTIME_DIR"/quickshell/by-id/*/; do
	[ -f "$d/log.qslog" ] && qs log "$d/log.qslog" > "$dbg/qs-$(basename "$d").log" 2>&1
done
cp "$XDG_RUNTIME_DIR"/matrix-lock.* "$dbg/" 2>/dev/null
hyprctl monitors > "$dbg/monitors.txt" 2>&1
journalctl -b --no-pager -q --since '-30min' > "$dbg/journal.txt" 2>&1
echo "logs saved to $dbg"

pkill -x qs; pkill -x quickshell
sleep 1
echo "starting hyprlock on $WAYLAND_DISPLAY - switch back (Ctrl+Alt+F1) and unlock there"
nohup hyprlock >/dev/null 2>&1 &
