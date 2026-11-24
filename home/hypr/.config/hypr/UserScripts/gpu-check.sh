#!/bin/bash
# Run inside the Hyprland session. Shows which GPU does what and whether the dGPU can sleep.
# Output saved to ~/gpu-check.log
exec > >(tee ~/gpu-check.log) 2>&1
dgpu=/sys/bus/pci/devices/0000:01:00.0
log="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log"

echo "== session: $XDG_SESSION_TYPE / $XDG_CURRENT_DESKTOP"
echo "== env: GLX=$__GLX_VENDOR_LIBRARY_NAME LIBVA=$LIBVA_DRIVER_NAME GL_YIELD=$__GL_YIELD"
H=$(pgrep -x Hyprland)
# /proc/<Hyprland>/environ only shows the env Hyprland started with (config env= is setenv'd later), so check a child
echo "== GL_YIELD seen by Hyprland children (waybar): $(tr '\0' '\n' < /proc/$(pgrep -xo waybar)/environ | grep __GL_YIELD || echo unset)"
a=$(awk '{print $14+$15}' /proc/$H/stat); sleep 5; b=$(awk '{print $14+$15}' /proc/$H/stat)
echo "== Hyprland CPU (5s avg): $(( (b-a) * 100 / (5*$(getconf CLK_TCK)) ))%  (before fix: ~80% with HDMI, ~20% without)"
hyprctl monitors | grep ^Monitor
echo "== AQ_DRM_DEVICES (first = renders): $AQ_DRM_DEVICES"
grep -E 'Starting backend|Explicit sync' "$log" | sort | uniq -c
# main thread sleeping inside the NVIDIA driver = stalled on a cross-GPU copy. Before fix: ~50%
blk=$(for i in $(seq 300); do cat /proc/$H/wchan; echo; sleep 0.01; done | grep -c hrtimer_nanosleep)
echo "== Hyprland main thread stalled: $((blk*100/300))%  (Intel-primary with HDMI: ~50-60%)"
echo "== default GL renderer:"; glxinfo -B 2>/dev/null | grep 'renderer string'
echo "== nvidia params:"; grep -E 'PreserveVideoMemory|S0ix|TemporaryFilePath' /proc/driver/nvidia/params
echo "== hyprland GPU log:"; grep -iE 'primary|drm|explicit|syncobj|mgpu|error|fail' "$log" | head -40

# don't call nvidia-smi before this: it wakes the dGPU
echo "== waiting 30s for dGPU to idle..."; sleep 30
echo "== dGPU runtime_status: $(cat $dgpu/power/runtime_status)  (suspended = good, active = something holds it)"
echo "== processes holding NVIDIA:"; fuser -v /dev/nvidia* 2>&1 | grep -v '^\s*$' || echo "(none)"
echo "== temps/fans:"; sensors 2>/dev/null | grep -iE 'package|fan'
echo "== top CPU:"; top -bn1 -o %CPU | sed -n '7,13p'
echo "== crash reports:"; ls -t ~/.cache/hyprland/hyprlandCrashReport* 2>/dev/null | head -3 || echo "(none)"
