#!/bin/sh
# Keep NVIDIA VRAM across s2idle suspend (otherwise Wayland/Xorg on dGPU loses buffers after resume).
# nvidia-suspend/resume/hibernate services are already enabled; they need these module options.
# Revert: cp /etc/modprobe.d/nvidia-options.conf.bak /etc/modprobe.d/nvidia-options.conf && update-initramfs -u
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
f=/etc/modprobe.d/nvidia-options.conf
cp -n "$f" "$f.bak"
sed -i -e 's/^#\(options nvidia-current NVreg_PreserveVideoMemoryAllocations=1\)/\1/' \
       -e 's/^#\(options nvidia-current NVreg_EnableS0ixPowerManagement=1\)/\1/' "$f"
# /tmp is tmpfs (RAM); dump VRAM to disk instead
grep -q '^options nvidia-current NVreg_TemporaryFilePath' "$f" ||
  echo 'options nvidia-current NVreg_TemporaryFilePath=/var/tmp' >> "$f"
echo "--- active options:"; grep '^options' "$f"
update-initramfs -u
echo "--- done. Reboot to apply."
