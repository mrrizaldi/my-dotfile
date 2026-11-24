#!/usr/bin/env bash
# Preview the Matrix lockscreen safely: hyprlock runs inside a throw-away nested
# Hyprland window (made fullscreen so it really renders), never locks your session.
# Closes after N seconds and reports frames hyprlock refused (= real dropped frames).
#   preview.sh [seconds=20]
secs=${1:-20}
cfg=$(mktemp --suffix=.lua); log=$(mktemp)
echo 'hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true } })' > "$cfg"
before=$(hyprctl instances -j | jq -r '.[].instance')
env -u AQ_DRM_DEVICES Hyprland -c "$cfg" >/dev/null 2>&1 &
pid=$!
for _ in $(seq 50); do
  sig=$(hyprctl instances -j | jq -r '.[].instance' | grep -vxF "$before" | head -1)
  [ -n "$sig" ] && break
  sleep 0.2
done
sock=$(hyprctl instances -j | jq -r --arg s "$sig" '.[] | select(.instance==$s) | .wl_socket')
sleep 0.5
# hidden windows get no frame callbacks -> hyprlock animations stall; keep it on top
hyprctl dispatch "hl.dsp.window.fullscreen({ window = 'pid:$pid', mode = 'fullscreen' })" >/dev/null
rm -f "$XDG_RUNTIME_DIR"/hyprlock-matrix-rain "$XDG_RUNTIME_DIR"/hyprlock-matrix-hud
WAYLAND_DISPLAY=$sock HYPRLAND_INSTANCE_SIGNATURE=$sig hyprlock -c "$HOME/.config/hypr/hyprlock-matrix.conf" >"$log" 2>&1 &
lockpid=$!
sleep "$secs"
kill "$lockpid" 2>/dev/null; sleep 0.3   # hyprlock first: killing its compositor under it = abort + core dump
kill "$pid" 2>/dev/null
echo "frames shown: $(cut -d' ' -f1 "$XDG_RUNTIME_DIR/hyprlock-matrix-rain" 2>/dev/null)+1, refused: $(grep -c 'Refusing to load' "$log"), clock skips: $(grep -c 'Skipping update' "$log")"
rm -f "$cfg" "$log" "$XDG_RUNTIME_DIR"/hyprlock-matrix-rain "$XDG_RUNTIME_DIR"/hyprlock-matrix-hud
