# Hyprland config (KooL / LinuxBeginnings Lua dots)

Machine: HP Victus 15-fa0xxx, Debian 13 trixie, Intel ADL iGPU (eDP, card0) + RTX 3050 (HDMI-A-1 wired to dGPU).
Hyprland **0.57.2** built from source into `/usr/local` (SDDM session "Hyprland (direct)", no start-hyprland watchdog).
NVIDIA driver 595 (NVIDIA CUDA repo, open module). Kernel 7.2.12 (+ 6.12 fallback).

Full history of past debugging: `~/.claude/projects/-home-mrrizaldi/memory/hyprland-hybrid-gpu.md`
and `laptop-resume-black-screen.md`. Read them before touching GPU, suspend or lockscreen stuff.
User-facing summary (Indonesian, keep in sync after every fix): `docs/CATATAN-LAPTOP.md`.

## Hard rules

- **0.57 is Lua-only.** `.conf` for Hyprland itself is ignored (hypridle/hyprlock still use `.conf`).
- **Never run `Hyprland --verify-config` without `-c`** — it autogenerates/overwrites `hyprland.lua`.
- **0.57 dispatch syntax:** `hyprctl dispatch name args` fails. Use
  `hyprctl dispatch 'hl.dsp.X({...})'`, e.g. `hyprctl dispatch hl.dsp.dpms '{ action = "on" }'`.
- Animation `speed` max is 100 in 0.57.
- `hl.reload_config()` via `hyprctl eval` does NOT undo eval'd `hl.animation` overrides.
- Edit **only `UserConfigs/` and `UserScripts/`**. `configs/system_*.lua`, `lua/`, `scripts/` belong to
  the dots and get replaced by `copy.sh --upgrade` (which also silently drops user tweaks → re-port from
  `UserConfigs/LegacyConfigs/<ts>` if that ever happens). Need to change a dots script? Copy it into
  `UserScripts/` and point the keybind there.
- Don't `pkill -f <pattern>` where the pattern is in your own command line (kills your shell).
- Never screenshot the live session to check something — it captured private content once. Use nested
  previews and only grim while `hyprctl activewindow` pid == preview pid.

## Load order

`hyprland.lua` → `lua/user_defaults` → `lua/keybind_index` → `lua/animations` → `lua/window_actions` →
`lua/user_overrides` → `lua/monitors` → `lua/workspaces`.

`lua/user_overrides.lua` loads `configs/system_*.lua` first, then `UserConfigs/user_*.lua`
(env, startup, window_rules, layer_rules, keybinds, settings, decorations, animations, laptops) — user
files win. Missing file = silently skipped; other load errors print `[WARN]` to the Hyprland log.

Rebinding an existing combo: `unbind(...)` first, then `bind(...)` (see header of `user_keybinds.lua`).

## Where things live

