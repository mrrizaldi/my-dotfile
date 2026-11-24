#!/bin/sh
# hyprlock reload_cmd: print the next frame of a sequence (rain|hud), one step per call.
# Frame count = number of PNGs in the folder (gen.py decides it).
# Every monitor's widget calls this each second; calls within 500 ms of the last step
# get the same frame, so a 2nd monitor doesn't double the step (big jumps again).
dir="$HOME/.config/hypr/hyprlock-matrix/$1"
state="${XDG_RUNTIME_DIR:-/tmp}/hyprlock-matrix-$1"
now=$(date +%s%3N)
read -r n last 2>/dev/null < "$state" || { n=-1; last=0; }
if [ $((now - last)) -ge 500 ]; then
  count=$(ls "$dir" | grep -c '\.png$')
  n=$(( (n + 1) % count ))
  echo "$n $now" > "$state"
fi
printf '%s/%02d.png\n' "$dir" "$n"
