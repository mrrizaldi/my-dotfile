-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User startup overrides (auto-generated).
-- Add commands with exec_once("your command")
-- Example:
-- exec_once("${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserScripts/MyStartup.sh")

local user_startup_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_startup_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_startup_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_startup_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.exec_once then
          user_startup_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_startup_helper then
    error("Failed to load user_startup_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end
local exec_once = user_startup_helper.exec_once

-- Converted from Startup_Apps.conf
local startup_commands = {
  "$HOME/.config/hypr/UserScripts/LiveWallpaper.sh",
  -- Applies the saved DisplayProfile layout (Meja: HDMI left) at login and on every hotplug.
  -- Without it, monitors.lua's position=auto put HDMI on the right after a hotplug.
  "$HOME/.config/hypr/scripts/MonitorWatcher.sh",
}

local function run_startup_commands()
  for _, cmd in ipairs(startup_commands) do
    exec_once(cmd)
  end
end

if hl and hl.on then
  hl.on("hyprland.start", run_startup_commands)
else
  run_startup_commands()
end

-- Live wallpaper follows monitor hotplug: the engine only covers screens that were connected
-- when it started, so a newly plugged HDMI showed the old static swww image.
-- "hotplug" restarts only a running engine (a paused one stays paused); the script flocks.
if hl and hl.on and hl.exec_cmd then
  local livewall = (os.getenv("HOME") or "") .. "/.config/hypr/UserScripts/LiveWallpaper.sh hotplug"
  for _, ev in ipairs({ "monitor.added", "monitor.removed" }) do
    hl.on(ev, function()
      hl.exec_cmd(livewall)
    end)
  end
end

-- HDMI plugged into an Intel-primary session (logged in without it): offer a relog so ~/.zprofile
-- picks NVIDIA. 15 s countdown with "Batal"; does nothing when already NVIDIA-primary.
if hl and hl.on and hl.exec_cmd then
  local relog = (os.getenv("HOME") or "") .. "/.config/hypr/UserScripts/gpu-relog.sh"
  hl.on("monitor.added", function()
    hl.exec_cmd(relog)
  end)
end
