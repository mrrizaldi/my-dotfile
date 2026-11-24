#!/bin/sh
# Screenshot straight to the clipboard, no file saved (like Cinnamon).
#   ScreenshotClip.sh area|full|window
# Paste with Ctrl+V. Uses the dots' shutter sound + a short notification.
tmp=$(mktemp --suffix=.png) || exit 1
trap 'rm -f "$tmp"' EXIT
trap 'exit 130' INT TERM HUP   # signals -> exit, so the EXIT trap cleans up too

case "${1:-area}" in
	area)   geo=$(slurp) || exit 0                      # Esc / right-click = cancel
	        grim -g "$geo" "$tmp" ;;
	full)   grim "$tmp" ;;                              # every monitor, like Cinnamon
	window) geo=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
	        grim -g "$geo" "$tmp" ;;
	*)      echo "usage: $0 area|full|window" >&2; exit 2 ;;
esac || exit 1

wl-copy --type image/png < "$tmp" || exit 1
"$HOME/.config/hypr/scripts/Sounds.sh" --screenshot >/dev/null 2>&1 &
notify-send -t 2000 -i "$HOME/.config/swaync/icons/picture.png" "Screenshot" "Copied to clipboard"
