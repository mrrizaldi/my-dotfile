#!/usr/bin/env bash
# HDMI plugged into a session that logged in WITHOUT it: ~/.zprofile picked Intel as the primary
# GPU, so the iGPU renders everything incl. the 1440p144 monitor (~86% busy, maxed clocks) while
# the RTX idles. The GPU order is fixed at login (aquamarine reads AQ_DRM_DEVICES before config),
# so the only fix is a relog. Countdown notification, then logout to SDDM (password still asked).
# "Batal" or closing the notification keeps the session. Run on monitor.added (user_startup.lua).
# Test without logging out: DRY=1 WAIT=3 UserScripts/gpu-relog.sh
WAIT=${WAIT:-15}
intel=$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card)
[[ "${AQ_DRM_DEVICES%%:*}" == "$intel" ]] || exit 0 # already NVIDIA-primary
hdmi() { grep -qx connected /sys/class/drm/card*-HDMI-A-1/status 2>/dev/null; }
hdmi || exit 0
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/gpu-relog.lock"
flock -n 9 || exit 0 # monitor.added comes in bursts: one prompt at a time

act=$(timeout "$WAIT" notify-send -a "GPU mode" -i video-display -t $((WAIT * 1000)) \
  -A logout="Logout sekarang" -A cancel="Batal" \
  "HDMI terdeteksi, GPU masih mode Intel" \
  "Logout otomatis dalam $WAIT detik supaya login ulang pakai NVIDIA. Simpan pekerjaanmu; sesi tmux tetap jalan.")
rc=$?
# rc 124 = countdown ran out. Anything else without "logout" = Batal or closed by hand.
[[ $rc -eq 124 || "$act" == logout ]] || exit 0
hdmi || exit 0 # unplugged during the countdown
if [[ -n "$DRY" ]]; then
  echo "DRY: would log out now (rc=$rc act=${act:-none})"
  exit 0
fi
exec "$HOME/.config/hypr/scripts/Logout.sh"
