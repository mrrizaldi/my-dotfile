#!/bin/sh
# Run by hypridle's after_sleep_cmd. A wallpaper engine that lived through a suspend
# (NVRM error flood on resume, 2026-11-19) leaked ~18 MB/min (3.7 GB after hours);
# a freshly started one grows ~1 MB/min. So restart it once the GPU has settled.
# Old memory + log are kept so the cause can be checked: journalctl -t livewall
#   livewall-resume.sh [delay_s=20]
sleep "${1:-20}"
pid=$(pgrep -x linux-wallpaper) || exit 0 # paused/off: leave it
mem=$(awk '/RssAnon|VmSwap/{s+=$2} END{print int(s/1024)}' "/proc/$pid/status")
logger -t livewall "restart after resume, old engine anon+swap ${mem} MB"
cp /tmp/linux-wallpaperengine.log /tmp/linux-wallpaperengine.prev.log 2>/dev/null
exec "$HOME/.config/hypr/UserScripts/LiveWallpaper.sh" hotplug
