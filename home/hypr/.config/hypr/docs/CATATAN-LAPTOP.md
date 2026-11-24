# Catatan Laptop: GPU, Layar, Suspend, Lockscreen

HP Victus 15-fa0xxx · Debian 13 · Intel iGPU (layar laptop / eDP) + RTX 3050 (port HDMI)
Hyprland 0.57.2 (build sendiri, `/usr/local`) · driver NVIDIA 595 · kernel 7.2.12

Status per 2026-11-18. Tiap bagian ditandai:
**[BERES]** sudah diperbaiki dan terbukti · **[AKALAN]** jalan, tapi workaround, akar masalah di luar kendali kita ·
**[BELUM DIUJI]** sudah dipasang tapi skenario aslinya belum dicoba ulang · **[TERBUKA]** belum ada solusi.

---

## 1. Pembagian kerja Intel vs RTX

### Fakta kabel (tidak bisa diubah)
- Layar laptop (eDP) tersambung ke **Intel**. Port HDMI tersambung ke **RTX**.
- Jadi saat dua layar dipakai, gambar harus disalin antar-GPU. Itu sumber semua masalah performa.

### Riwayat
| Tanggal | Masalah | Tindakan | Status |
|---|---|---|---|
| 12 Nov | Config bawaan dots memaksa semua app ke NVIDIA (`__GLX_VENDOR_LIBRARY_NAME=nvidia`, `LIBVA_DRIVER_NAME=nvidia`) → panas, crash | Default dibalik: app biasa di Intel, RTX hanya kalau diminta | [BERES] |
| 12 Nov | Suspend dengan NVIDIA tidak menyimpan memori GPU | Opsi modul NVIDIA: PreserveVideoMemory=1, S0ix=1 (sekarang bawaan paket 595) | [BERES] |
| 12 Nov | Hyprland makan CPU ~80% kalau HDMI nyala (driver 550 sibuk-menunggu) | `__GL_YIELD=USLEEP` → 29% | [BERES], lalu diganti solusi di bawah |
| 12 Nov | Driver Debian (550) terlalu tua, tidak punya explicit sync | Upgrade ke driver 595 dari repo NVIDIA. Rollback: `~/nvidia-595/rollback.sh` | [BERES] |
| 12 Nov | Sesudah upgrade, SDDM tidak muncul (modul `nvidia-drm` telat dimuat) | `/etc/modules-load.d/nvidia-drm.conf` berisi `nvidia-drm` | [BERES] |
| 12 Nov | Masih ~50% thread utama macet saat HDMI nyala, walau sudah 595 | **GPU utama dipilih saat login** (lihat bawah) → macet 50% → 2% | [BERES] |
| 12 Nov | CPU Hyprland masih 25–38% saat dua layar | Hapus modul waybar `cava` (−14%), matikan animasi border yang tak terlihat | [BERES] sebagian |
| — | Layar laptop disalin lewat CPU saat RTX jadi GPU utama | Bug yang diketahui di aquamarine (pustaka Hyprland), tidak ada setelan | [TERBUKA], tidak bisa kita perbaiki |

### Cara kerjanya sekarang
`~/.zprofile` dijalankan **sekali saat login**, lalu mengisi `AQ_DRM_DEVICES` (GPU pertama = yang me-render semuanya):

| Saat login | GPU utama | Cocok untuk |
|---|---|---|
| HDMI tercolok | **RTX** | Meja / monitor 1440p144 / clamshell |
| HDMI tidak tercolok | **Intel** | Baterai, di luar |

- `UserConfigs/user_env.lua` ikut menyesuaikan GLX ke GPU yang sama. `LIBVA_DRIVER_NAME=iHD` selalu: **decode video selalu di Intel** (lebih hemat).
- **HDMI dicolok sesudah login** → Intel tetap GPU utama dan ikut me-render monitor besar (iGPU ~86%, panas).
  `UserScripts/gpu-relog.sh` lalu menampilkan hitung mundur 15 detik untuk logout. **Jangan tekan "Batal"**, login ulang saja.
- **Posisi monitor** (monitor di kiri, laptop di kanan) = layout DisplayProfile `Meja`. Dipasang otomatis saat login
  dan tiap HDMI dicolok oleh `scripts/MonitorWatcher.sh` (dijalankan dari `UserConfigs/user_startup.lua`, sejak 2026-11-19).
  Kalau kebalik lagi: `SUPER+ALT+D` → Meja; cek log `$XDG_RUNTIME_DIR/kooldots-display-profiles/monitor-watcher.log`.
- Intel tidak pernah benar-benar "mati": iGPU ada di dalam CPU. Saat tidak dipakai ia masuk mode hemat (RC6) dan hampir tidak memakan daya.

