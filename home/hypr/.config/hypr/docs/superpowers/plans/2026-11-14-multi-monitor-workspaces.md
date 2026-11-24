# Multi-monitor: tanpa redup, kursor ikut fokus, workspace per monitor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Window/monitor yang tidak fokus tidak lagi redup/transparan, kursor ikut saat fokus pindah via keyboard, dan `SUPER+1..0` berarti "workspace N di monitor yang sedang fokus".

**Architecture:** Semua perubahan di `UserConfigs/` (file dots tidak disentuh). Tiap monitor dapat blok 10 ID workspace: eDP dulu (1–10), monitor lain urut nama (11–20, 21–30…); tanpa eDP (lid tertutup) monitor eksternal dapat 1–10. Fungsi Lua kecil di `user_keybinds.lua` menghitung ID dari monitor aktif, lalu bind ulang `SUPER` / `SUPER SHIFT` / `SUPER CTRL` + angka. Tidak perlu workspace rule: workspace baru otomatis dibuat di monitor yang sedang fokus.

**Tech Stack:** Hyprland 0.57.2 Lua config (`hl.*` API), `hyprctl`, `jq`.

**Keputusan desain (sudah disetujui user 2026-11-14):**
- Model per monitor (bukan virtual desktop berpasangan, bukan plugin `split-monitor-workspaces` → harus rebuild tiap update Hyprland).
- `dim_special` (overlay gelap saat special workspace) **tetap**, itu bukan efek window tidak aktif.
- Pindah fokus/window antar monitor pakai bind yang **sudah ada**: `SUPER ←/→` (fokus), `SUPER CTRL ←/→` (pindah window; di tepi layar menyeberang monitor). Tidak ada bind baru.
- Waybar (dots-owned, `all-outputs: true`, format titik `{icon}`) **tidak** diubah. Nama workspace tidak di-rename karena waybar tidak menampilkan angka.
- Batasan yang diterima: setelah HDMI dicabut, workspace 11–20 pindah ke eDP dengan ID aslinya → hanya bisa dicapai via `SUPER Tab` / klik waybar, bukan `SUPER+N`.

**Catatan:** `~/.config/hypr` bukan git repo → tiap task bikin backup `.bak-pmw` alih-alih commit.

---

## File Structure

| File | Perubahan |
|---|---|
| `UserConfigs/user_decorations.lua` | `inactive_opacity` 0.9 → 1.0, `dim_inactive` true → false |
| `UserConfigs/user_settings.lua` | tambah `cursor.no_warps = false` |
| `UserConfigs/workspaces.lua` | hapus rule sisa nested test (`workspace 2 → WAYLAND-1`) |
| `UserConfigs/user_keybinds.lua` | blok baru "Per-monitor workspaces" di akhir file |

Task 1–4 bisa dikerjakan **tanpa** monitor eksternal (Task 4 pakai headless output). Task 5 butuh monitor asli.

---

### Task 0: Backup

- [ ] **Step 1: Backup keempat file**

```bash
cd ~/.config/hypr/UserConfigs
for f in user_decorations.lua user_settings.lua workspaces.lua user_keybinds.lua; do cp -a "$f" "$f.bak-pmw"; done
ls *.bak-pmw
```
Expected: 4 file `.bak-pmw`.

Rollback kapan saja: `for f in *.bak-pmw; do mv "$f" "${f%.bak-pmw}"; done; hyprctl reload`.

---

### Task 1: Matikan redup & transparan untuk window tidak aktif

**Files:**
- Modify: `UserConfigs/user_decorations.lua` (blok `decoration`, ±baris 36–38)

- [ ] **Step 1: Cek nilai sekarang (harus "gagal" terhadap target)**

```bash
hyprctl getoption decoration:inactive_opacity -j | jq .float
hyprctl getoption decoration:dim_inactive -j | jq .int
```
Expected sekarang: `0.9` dan `1`.

- [ ] **Step 2: Edit**

Ganti:
```lua
    inactive_opacity = 0.9,
```
menjadi:
```lua
    inactive_opacity = 1.0, -- no see-through on unfocused windows (other monitor looked faded)
```
dan:
```lua
    dim_inactive = true,
```
menjadi:
```lua
    dim_inactive = false, -- unfocused monitor no longer looks dimmed
```
`dim_strength` dan `dim_special` biarkan.

- [ ] **Step 3: Reload & verifikasi**

```bash
hyprctl reload; sleep 1
hyprctl configerrors
hyprctl getoption decoration:inactive_opacity -j | jq .float
hyprctl getoption decoration:dim_inactive -j | jq .int
```
Expected: configerrors kosong, lalu `1` dan `0`.

---

### Task 2: Kursor ikut saat fokus pindah via keyboard

Kenapa: dots set `cursor:no_warps = true` (`lua/settings.lua`). `SUPER →` ke Chrome di monitor lain memindah keyboard tapi kursor tetap → scroll kena window lama, dan `follow_mouse = 1` merebut fokus balik begitu mouse tersenggol.

**Files:**
- Modify: `UserConfigs/user_settings.lua` (tambah di akhir file)

- [ ] **Step 1: Cek nilai sekarang**

```bash
hyprctl getoption cursor:no_warps -j | jq .bool
```
Expected: `true`.

- [ ] **Step 2: Tambahkan di akhir file**

```lua

-- Cursor follows keyboard focus (SUPER+arrows, also across monitors), so scroll/click
-- hit the same window the keyboard is on. Dots default (lua/settings.lua) is no_warps = true.
hl.config({ cursor = { no_warps = false } })
```

- [ ] **Step 3: Reload & verifikasi**

