#!/usr/bin/env bash
# Rebuild this machine's setup on Debian 13. Steps run in the order given; no args = --link.
#   --system    copy system/root/ into / (apt repos + keyrings, nvidia-drm, i915 VBT), i386 arch
#   --packages  apt install packages/apt.txt
#   --kool      clone the pinned Debian-Hyprland installer (run its install.sh yourself)
#   --link      stow home/* into ~ (repo wins), clone shell/editor frameworks, enable user units
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
REPO=$PWD
. ./upstream.env

clone() { [ -d "$2" ] || git clone --depth 1 "$1" "$2"; }

do_system() {
  sudo dpkg --add-architecture i386
  sudo cp -r --preserve=mode system/root/. /
  sudo update-initramfs -u
  grep -q 'i915.vbt_firmware' /etc/default/grub || cat <<'EOF'
!! Add to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub, then: sudo update-grub
   nvidia-drm.modeset=1 i915.enable_psr=0 intel_iommu=off i915.vbt_firmware=i915/vbt-victus-fixed.bin
EOF
}

do_packages() {
  sudo apt update
  grep -v '^#' packages/apt.txt | xargs sudo apt install -y
  echo "Manual .debs: packages/manual-debs.md"
}

do_kool() {
  local dir=~/Debian-Hyprland-LB
  clone "$DEBIAN_HYPRLAND_REPO" "$dir" && git -C "$dir" fetch --depth 1 origin "$DEBIAN_HYPRLAND_REF" \
    && git -C "$dir" checkout -q FETCH_HEAD
  echo "Now run: cd $dir && ./install.sh   (then re-run ./bootstrap.sh --link)"
}

do_link() {
  # ponytail: --adopt pulls live files into the repo, checkout puts the repo version back.
  # That is only safe when home/ has no uncommitted work.
  if [ -n "$(git status --porcelain home)" ]; then
    echo "home/ has uncommitted changes; commit or stash them first." >&2; exit 1
  fi
  local pkgs; pkgs=$(ls home)
  # shellcheck disable=SC2086
  stow --no-folding --adopt -d home -t ~ $pkgs
  git checkout -- home

  clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
  local zc=~/.oh-my-zsh/custom
  clone https://github.com/zsh-users/zsh-autosuggestions "$zc/plugins/zsh-autosuggestions"
  clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zc/plugins/zsh-syntax-highlighting"
  clone https://github.com/romkatv/powerlevel10k.git "$zc/themes/powerlevel10k"
  clone https://github.com/gpakosz/.tmux.git ~/.config/tmux/oh-my-tmux
  ln -sfn ~/.config/tmux/oh-my-tmux/.tmux.conf ~/.config/tmux/tmux.conf
  clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
  clone "$NVIM_REPO" ~/.config/nvim

  local wb=~/.config/hypr/waybar
  ln -sfn "configs/[TOP] Default Laptop (per-monitor)" "$wb/config"
  ln -sfn "$wb/style/[Extra] ML4W starter.css" "$wb/style.css"

  local m=~/.config/hypr/hyprlock-matrix
  if [ ! -d "$m/rain" ] && command -v magick >/dev/null; then python3 "$m/gen.py"; fi

  systemctl --user daemon-reload && systemctl --user enable polkit-agent.service \
    || echo "systemd --user not reachable; enable polkit-agent.service later."

  [ -f ~/.config/shell/secrets.sh ] || echo "Create ~/.config/shell/secrets.sh (chmod 600) for API keys."
  echo "Linked: $pkgs (from $REPO/home)"
}

[ $# -eq 0 ] && set -- --link
for a in "$@"; do
  case $a in
    --system) do_system ;; --packages) do_packages ;; --kool) do_kool ;; --link) do_link ;;
    *) sed -n '2,7p' "$0"; exit 1 ;;
  esac
done
