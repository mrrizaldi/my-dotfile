
# Created by `pipx` on 2025-10-07 04:14:35
export PATH="$PATH:/home/mrrizaldi/.local/bin"


# Added by Antigravity CLI installer
export PATH="/home/mrrizaldi/.local/bin:$PATH"

# Hyprland GPU order (hybrid laptop): the HDMI port is wired to the NVIDIA GPU.
# HDMI connected at login -> NVIDIA renders, so the external monitor needs no per-frame
# Intel->NVIDIA copy (that copy stalls Hyprland's main thread = frame drops).
# Otherwise Intel renders and NVIDIA can sleep (battery). Decided once per login.
# by-path names have colons (AQ_DRM_DEVICES separator), so resolve to /dev/dri/cardN.
_hy_intel=$(readlink -f /dev/dri/by-path/pci-0000:00:02.0-card)
_hy_nv=$(readlink -f /dev/dri/by-path/pci-0000:01:00.0-card)
# GLX vendor follows the first device here: see glx_vendor() in
# ~/.config/hypr/UserConfigs/user_env.lua.
if grep -qx connected /sys/class/drm/card*-HDMI-A-1/status 2>/dev/null; then
  export AQ_DRM_DEVICES="$_hy_nv:$_hy_intel"
else
  export AQ_DRM_DEVICES="$_hy_intel:$_hy_nv"
fi
unset _hy_intel _hy_nv
