#!/bin/bash
# Re-train the laptop panel link after s2idle resume (i915 eDP link training
# fails on first try after resume on this HP Victus; a later fresh modeset works).
# Retries until the kernel log shows no new "link training" error (needs adm group).
# ponytail: blind dpms cycle, replace with kernel/BIOS fix if one lands.
sleep "${1:-3}"
# A panel left disabled (not just dpms-off) needs the layout re-applied first.
hyprctl eval 'apply_laptop_monitor_layout(true)'
for try in 1 2 3 4 5; do
    since=$(date '+%Y-%m-%d %H:%M:%S')
    hyprctl dispatch 'hl.dsp.dpms({ action = "off", monitor = "eDP-1" })'
    sleep 1
    hyprctl dispatch 'hl.dsp.dpms({ action = "on", monitor = "eDP-1" })'
    sleep 1
    journalctl -k --since "$since" --no-pager -q | grep -q 'eDP-1.*link training' || exit 0
    sleep 2
done
