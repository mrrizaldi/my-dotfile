#!/usr/bin/env bash
# SUPER+W: pick a Wallpaper Engine wallpaper for the focused monitor.
# First entry falls back to the old static picker (swww).
D="$HOME/.local/share/wallpaperengine"
WS="$HOME/.steam/debian-installation/steamapps/workshop/content/431960"
rofi_theme="$HOME/.config/hypr/rofi/config-wallpaper.rasi"
thumbs="$HOME/.cache/livewall-thumbs"
mkdir -p "$thumbs"

pidof rofi >/dev/null && pkill rofi
mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

# Pull newly subscribed workshop items in as hardlinks (no extra disk space,
# survive Steam unsubscribing). Skip web wallpapers and IDs in ignore.txt.
for src in "$WS"/*/; do
  id=$(basename "$src")
  [[ -d "$D/wallpapers/$id" ]] && continue
  grep -qx "$id" "$D/ignore.txt" 2>/dev/null && continue
  [[ $(jq -r '.type // "" | ascii_downcase' "$src/project.json" 2>/dev/null) == web ]] && continue
  cp -al "$src" "$D/wallpapers/$id"
done

menu() {
  printf '%s\0icon\x1f%s\n' "🖼  Static image (swww) / matikan live" "$HOME/.config/swaync/images/ja.png"
  for dir in "$D"/wallpapers/*/; do
    id=$(basename "$dir")
    title=$(jq -r '.title // "?"' "$dir/project.json")
    preview="$dir/$(jq -r '.preview // "preview.jpg"' "$dir/project.json")"
    # low-res cached thumb: first frame for gifs, regenerated if preview changes
    thumb="$thumbs/$id.jpg"
    [[ "$thumb" -nt "$preview" ]] || magick "${preview}[0]" -thumbnail 320x320 "$thumb" 2>/dev/null
    printf '%s\0icon\x1f%s\n' "$title" "$thumb"
  done
}
# same glob order as menu(); menu runs in a pipe subshell, so collect ids here
ids=()
for dir in "$D"/wallpapers/*/; do ids+=("$(basename "$dir")"); done

idx=$(menu | rofi -i -dmenu -format i -p "Live wallpaper: $mon" -config "$rofi_theme" \
  -theme-str 'element-icon{size:20%;}')
[[ -z "$idx" || "$idx" == -1 ]] && exit 0

if ((idx == 0)); then
  "$HOME/.config/hypr/UserScripts/LiveWallpaper.sh" "$mon" off
  exec "$HOME/.config/hypr/UserScripts/WallpaperSelect.sh"
fi
"$HOME/.config/hypr/UserScripts/LiveWallpaper.sh" "$mon" "${ids[idx - 1]}"
