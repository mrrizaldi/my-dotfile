-- User keybind overrides.
-- Add, override, or rebind keybinds here.
--
-- =============================================================================
-- KEYBIND RULES & SYNTAX
-- =============================================================================
-- • bind("MODS", "KEY", action, [options])
-- • unbind("MODS", "KEY")
--
-- Supported modifiers:
--   "SUPER", "SHIFT", "CTRL", "ALT", or combinations like "SUPER SHIFT", "SUPER ALT"
--
-- Actions:
--   • exec_cmd("command")       -> launches a terminal command or script
--   • dispatch("dispatcher", [arg]) -> triggers a Hyprland dispatcher (e.g. killactive, togglefloating)
--
-- =============================================================================
-- EXAMPLES
-- =============================================================================
--
-- NOTE ON LUA REBINDS:
--   Yes — same rule as Hyprlang applies in practice: if a key combo is already bound,
--   unbind("MODS", "KEY") first, then bind(...) it to the new action.
--   This keeps behavior explicit and avoids duplicate/conflicting binds.
--
-- 1. ADDING A BRAND NEW KEYBIND (combo not used by default):
--    bind("SUPER", "Z", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--    bind("SUPER SHIFT", "V", exec_cmd("pavucontrol"), { description = "Audio Control" })
--    bind("SUPER", "X", dispatch("killactive"), { description = "Close active window" })
--
-- 2. OVERRIDING AN EXISTING COMBO WITH A DIFFERENT APP/COMMAND:
--    -- To replace what SUPER+Return opens (default: kitty):
--    unbind("SUPER", "Return")
--    bind("SUPER", "Return", exec_cmd("ghostty"), { description = "Launch Ghostty" })
--
-- 3. REBINDING / MOVING AN ACTION TO A NEW KEY COMBINATION:
--    -- Example: Move File Manager from SUPER+E to SUPER+F, and use SUPER+E for Emacs:
--    unbind("SUPER", "E")       -- unbind default file manager from SUPER+E
--    unbind("SUPER", "F")       -- unbind whatever SUPER+F was doing (default: fake fullscreen)
--    bind("SUPER", "F", exec_cmd("$HOME/.config/hypr/scripts/LaunchFileManager.sh '$files' '$term'"), { description = "File manager" })
--    bind("SUPER", "E", exec_cmd("emacsclient -c -a 'emacs'"), { description = "Launch Emacs" })
--
-- 4. REBINDING COMPOSITOR DISPATCHERS (e.g. workspace, fullscreen, floating):
--    unbind("SUPER", "Q")
--    bind("SUPER", "Q", dispatch("killactive"), { description = "Close active window" })
--    unbind("SUPER", "F") -- default fakefullscreen
--    bind("SUPER SHIFT", "F", dispatch("fullscreen", "0"), { description = "Toggle fullscreen" })
--    bind("SUPER ALT", "W", dispatch("workspace", "special:scratchpad"), { description = "Toggle scratchpad" })
--
-- 5. BIND OPTIONS (locked, repeating):
--    -- locked = true     -> runs even when lockscreen is active (e.g. media keys)
--    -- repeating = true  -> repeats when key is held down (e.g. volume / brightness)
--    bind("CTRL ALT", "bracketright", exec_cmd("$HOME/.config/hypr/scripts/Brightness.sh --inc"), { description = "Brightness up", repeating = true })
--    bind("", "XF86AudioMute", exec_cmd("$HOME/.config/hypr/scripts/Volume.sh --toggle"), { description = "Mute audio", locked = true })
--
-- =============================================================================
local user_keybinds_helper = nil
local submap_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""

  -- Load a helper module from the first candidate path that defines what we
  -- expect. Each helper is loaded exactly once, so a local copy always wins
  -- over the shipped template and no module is executed twice.
  local function load_helper(file_name, validate)
    local candidate_paths = {
      source_dir and (source_dir .. "/../lua/" .. file_name) or nil,
      home ~= "" and (home .. "/.config/hypr/lua/" .. file_name) or nil,
      home ~= "" and (home .. "/.config/hypr/" .. file_name) or nil,
    }

    local tried_paths = {}
    for _, helper_path in ipairs(candidate_paths) do
      if helper_path then
        table.insert(tried_paths, helper_path)
        local f = io.open(helper_path, "r")
        if f then
          f:close()
          local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
          if loaded_ok and type(loaded_helpers) == "table" and validate(loaded_helpers) then
            return loaded_helpers
          end
        end
      end
    end

    return nil, tried_paths
  end

  local tried_paths
  user_keybinds_helper, tried_paths = load_helper("user_keybinds_helper.lua", function(helpers)
    return helpers.bind ~= nil
  end)
  if not user_keybinds_helper then
    error("Failed to load user_keybinds_helper.lua from: " .. table.concat(tried_paths or {}, ", "))
  end

  -- submap_helper is optional: a missing or broken file must not take down all
  -- user keybinds, so it degrades to a warning and the keybinds below still load.
  submap_helper = load_helper("submap_helper.lua", function(helpers)
    return helpers.submap ~= nil
  end)
end

local exec_cmd = user_keybinds_helper.exec_cmd
local dispatch = user_keybinds_helper.dispatch
local bind = user_keybinds_helper.bind
local unbind = user_keybinds_helper.unbind
local submap = submap_helper and submap_helper.submap or nil
if not submap then
  print("[WARN] submap_helper.lua was not found; the submap.* helpers are unavailable. "
    .. "Copy config/hypr/lua/submap_helper.lua to ~/.config/hypr/lua/ to enable them.")
end

-- =============================================================================
-- DISPLAY LAYOUTS
-- =============================================================================
-- SUPER+ALT+D opens the layout menu for the monitor set in front of you.
-- SUPER+ALT+W applies a layout named Work directly, which is also the fallback
-- for when rofi will not start. Both combos were free: SUPER+ALT+H and
-- SUPER+ALT+P are taken by "horizontal scroll right" and the KB-passthrough
-- submap.
bind(
  "SUPER ALT",
  "D",
  exec_cmd("$HOME/.config/hypr/scripts/DisplayProfileMenu.sh"),
  { description = "Display layouts: menu for this monitor set" }
)
bind(
  "SUPER ALT",
  "W",
  -- A bare layout name is the controller's "apply this layout" verb, passed
  -- after -- so a name that looks like an option stays data. Create a layout
  -- called Work (menu -> Edit parameters) and this key applies it.
  exec_cmd("$HOME/.config/hypr/scripts/DisplayProfile.sh -- Work"),
  { description = "Display layouts: apply the layout named Work" }
)

-- Personal binds (ported from UserKeybinds.conf)
bind("SUPER", "bracketleft", exec_cmd("$HOME/.config/hypr/UserScripts/audio-switcher.sh output-toggle"), { description = "Audio Output Toggle" })
bind("SUPER", "bracketright", exec_cmd("$HOME/.config/hypr/UserScripts/audio-switcher.sh input-toggle"), { description = "Audio Input Toggle" })
-- Mouse5 (front side button, BTN_EXTRA) = Ctrl+W (close tab) in browsers.
-- ponytail: bind consumes the click, so Mouse5 = "Forward" is gone in non-browser apps too;
-- use input-remapper if per-app passthrough is ever needed
local BROWSERS = { ["brave-browser"] = true, ["google-chrome"] = true, chromium = true, firefox = true }
bind("", "mouse:276", function()
  local w = hl.get_active_window()
  if w and BROWSERS[tostring(w.class):lower()] then
    hl.dispatch(hl.dsp.send_shortcut({ mods = "CTRL", key = "w" }))
  end
end, { description = "Mouse5: close browser tab" })
bind("SUPER ALT", "N", exec_cmd("$term nmtui-connect"), { description = "connect network" })
unbind("SUPER", "W")
bind("SUPER", "W", exec_cmd("$HOME/.config/hypr/UserScripts/LiveWallpaperSelect.sh"), { description = "select live wallpaper" })
bind("SUPER ALT SHIFT", "W", exec_cmd("$HOME/.config/hypr/UserScripts/LiveWallpaper.sh toggle"), { description = "pause/resume live wallpaper (battery)" })
bind("CTRL ALT", "R", exec_cmd("$HOME/.config/hypr/UserScripts/edp-reset.sh 0"), { description = "Rescue laptop panel", locked = true })
bind("SUPER", "L", exec_cmd("$HOME/.config/hypr/scripts/LockScreen.sh"), { description = "lock screen" })
unbind("SUPER", "C")
-- XWayland: Netflix video is black on Chrome's Wayland path (NVIDIA-primary). See ~/.local/share/applications/google-chrome.desktop
bind("SUPER", "C", exec_cmd("google-chrome-stable --ozone-platform=x11"), { description = "open Google Chrome (XWayland)" })
bind("SUPER SHIFT", "C", exec_cmd("$HOME/.config/hypr/scripts/rofi-ssh-menu.sh"), { description = "SSH session manager" })
bind("SUPER SHIFT", "T", exec_cmd("$term btop"), { description = "btop (system monitor)" })

-- Screenshots straight to the clipboard, no file (like Cinnamon) - UserScripts/ScreenshotClip.sh
-- Delayed shots (SUPER+CTRL[+SHIFT]+Print / F6) still save files via the dots' ScreenShot.sh.
do
  local clip = "$HOME/.config/hypr/UserScripts/ScreenshotClip.sh "
  local shots = {
    { "",            "Print", "full",   "screenshot to clipboard (full)" },
    { "SHIFT",       "Print", "area",   "screenshot to clipboard (area)" },
    { "SUPER",       "Print", "full",   "screenshot to clipboard (full)" },
    { "SUPER",       "F6",    "full",   "screenshot to clipboard (full)" },
    { "SUPER SHIFT", "Print", "area",   "screenshot to clipboard (area)" },
    { "SUPER SHIFT", "F6",    "area",   "screenshot to clipboard (area)" },
    { "SUPER SHIFT", "S",     "area",   "screenshot to clipboard (area)" },
    { "ALT SHIFT",   "S",     "area",   "screenshot to clipboard (area)" },   -- was Hyprshot (not installed)
    { "ALT",         "Print", "window", "screenshot to clipboard (window)" },
    { "ALT",         "F6",    "window", "screenshot to clipboard (window)" },
  }
  for _, s in ipairs(shots) do
    unbind(s[1], s[2])
    bind(s[1], s[2], exec_cmd(clip .. s[3]), { description = s[4] })
  end
  -- the old area-then-edit flow, kept on a free combo
  bind("SUPER CTRL SHIFT", "S", exec_cmd("$HOME/.config/hypr/scripts/ScreenShot.sh --swappy"), { description = "screenshot (area) -> edit in swappy" })
end

-- Per-monitor workspaces: SUPER+N = workspace N on the monitor you're on.
-- Each monitor owns 10 IDs: eDP first (1-10), others by name (11-20, 21-30...).
-- No eDP (lid closed) -> the external monitor gets 1-10, where eDP's workspaces migrate.
-- ponytail: blocks follow the monitors connected right now. After unplugging a monitor its
-- workspaces (e.g. 11-20) land on eDP and are only reachable via SUPER+Tab / waybar.
do
  local function is_edp(name)
    return name:match("^eDP") ~= nil
  end

  local function block_of(name)
    local names = {}
    for _, m in ipairs(hl.get_monitors()) do
      names[#names + 1] = m.name
    end
    table.sort(names, function(a, b)
      if is_edp(a) ~= is_edp(b) then
        return is_edp(a)
      end
      return a < b
    end)
    for i, n in ipairs(names) do
      if n == name then
        return i - 1
      end
    end
    return 0
  end

  local function ws_id(n)
    local mon = hl.get_active_monitor()
    return (mon and block_of(mon.name) or 0) * 10 + n
  end

  local actions = {
    focus = function(id) return hl.dsp.focus({ workspace = id }) end,
    move = function(id) return hl.dsp.window.move({ workspace = id }) end,
    silent = function(id) return hl.dsp.window.move({ workspace = id, follow = false }) end,
  }

  -- Global on purpose: lets `hyprctl eval` test it (see docs/superpowers/plans/2026-11-14-*).
  UserWs = {
    id = ws_id,
    go = function(n, action)
      hl.dispatch(actions[action](ws_id(n)))
    end,
  }

  -- Hyprland gives every new monitor (boot or hotplug) the lowest free workspace ID, e.g.
  -- HDMI 1 + eDP 2 at boot, so SUPER+1 on HDMI (= 11) missed the window opened there.
  -- Move monitors sitting on an EMPTY workspace outside their block to the block's first one.
  -- ponytail: no check whether that first workspace already lives on another monitor
  -- (only possible right after an unplug); focus would then just jump there.
  -- at_boot: also move to exactly the first one (eDP 2 -> 1). Externals go first so ws 1 is
  -- already free when eDP's turn comes.
  function UserWs.settle(at_boot)
    local focused = hl.get_active_monitor()
    local mons = hl.get_monitors()
    table.sort(mons, function(a, b)
      return block_of(a.name) > block_of(b.name)
    end)
    for _, m in ipairs(mons) do
      local ws = m.active_workspace
      local first = block_of(m.name) * 10 + 1
      local off = ws and (ws.id < first or ws.id > first + 9 or (at_boot and ws.id ~= first))
      if off and ws.windows == 0 then
        hl.dispatch(hl.dsp.focus({ monitor = m.name }))
        hl.dispatch(hl.dsp.focus({ workspace = first }))
      end
    end
    if focused then
      hl.dispatch(hl.dsp.focus({ monitor = focused.name }))
    end
  end

  -- Unplug: Hyprland moves the gone monitor's workspaces (e.g. 11-13) onto eDP keeping their
  -- IDs, out of reach of SUPER+N, and drags them back on replug. Instead move their windows
  -- into the lowest empty slots of the block of the monitor they landed on, in order
  -- (11 -> first free, 12 -> next...), so the laptop just counts 1..10.
  -- ponytail: block full (10 busy workspaces) -> leftovers keep their ID.
  function UserWs.gather()
    local by_ws, used = {}, {}
    for _, w in ipairs(hl.get_windows()) do
      local ws = w.workspace
      -- special workspaces (dropterm scratchpad) have id = nil
      if ws and ws.id and ws.id > 0 then
        used[ws.id] = true
        by_ws[ws.id] = by_ws[ws.id] or { mon = ws.monitor.name, wins = {} }
        table.insert(by_ws[ws.id].wins, w)
      end
    end
    local ids = {}
    for id in pairs(by_ws) do
      ids[#ids + 1] = id
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
      local e = by_ws[id]
      local first = block_of(e.mon) * 10 + 1
      if id < first or id > first + 9 then
        for t = first, first + 9 do
          if not used[t] then
            for _, w in ipairs(e.wins) do
              hl.dispatch(hl.dsp.window.move({ window = w, workspace = t, follow = false }))
            end
            used[t] = true
            break
          end
        end
      end
    end
  end

  if hl.on then
    hl.on("hyprland.start", function()
      UserWs.settle(true)
    end)
    hl.on("monitor.added", function()
      UserWs.settle(false)
    end)
    -- ponytail: second pass 1.5 s later in case the event fires before Hyprland has moved the
    -- gone monitor's workspaces / user_laptops re-enabled eDP (unverified; gather is idempotent).
    hl.on("monitor.removed", function()
      UserWs.gather()
      hl.timer(function()
        UserWs.gather()
      end, { timeout = 1500, type = "oneshot" })
    end)
  end

  local kinds = {
    { "SUPER", "focus", "workspace" },
    { "SUPER SHIFT", "move", "move to workspace" },
    { "SUPER CTRL", "silent", "move silently to workspace" },
  }
  for n = 1, 10 do
    local key = "code:" .. (n + 9) -- code:10 = "1" ... code:19 = "0" (workspace 10)
    for _, k in ipairs(kinds) do
      unbind(k[1], key)
      bind(k[1], key, function()
        UserWs.go(n, k[2])
      end, { description = k[3] .. " " .. n .. " (this monitor)" })
    end
  end
end

-- SUPER+arrows: real directional focus, crosses monitors at the screen edge.
-- Dots' layout_focus() cycles windows inside the workspace on dwindle (never leaves the
-- monitor). Cycling stays available on SUPER+J/K.
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  unbind("SUPER", dir)
  bind("SUPER", dir, hl.dsp.focus({ direction = dir }), { description = "focus " .. dir .. " (crosses monitors)" })
end