### Cek sendiri
```sh
echo $AQ_DRM_DEVICES                      # device pertama = GPU utama
sudo intel_gpu_top                        # Render/3D Intel harus ~0% kalau RTX yang utama
nvidia-smi
UserScripts/gpu-check.sh                  # ringkasan, ditulis ke ~/gpu-check.log
```

### Panas
- Power profile **harus `balanced`**. `performance` = CPU 96–100 °C, kipas HP tidak ikut naik (dikontrol EC).
- Live wallpaper menambah ~7–9 °C di iGPU.
- **RAM wallpaper bocor habis suspend** (2026-11-19): engine yang ikut suspend naik ~18 MB/menit (3,7 GB setelah
  berjam-jam), engine baru cuma ~1 MB/menit. Sekarang hypridle me-restart engine 20 detik setelah resume
  (`UserScripts/livewall-resume.sh`). Cek: `journalctl -t livewall` (ukuran RAM engine lama sebelum di-restart).

---

## 2. Layar laptop hitam sesudah suspend (masalah driver Intel)

| Tanggal | Masalah | Tindakan | Status |
|---|---|---|---|
| 11–13 Nov | Bangun dari sleep, layar laptop hitam, padahal sistem hidup. Kernel: `eDP-1 Failed to enable link training` | Akar: tabel firmware (VBT) dari BIOS HP mendeklarasikan layar kedua palsu. VBT ditambal (3 byte), dimuat lewat `i915.vbt_firmware=i915/vbt-victus-fixed.bin` | [BERES] sejak 13 Nov. Tidak ada lagi error link training di 72 boot terakhir |
| 13 Nov | Upgrade BIOS F.34 gagal | — | Tidak dilanjutkan |

Kalau BIOS atau kernel nanti diupdate, VBT bisa berubah. Cek lagi sebelum tetap memakai tambalan. Cara undo ada di catatan Claude (`laptop-resume-black-screen.md`).

---

## 3. Lockscreen (Quickshell Matrix)

| Tanggal | Masalah | Tindakan | Status |
|---|---|---|---|
| 14 Nov | Sesudah sleep lama (3–6 jam) lockscreen berhenti menggambar, tidak bisa mengetik | `lock-watchdog.sh` mengecek heartbeat frame sesudah resume → restart lockscreen sekali → kalau masih gagal, pindah ke hyprlock | [AKALAN]. Penyebab di dalam Qt/Quickshell belum diketahui |
| 14 Nov | — | Suspend otomatis kalau terkunci ≥ 9 menit (`idle-suspend.sh 540`) | [BERES] |
| — | xdg-desktop-portal timeout tiap lockscreen start, swaync kadang mati | — | [TERBUKA] |

Darurat dari TTY (Ctrl+Alt+F3): `~/.config/hypr/UserScripts/lock-rescue.sh`

---

## 4. Insiden 18 Nov: layar hitam sesudah sleep, Ctrl+Alt+R tidak menolong

### Yang terjadi
1. 07:39:35 lid ditutup, HDMI masih tercolok → mode clamshell, layar laptop dimatikan (benar).
2. 07:39:41 HDMI dicabut. Hyprland jadi tanpa layar fisik, lalu membuat layar bayangan bernama `FALLBACK`.
   **Bug 1:** skrip lid (`user_laptops.lua`) menganggap `FALLBACK` sebagai monitor eksternal → layar laptop tetap dimatikan → laptop suspend.
3. Bangun, lid dibuka, tapi sesi terkunci.
   **Bug 2:** bind lid tidak punya `locked = true` → Hyprland mengabaikan event buka lid selama terkunci.
4. Hasil: lockscreen menggambar ke `FALLBACK` (tak terlihat), layar laptop tetap mati. Watchdog melihat frame tetap mengalir, jadi menganggapnya normal.
5. **Bug 3:** Ctrl+Alt+R juga tanpa `locked = true` (tidak jalan saat terkunci). Kalaupun jalan, `edp-reset.sh` cuma mematikan lalu menyalakan DPMS, tidak menyalakan layar yang statusnya *disabled*.
6. Bukan masalah driver: tidak ada error link training.

### Perbaikan
| File | Perubahan |
|---|---|
| `UserConfigs/user_laptops.lua` | `FALLBACK` tidak dihitung sebagai monitor eksternal; bind lid buka/tutup `{ locked = true }` |
| `UserConfigs/user_keybinds.lua` | Ctrl+Alt+R `locked = true` |
| `UserScripts/edp-reset.sh` | Menjalankan ulang layout monitor dulu (`apply_laptop_monitor_layout`), baru mematikan/menyalakan DPMS |