| What | File |
|---|---|
| Env (GPU, `__GL_YIELD=USLEEP`, GLX vendor) | `UserConfigs/user_env.lua` |
| Keybinds | `UserConfigs/user_keybinds.lua` |
| Per-monitor workspaces (SUPER/SHIFT/CTRL+N = ws N on focused monitor; eDP 1-10, others 11+ by name). Test: `hyprctl eval 'error(UserWs.id(3))'`. Hyprland gives new monitors the lowest free ws ID (boot: HDMI 1, eDP 2) → `UserWs.settle` on `hyprland.start` / `monitor.added` moves empty off-block monitors into their block. Unplug: `UserWs.gather` (`monitor.removed`) moves windows of off-block workspaces into the lowest empty slots of the monitor they landed on (HDMI 11,12 → eDP free slots), so replug pulls nothing back. Runs twice (now + 1.5 s timer). Special workspaces have `id = nil` — guard it (crash left browsers stranded on 11/13, 2026-11-19) | `UserConfigs/user_keybinds.lua` (`UserWs`), plan in `docs/superpowers/plans/2026-11-14-*` |
| SUPER+arrows = native directional focus (crosses monitors; dots' version only cycled inside the workspace on dwindle) | `UserConfigs/user_keybinds.lua` |
| Unfocused windows: no dim, opacity 1.0; cursor warps on keyboard focus (`no_warps = false`) | `UserConfigs/user_decorations.lua`, `user_settings.lua` |
| Per-app opacity: inactive = active (dots' `lua/window_rules.lua` opacity-*-tag rules drop inactive to 0.7-0.86 and override the global). Check: `hyprctl getprop address:<a> opacity_inactive` | `UserConfigs/user_window_rules.lua` (`user-same-opacity-*`) |
| Chrome runs on XWayland (`--ozone-platform=x11`): Netflix/Widevine video black (subs + audio OK, frames decoded) on Chrome's Wayland path with NVIDIA-primary; X11 works. Forcing Chrome to Intel (`--render-node-override=renderD128`) = whole window black (NVIDIA Hyprland can't import Intel dmabufs). Chrome 157 has no ozone-platform-hint flag | `UserConfigs/user_keybinds.lua` (SUPER C), `~/.local/share/applications/google-chrome.desktop` (user copy) |
| Brave same fix (2026-11-21): fullscreen video black on Wayland path (Chromium overlay surface NVIDIA Hyprland can't show) → `--ozone-platform=x11`. Also `vrr = 0` + `render.send_content_type = false`: both made fullscreen modeset HDMI-A-1 (black blink); HDMI via NVIDIA has no VRR | `~/.local/share/applications/brave-browser.desktop` (user copy), `UserConfigs/user_settings.lua` |
| Startup apps (live wallpaper) | `UserConfigs/user_startup.lua` |
| Animations (borderangle OFF on purpose, saves ~9% CPU) | `UserConfigs/user_animations.lua` |
| Monitors / workspaces. `position = "auto"` orders by detection (boot: HDMI left, hotplug: HDMI right) → desk layout saved as DisplayProfile layout `Meja` (default for eDP + SKYDATA H27G30Q): HDMI 0x0, eDP 2560x0. Change: arrange live, `scripts/DisplayProfile.sh capture -- Meja` (or SUPER ALT D menu). Applied at login + every hotplug by `scripts/MonitorWatcher.sh` (started from `user_startup.lua`, added 2026-11-19; before that nothing applied it → HDMI landed right after hotplug). Log: `$XDG_RUNTIME_DIR/kooldots-display-profiles/monitor-watcher.log` | `UserConfigs/monitors.lua`, `UserConfigs/workspaces.lua`, `UserConfigs/display-layouts.json` |
| Idle / lock / suspend | `hypridle.conf` → `UserScripts/matrix-lock.sh`, `idle-suspend.sh`, `lock-watchdog.sh` |
| Lockscreen (Quickshell) | `~/.config/quickshell/matrix-lock/` (hyprlock = fallback, `hyprlock.conf` sources `hyprlock-matrix.conf`) |
| Colors | wallust (`wallust/`), regenerated from wallpaper by dots' WallpaperDaemon |
| Waybar | `~/.config/hypr/waybar/` (dots-owned; `~/.config/waybar/` no longer exists). Active = `config` symlink → `configs/[TOP] Default Laptop (per-monitor)` (user copy of `(old v4)` using `hyprland/workspaces#permon` from `UserModules`: per-output, 11-20 labelled like 1-10; revert = point symlink back + restart waybar). cava module removed on purpose: −14% Hyprland CPU |
| Rofi themes | `~/.config/hypr/rofi/` (`~/.config/rofi/` no longer exists — old scripts pointing there lose `show-icons`, so menus show names only) |

## Live wallpaper (linux-wallpaperengine, custom)

- Engine: `~/linux-wallpaperengine/build/output/linux-wallpaperengine`, one process for all screens.
  Wallpapers in `~/.local/share/wallpaperengine/wallpapers/<id>/`; state file `…/current` = lines `MONITOR ID`.
  swww-daemon keeps running underneath (static image).
- `UserScripts/LiveWallpaper.sh`: no args = (re)start from state (login, via `user_startup.lua`);
  `MON ID` = set + restart; `MON off` = remove; `toggle` = pause/resume.
- Hotplug: `user_startup.lua` runs `LiveWallpaper.sh hotplug` on `monitor.added/removed` (restarts only a running
  engine, 2 s delay for DisplayProfile; whole script is `flock`ed on `$XDG_RUNTIME_DIR/livewall.lock`, engine
  started with `9>&-` so it never holds the lock).
- `SUPER+W` → `UserScripts/LiveWallpaperSelect.sh` (rofi with previews). Auto-imports newly subscribed
  Steam Workshop items as hardlinks (skips `web` type and IDs in `ignore.txt`). Rofi icons are 320px
  thumbs cached in `~/.cache/livewall-thumbs/<id>.jpg` (originals are up to 1 MB GIFs). First entry =
  turn live off + open the static picker.
- `SUPER ALT SHIFT W` → `LiveWallpaper.sh toggle` (battery): kills the engine, swww shows the still frame.
  Not remembered across login (startup restarts it).
- `UserScripts/AddLiveWallpaper.sh FILE [TITLE]` adds any mp4/webm as `wallpapers/local-<sha1>/`
  (hardlink + 640px preview + minimal `project.json`: `type`, `title`, `file`, `preview`).
- **Never run two engines at once** (e.g. start new before killing old to hide the load gap) → the new
  one renders black. Order stays kill → wait → start. The load gap is covered by first putting the new
  wallpaper's still on swww (`<id>-bg.jpg`, first frame of its preview).
- Paused image = `--screenshot ~/.cache/livewall-thumbs/live-shot.jpg --screenshot-delay 90` (full-res
  frame ~3 s after start, deleted on every start). The engine stitches all screens side by side in
  `std::map` name order (`LC_ALL=C sort`, so `HDMI-A-1` before `eDP-1`); `toggle` crops per monitor into
  `paused-<MON>.jpg`. Falls back to the low-res preview if paused before the shot exists. Rotated
  monitors not handled.
- `swww img` from these scripts doesn't touch the dots' rofi wallpaper links, so wallust colors and the
  static wallpaper restored at login stay unchanged.
- Engine log: `/tmp/linux-wallpaperengine.log`.
- **RAM leak after suspend (2026-11-19):** an engine that lived through a suspend (resume with NVRM error flood)
  grew ~18 MB/min (3.7 GB anon+swap, all in `[heap]`); fresh engine ~1 MB/min. A/B: `--hwdec no` alone also
  leaks ~20 MB/min; Pulse detector negligible. Fix: hypridle `after_sleep_cmd` runs `UserScripts/livewall-resume.sh`
  (20 s later, `LiveWallpaper.sh hotplug` = restart only if running). It logs the old size (`journalctl -t livewall`)
  and keeps the old log as `/tmp/linux-wallpaperengine.prev.log` (look for nvdec→software fallback there).
  Note `ps etime` excludes suspend time. Backup: `hypridle.conf.bak-livewall`.
- **Local patch, re-apply after `git pull`**: `src/WallpaperEngine/VideoPlayback/MPV/GLPlayer.cpp` sets
  mpv `clipboard-backends=vo`. mpv 0.40's Wayland clipboard thread (`clipboard-wayland.c:334`) busy-loops
  in `ppoll` = 1 full core per video player (2 screens = ~210% CPU, 97 °C); patched ~8%, 58 °C.
  `clipboard-backends-remove` is silently ignored. Check: `git -C ~/linux-wallpaperengine diff`.
  Trigger = copying an image (screenshot) to the clipboard. Upstream PR: Almamu/linux-wallpaperengine#742
  (branch `fix/mpv-wayland-clipboard-spin`, remote `fork`). Drop the local patch once #742 is merged or
  Debian ships mpv ≥ 0.41.

## Waybar runs under systemd (custom, outside dots)

- `~/.config/systemd/user/waybar.service` overrides the Debian unit: `ExecStart` resolves the config like
  `WaybarStartup.sh` (`DisplayProfile.sh waybar-config`, fallback `hypr/waybar/config`) + `Restart=on-failure`.
- Why: waybar 0.12 segfaults in the `mpris` module (`Glib::DispatchNotifier`) when MPRIS players
  re-register (2026-11-14). Launched directly, a crashed bar stayed gone.
- No `[Install]` on purpose → unit is `static`, so dots' `WaybarStartup.sh` takes its systemd path and
  starts it only after importing `WAYLAND_DISPLAY`. Don't `enable` it (would start before env exists).
- Clean exit (`pkill waybar`) is not restarted; 5 crashes/10 s → systemd gives up, `SUPER ALT R` resets.
- Revert: delete the file + `systemctl --user daemon-reload`.

## Hybrid GPU setup (don't break)

- `~/.zprofile` exports `AQ_DRM_DEVICES` at login: HDMI connected → NVIDIA first (kills the 50% main-thread
  stall on external 1440p144), else Intel first (battery). Aquamarine reads it before config loads, so it
  can't move into Lua.
- `user_env.lua` `glx_vendor()` derives `__GLX_VENDOR_LIBRARY_NAME` from that order (mesa on NVIDIA
  Xwayland = zink, bad). `LIBVA_DRIVER_NAME=iHD` always.
- In NVIDIA-primary mode the eDP blit falls back to CPU copy (known aquamarine FIXME, no knob).
- HDMI plugged AFTER login = Intel stays primary and renders the 1440p144 monitor too (iGPU ~86%, maxed clock;
  Hyprland + live wallpaper). `UserScripts/gpu-relog.sh` (on `monitor.added`, user_startup.lua) shows a 15 s
  countdown → `scripts/Logout.sh` → SDDM; "Batal"/closing keeps the session. `DRY=1 WAIT=3` to test.
  Per-process iGPU busy: `/proc/<pid>/fdinfo` `drm-engine-render` (one value per drm-client-id).
- Power profile: keep `balanced` — `performance` = 96–100 °C, HP EC fans don't ramp.
- Diagnostics: `UserScripts/gpu-check.sh` (run inside Hyprland → `~/gpu-check.log`).

## Lockscreen / suspend gotchas

- Quickshell lock freezes after long (hours) suspends. `lock-watchdog.sh` (hypridle `after_sleep_cmd`)
  checks the frame heartbeat in `$XDG_RUNTIME_DIR/matrix-lock.heartbeat`, restarts qs once, then falls back
  to hyprlock.
- Rescue from TTY: `UserScripts/lock-rescue.sh` (saves logs to `~/lock-debug-*`).
- Preview without locking: `MATRIX_LOCK_PREVIEW=1 [MATRIX_LOCK_DEMO=1|type|grant]`.
- `idle-suspend.sh 540` suspends only if locked ≥ 9 min; `DRY=1` prints the decision.
- eDP black-after-resume was fixed by patched VBT (`i915.vbt_firmware`), not config. Manual reset:
  Ctrl+Alt+R → `UserScripts/edp-reset.sh`.
- Lid binds + Ctrl+Alt+R must stay `locked = true` (lid opens on the lock screen after suspend).
  `user_laptops.lua` ignores the `FALLBACK` headless output as "external": counting it kept eDP
  disabled after undocking with the lid closed → resume showed only FALLBACK = black (2026-11-18).

## Testing a change

1. Edit file in `UserConfigs/`.
2. `hyprctl reload` (or the dots auto-reload via `LuaConfigWatch.sh`).
3. Check errors: `hyprctl configerrors` and `$XDG_RUNTIME_DIR/hypr/*/hyprland.log`.
4. Bigger/risky changes: nested test before touching the live session.

## Updating Hyprland

Installer fork at `~/Debian-Hyprland-LB` (tag pinned in `hypr-tags.env`). Prepend
`~/Debian-Hyprland-LB/tools/git` to PATH (GitHub connection resets). After rebuild: no
`/usr/local/bin/hypr*` may `ldd` a stale libhyprutils/libaquamarine. Backups in `~/backups/`.