```bash
hyprctl reload; sleep 1
hyprctl configerrors
hyprctl getoption cursor:no_warps -j | jq .bool
```
Expected: kosong, lalu `false`. Manual: buka 2 window berdampingan, `SUPER ←/→` → kursor lompat ke tengah window yang difokus.

---

### Task 3: Hapus workspace rule sisa nested test

**Files:**
- Modify: `UserConfigs/workspaces.lua` (baris terakhir)

- [ ] **Step 1: Hapus baris ini**

```lua
hl.workspace_rule({ workspace = "2", monitor = "WAYLAND-1", layout = "dwindle" })
```
(`WAYLAND-1` = output nested Hyprland, bukan monitor asli; ditulis `PersistWorkspaceLayout.sh` waktu test. Komentar contoh di atasnya biarkan.)

- [ ] **Step 2: Verifikasi**

```bash
grep -c WAYLAND-1 ~/.config/hypr/UserConfigs/workspaces.lua
hyprctl reload; sleep 1; hyprctl configerrors
```
Expected: `0`, configerrors kosong.

---

### Task 4: Workspace per monitor

**Files:**
- Modify: `UserConfigs/user_keybinds.lua` (tambah blok di akhir file)

- [ ] **Step 1: Tes gagal dulu — `UserWs` belum ada**

```bash
hyprctl eval 'error("id=" .. UserWs.id(3))' 2>&1
```
Expected: error `attempt to index a nil value (global 'UserWs')`.
(Trik: `hyprctl eval` jalan di state Lua config yang sama; `error(...)` dipakai untuk membaca nilai karena eval cuma mengembalikan `ok`.)

- [ ] **Step 2: Tambahkan blok ini di akhir `user_keybinds.lua`**

```lua

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
```

- [ ] **Step 3: Reload & cek error**

```bash
hyprctl reload; sleep 1
hyprctl configerrors
grep -h 'WARN\|ERR' "$XDG_RUNTIME_DIR"/hypr/*/hyprland.log | tail -5
```
Expected: configerrors kosong; tidak ada `[WARN]` baru yang menyebut `user_keybinds`.

- [ ] **Step 4: Tes satu monitor (perilaku harus sama seperti dulu)**

```bash
hyprctl eval 'error("id=" .. UserWs.id(3))' 2>&1
```
Expected: `...: id=3`. Manual: `SUPER+3` → workspace 3, `SUPER+1` balik; `SUPER SHIFT+2` pindah window ke 2 dan ikut; `SUPER CTRL+3` pindah window tanpa ikut.

- [ ] **Step 5: Tes dua monitor pakai headless output (tanpa monitor asli)**

```bash
hyprctl output create headless PMWTEST
hyprctl monitors -j | jq -r '.[] | "\(.name) ws=\(.activeWorkspace.id)"'
hyprctl dispatch 'hl.dsp.focus({ monitor = "PMWTEST" })'
hyprctl eval 'error("id=" .. UserWs.id(3))' 2>&1
hyprctl eval 'UserWs.go(3, "focus")'
hyprctl monitors -j | jq -r '.[] | "\(.name) ws=\(.activeWorkspace.id)"'
hyprctl dispatch 'hl.dsp.focus({ monitor = "eDP-1" })'
hyprctl eval 'error("id=" .. UserWs.id(3))' 2>&1
hyprctl output remove PMWTEST
```
Expected:
- `id=13` saat fokus di PMWTEST.
- Setelah `go(3)`: `PMWTEST ws=13`, `eDP-1 ws=` **sama** dengan sebelum tes.
- `id=3` setelah fokus balik ke eDP-1.
- Setelah `output remove`, `hyprctl monitors` cuma eDP-1. Workspace 13 kosong → hilang sendiri.

Kalau `hyprctl output create` gagal di 0.57, lewati step ini; Task 5 menutupinya.

---

### Task 5: Tes nyata dengan monitor eksternal (di meja)

- [ ] **Step 1: Colok HDMI, login ulang** (`.zprofile` set `AQ_DRM_DEVICES` NVIDIA-first saat login).

- [ ] **Step 2: Cek blok**

```bash
hyprctl monitors -j | jq -r '.[] | "\(.name) ws=\(.activeWorkspace.id) focused=\(.focused)"'
```
Fokus di HDMI-A-1 lalu `hyprctl eval 'error("id=" .. UserWs.id(1))' 2>&1` → `id=11`.

- [ ] **Step 3: Checklist manual**
  - Monitor yang tidak fokus **tidak** redup/transparan.
  - Di eDP `SUPER+3` → eDP ke ws 3, HDMI tidak berubah. Di HDMI `SUPER+3` → HDMI ke ws 13, eDP tidak berubah.
  - `SUPER →` dari eDP ke Chrome di HDMI → kursor ikut ke Chrome, scroll kena Chrome.
  - `SUPER CTRL →` berulang → window menyeberang ke HDMI.
  - `SUPER SHIFT+2` di HDMI → window ke ws 12 di HDMI.
  - `SUPER Tab` cuma muter workspace di monitor yang fokus.

- [ ] **Step 4: Cabut HDMI** → window dari 11–20 muncul di eDP, bisa dicapai via `SUPER Tab`. Tidak ada crash/freeze (cek `hyprctl monitors`).

- [ ] **Step 5: Bersihkan backup kalau semua oke**

```bash
rm ~/.config/hypr/UserConfigs/*.bak-pmw
```

- [ ] **Step 6: Update `~/.config/hypr/CLAUDE.md`** tabel "Where things live", tambah baris:

```markdown
| Per-monitor workspaces (SUPER/SHIFT/CTRL+N = ws N on focused monitor, eDP 1-10, others 11+) | `UserConfigs/user_keybinds.lua` (`UserWs`) |
```