Terbukti: `hyprctl binds` → lid dan Ctrl+Alt+R `locked=True`, tidak ada error config.
**[BELUM DIUJI]** skenario aslinya. Uji sekali: colok HDMI → tutup lid → cabut HDMI → tunggu suspend → buka lid.
Harus muncul lockscreen di layar laptop. Kalau tetap hitam, tekan Ctrl+Alt+R.

### Temuan lain hari itu
- **Jam maju 7 jam sesudah resume** (08:11 tercatat 15:11). Jam hardware (RTC) disetel ke waktu lokal (`RTC in local TZ: yes`).
  Tidak menyebabkan layar hitam. Kalau tidak dual-boot Windows: `timedatectl set-local-rtc 0`. [TERBUKA]
- Waybar crash (segfault) sesudah resume, lalu restart otomatis. [TERBUKA], tidak berbahaya.
- **2026-11-19: Chrome/Brave "tidak kebuka" sesudah pilih profil.** Browser sebenarnya jalan, tapi window-nya
  tertinggal di workspace 11/13 (sisa monitor HDMI yang dicabut), jadi tidak kelihatan. Penyebab: `UserWs.gather`
  crash karena dropterm (`special:scratchpad`) punya id kosong. Sudah diperbaiki (`user_keybinds.lua`) + dijalankan ulang
  1,5 dtk sesudah HDMI dicabut. Darurat: `hyprctl eval 'UserWs.gather()'` atau SUPER+Tab. [SELESAI]
- **2026-11-19: spam `NVRM: Possible bad register read` ~1 menit sesudah resume** (~670 ribu baris, journald sampai buang
  pesan) → layar baru balik ~1 menit kemudian. Terjadi sekali: sesi NVIDIA-primary, HDMI dicabut menjelang lid ditutup,
  sleep 7 jam. Pesan `ACPI Error ... _Q33 ... SystemCMOS` saat resume = bug BIOS HP, aman. [PANTAU] Kalau terulang:
  sesudah cabut HDMI, logout-login dulu (balik Intel-primary) sebelum menutup lid.

---

## 5. Mode clamshell (lid tutup, monitor tetap nyala)
- Jalan: systemd-logind bawaan `HandleLidSwitchDocked=ignore` (ada monitor eksternal → tidak suspend), `user_laptops.lua` mematikan layar laptop.
- Layar laptop benar-benar dimatikan (bukan sekadar gelap) → tidak ada panas dari layar.
- Panas bodi: taruh di permukaan keras (ventilasi bawah/belakang), profile `balanced`. Pantau: `watch sensors`.
- Cabut HDMI saat lid tertutup → laptop suspend (ini perilaku yang diharapkan). Bug soal ini sudah diperbaiki di bagian 4.

---

## 6. Warning "launched without start-hyprland"
Muncul di log Hyprland. **Sengaja, aman diabaikan.**
Sesi yang dipilih di SDDM adalah **"Hyprland (direct)"**. Kalau memakai sesi "Hyprland" biasa (`start-hyprland`), Hyprland crash saat logout (bug aquamarine). Watchdog menganggapnya crash dan me-restart dalam safe mode, sehingga kamu tertahan di tty1.
Jangan pindah sesi sebelum bug itu diperbaiki di versi baru.

---

## 7. Video fullscreen di browser hitam (2026-11-21) [SELESAI]
- **Gejala:** video (GitLab, Netflix, dll) di Brave/Chrome normal di jendela, tapi begitu fullscreen layar hitam polos (tanpa "No Signal").
- **Penyebab:** saat fullscreen, Chromium di Wayland memindah video ke surface overlay terpisah. Hyprland yang jalan di NVIDIA
  tidak bisa menampilkan buffer itu → hitam. Di mode jendela video digabung ke frame browser, jadi kelihatan.
- **Perbaikan:** Brave dan Chrome dijalankan lewat XWayland (`--ozone-platform=x11`) via salinan launcher
  `~/.local/share/applications/brave-browser.desktop` dan `google-chrome.desktop`. Hapus file itu = balik ke launcher bawaan.
  Flag hanya berlaku kalau **semua** window browser ditutup dulu.
- **Ikut dibereskan:** fullscreen juga bikin HDMI modeset ulang (kedip hitam) karena `vrr = 2` dan `send_content_type`.
  Dua-duanya dimatikan di `UserConfigs/user_settings.lua`. Monitor HDMI lewat NVIDIA memang tidak mendukung VRR.

---

## Lokasi catatan lain
- `~/.config/hypr/CLAUDE.md`: ringkasan aturan untuk Claude (bahasa Inggris, padat).
- `~/.claude/projects/-home-mrrizaldi/memory/hyprland-hybrid-gpu.md` dan `laptop-resume-black-screen.md`: log debugging lengkap (Inggris, sangat teknis).
- Backup: `~/backups/`, `~/backup-hypr-waybar-20261112-2007`, `~/nvidia-595/`.
