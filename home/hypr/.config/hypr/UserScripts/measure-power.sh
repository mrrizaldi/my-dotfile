#!/bin/bash
# Measure how much power the lock screen draws, via Intel RAPL (CPU package,
# cores, iGPU/uncore) - works on AC too. RAPL counters are root-only, so:
#   sudo ~/.config/hypr/UserScripts/measure-power.sh [seconds=480] [label=qs-lock]
# then lock the screen whenever you like (Quickshell lock or hyprlock) and leave it.
# Measuring starts when the lock appears and stops after <seconds> or at unlock.
# Default 480 s ends before idle-suspend (10 min). Result: ~/power-<label>.log
# On battery it also reports whole-laptop draw from the battery gauge.
set -u
secs=${1:-480}
label=${2:-qs-lock}
[ "$(id -u)" = 0 ] || { echo "run with sudo (RAPL energy counters are root-only)"; exit 1; }

user=${SUDO_USER:-root}
uid=$(id -u "$user")
home=$(getent passwd "$user" | cut -d: -f6)
run="/run/user/$uid"
out="$home/power-$label.log"

R=/sys/class/powercap/intel-rapl:0
zones=("$R" "$R:0" "$R:1")
names=(package cpu-cores igpu)
bat=/sys/class/power_supply/BAT0

locked() {   # Quickshell lock holds this flock while running; hyprlock is a process
	! flock -n "$run/matrix-lock.flock" true 2>/dev/null || pidof -q hyprlock
}
energies() { for z in "${zones[@]}"; do cat "$z/energy_uj"; done; }

echo "waiting for the screen to lock (lock it now)..."
until locked; do sleep 1; done
sleep 3   # skip the lock-in animation
echo "locked - measuring up to ${secs}s; leave the laptop alone"

mapfile -t e0 < <(energies)
mapfile -t max < <(for z in "${zones[@]}"; do cat "$z/max_energy_range_uj"; done)
b0=$(cat "$bat/energy_now"); bstat=$(cat "$bat/status")
t0=$(date +%s.%N)

end=$(( $(date +%s) + secs ))
while [ "$(date +%s)" -lt "$end" ] && locked; do sleep 2; done

mapfile -t e1 < <(energies)
b1=$(cat "$bat/energy_now")
t1=$(date +%s.%N)
dt=$(echo "$t1 - $t0" | bc -l)

{
	echo "label:    $label"
	echo "date:     $(date '+%F %T')"
	printf 'duration: %.0f s%s\n' "$dt" "$(locked || echo ' (stopped early: unlocked)')"
	for i in 0 1 2; do
		d=$(( e1[i] - e0[i] )); (( d < 0 )) && d=$(( d + max[i] ))   # counter wrap
		w=$(echo "$d / 1000000 / $dt" | bc -l)
		printf '%-10s avg %5.2f W   -> %.2f Wh per 10 min\n' "${names[i]}" "$w" "$(echo "$w / 6" | bc -l)"
	done
	if [ "$bstat" = Discharging ]; then
		w=$(echo "($b0 - $b1) / 1000000 / ($dt / 3600)" | bc -l)
		printf '%-10s avg %5.2f W   -> %.2f Wh per 10 min (whole laptop incl. screen)\n' battery "$w" "$(echo "$w / 6" | bc -l)"
	else
		echo "battery    n/a (on AC: unplug to also get whole-laptop draw)"
	fi
} | tee "$out"
chown "$user": "$out"
