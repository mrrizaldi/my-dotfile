#!/usr/bin/env bash
# Add a local video (mp4/webm/mkv) as a live wallpaper, then pick it with SUPER+W.
# Usage: AddLiveWallpaper.sh FILE [TITLE]
# Creates ~/.local/share/wallpaperengine/wallpapers/local-<hash>/ with the
# minimal project.json linux-wallpaperengine needs (type, title, file) + preview.
set -e
[[ -f "$1" ]] || { echo "usage: ${0##*/} FILE [TITLE]" >&2; exit 1; }
src=$(realpath "$1")
title=${2:-$(basename "${src%.*}")}
dir="$HOME/.local/share/wallpaperengine/wallpapers/local-$(sha1sum "$src" | cut -c1-10)"
file=$(basename "$src")

mkdir -p "$dir"
# hardlink = no extra disk space and survives deleting the original; copy if other filesystem
cp -l "$src" "$dir/" 2>/dev/null || cp "$src" "$dir/"
ffmpeg -v error -y -ss 1 -i "$src" -frames:v 1 -vf scale=640:-2 "$dir/preview.jpg" ||
  ffmpeg -v error -y -i "$src" -frames:v 1 -vf scale=640:-2 "$dir/preview.jpg" # video < 1 s
jq -n --arg t "$title" --arg f "$file" \
  '{type: "video", title: $t, file: $f, preview: "preview.jpg"}' >"$dir/project.json"
echo "Added \"$title\" -> $dir"
echo "Pick it with SUPER+W."
