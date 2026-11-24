#!/usr/bin/env bash
# Start linux-wallpaperengine from the per-monitor state file (one process, all screens).
# State: ~/.local/share/wallpaperengine/current  -> lines "MONITOR WALLPAPER_ID"
# Usage: LiveWallpaper.sh            (re)start from state
#        LiveWallpaper.sh MON ID     set MON to ID, then restart
#        LiveWallpaper.sh MON off    remove live wallpaper from MON, then restart
#        LiveWallpaper.sh toggle     pause (still frame on swww, battery) / resume
#        LiveWallpaper.sh hotplug    monitor added/removed: restart only if running (keeps pause)
LWE="$HOME/linux-wallpaperengine/build/output/linux-wallpaperengine"
D="$HOME/.local/share/wallpaperengine"
STATE="$D/current"
THUMBS="$HOME/.cache/livewall-thumbs"
# Full-res frame the engine saves ~3 s after start (--screenshot); used as the
# paused image. preview.jpg/gif is tiny (192-1080 px square) and looks blurry.
SHOT="$THUMBS/live-shot.jpg"
touch "$STATE"
# Hotplug events come in bursts and two engines at once = black screen: one run at a time.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/livewall.lock"
flock 9
if [[ "$1" == hotplug ]]; then
  pgrep -x linux-wallpaper >/dev/null || exit 0 # paused/off: leave it
  sleep 2 # let DisplayProfile finish placing the new monitor
  set --
fi
mkdir -p "$THUMBS"

if [[ -n "$2" ]]; then
  sed -i "/^$1 /d" "$STATE"
  [[ "$2" != off ]] && echo "$1 $2" >>"$STATE"
fi

# Put a still (first frame) of wallpaper ID on swww for MON. Used to cover the
# engine's load gap and as the paused image. A gif would keep animating under
# the engine, hence the first frame. Two engines at once = black screen, so the
# gap can't be hidden by overlapping them. swww img doesn't touch the rofi
# links, so wallust/static wallpaper stay as-is.
show_still() {
  local json="$D/wallpapers/$2/project.json" preview still
  [[ -f "$json" ]] || return
  preview="$D/wallpapers/$2/$(jq -r '.preview // "preview.jpg"' "$json")"
  still="$THUMBS/$2-bg.jpg"
  [[ "$still" -nt "$preview" ]] || magick "${preview}[0]" "$still" 2>/dev/null
  swww img -o "$1" --transition-type none "$still" </dev/null 2>/dev/null
}

if [[ "$1" == toggle ]]; then
  if pgrep -x linux-wallpaper >/dev/null; then
    if [[ -s "$SHOT" ]]; then
      # Screenshot = live monitors side by side, sorted by name (engine uses a
      # std::map), each at physical size, top-aligned. Cut each one out.
      # ponytail: rotated monitors not handled (width/height would swap)
      x=0
      while read -r mon w h; do
        magick "$SHOT" -crop "${w}x${h}+${x}+0" +repage "$THUMBS/paused-$mon.jpg" 2>/dev/null &&
          swww img -o "$mon" --transition-type none "$THUMBS/paused-$mon.jpg" </dev/null 2>/dev/null
        x=$((x + w))
      done < <(hyprctl monitors -j | jq -r --rawfile st "$STATE" '
        ($st | split("\n") | map(split(" ")[0])) as $live
        | .[] | select(.name as $n | $live | index($n)) | "\(.name) \(.width) \(.height)"' | LC_ALL=C sort)
    else
      while read -r mon id; do show_still "$mon" "$id"; done <"$STATE"
    fi
    pkill -x linux-wallpaper
    while pgrep -x linux-wallpaper >/dev/null; do sleep 0.1; done
    notify-send -e -u low "Live wallpaper paused" "Static image. SUPER ALT SHIFT W to resume."
    exit 0
  fi
  notify-send -e -u low "Live wallpaper resumed"
  set -- # fall through: restart from state
fi

[[ -n "$2" && "$2" != off ]] && show_still "$1" "$2"

pkill -x linux-wallpaper # comm name is truncated to 15 chars
while pgrep -x linux-wallpaper >/dev/null; do sleep 0.1; done

args=()
connected=$(hyprctl monitors -j | jq -r '.[].name')
while read -r mon id; do
  # skip monitors not plugged in now; user_startup.lua re-runs "hotplug" on monitor add/remove
  grep -qx "$mon" <<<"$connected" && [[ -d "$D/wallpapers/$id" ]] &&
    args+=(--screen-root "$mon" --bg "$D/wallpapers/$id" --scaling fill)
done <"$STATE"

((${#args[@]})) || exit 0
rm -f "$SHOT" # never pause onto a stale frame of the previous wallpaper
# --silent: wallpapers with BGM stay quiet; drop it to hear them
# --fullscreen-pause-only-active: default pauses while ANY window is fullscreen (any
# workspace); started paused = never renders a first frame = black layer over swww.
nohup "$LWE" --assets-dir "$D/assets" --silent --fps 30 --fullscreen-pause-only-active --screenshot "$SHOT" --screenshot-delay 90 \
  "${args[@]}" >/tmp/linux-wallpaperengine.log 2>&1 9>&- & # 9>&-: engine must not hold the lock
