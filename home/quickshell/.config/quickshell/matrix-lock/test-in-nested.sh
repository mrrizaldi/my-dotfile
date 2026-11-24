#!/usr/bin/env bash
# Real lock + real PAM, but inside a throw-away nested Hyprland window, so a
# broken unlock can never trap your actual session. Type your password in the
# window: if it unlocks, quickshell exits and this prints PASS.
#   test-in-nested.sh [timeout_seconds=120]
# Log is kept at $XDG_RUNTIME_DIR/matrix-lock-test.log whatever happens.
limit=${1:-120}
log="$XDG_RUNTIME_DIR/matrix-lock-test.log"
cfg=$(mktemp --suffix=.lua)
echo 'hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true, allow_session_lock_restore = true } })' > "$cfg"

before=$(hyprctl instances -j | jq -r '.[].instance')
env -u AQ_DRM_DEVICES Hyprland -c "$cfg" >/dev/null 2>&1 &
hpid=$!
for _ in $(seq 50); do
	sig=$(hyprctl instances -j | jq -r '.[].instance' | grep -vxF "$before" | head -1)
	[ -n "$sig" ] && break
	sleep 0.2
done
sock=$(hyprctl instances -j | jq -r --arg s "$sig" '.[] | select(.instance==$s) | .wl_socket')
[ -n "$sock" ] || { echo "nested Hyprland did not start"; kill "$hpid" 2>/dev/null; exit 1; }
echo "nested Hyprland up ($sock)"

sleep 1
hyprctl dispatch "hl.dsp.window.fullscreen({ window = 'pid:$hpid', mode = 'fullscreen' })" >/dev/null
sleep 1   # let the nested output settle at full size before locking it
echo "locking nested session - rain + rings should appear within ~2 s"

WAYLAND_DISPLAY=$sock HYPRLAND_INSTANCE_SIGNATURE=$sig timeout "$limit" qs -c matrix-lock >"$log" 2>&1
rc=$?
kill "$hpid" 2>/dev/null
rm -f "$cfg"

case $rc in
	0)   echo "PASS: unlocked with your password (PAM works)";;
	124) echo "TIMEOUT: not unlocked within ${limit}s (log: $log)";;
	*)   echo "FAIL: quickshell exited with $rc (log: $log)";;
esac
