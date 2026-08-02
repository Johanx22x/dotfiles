#!/usr/bin/env bash
# Replicates this setup on a clean Arch machine.
#
# Idempotent: it can be re-run. It asks before each block, so it can be used
# to apply only part of it.
#
# It does NOT touch /etc: that is done by hand, see system/ and the main
# README.
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(zsh hypr quickshell kitty matugen shell qt gtk media openrgb systemd bin ranger icons xdg)

blue()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
green() { printf '\033[1;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[1;31m%s\033[0m\n' "$*"; }

ask() {
  local r
  read -rp "$(printf '\033[1;33m%s\033[0m [y/N] ' "$1")" r
  [[ "$r" =~ ^[yYsS]$ ]]
}

[[ -f /etc/arch-release ]] || { red "This is for Arch Linux."; exit 1; }
[[ $EUID -eq 0 ]] && { red "Do not run it as root. It asks for sudo when it needs it."; exit 1; }

# ---------------------------------------------------------------------------
# Done BEFORE linking: if you link first, the rewrite would have to follow the
# symlinks and it is easy to leave half the files done.
blue "== 1/6  Absolute paths =="
ORIGINAL="/home/johan"
if [[ "$HOME" == "$ORIGINAL" ]]; then
  echo "   home matches, nothing to rewrite"
else
  # matugen does NOT expand ~ in output_path, so the absolute path is
  # mandatory there; same in a few scripts.
  # That is why the repo carries fixed paths and they have to be adapted on
  # cloning.
  # This script itself is excluded: rewriting its ORIGINAL would leave the
  # check above comparing the new home against itself.
  find_paths() { grep -rl "$ORIGINAL" "$DOT" --exclude-dir=.git --exclude=install.sh --exclude=README.md 2>/dev/null || true; }
  mapfile -t WITH_PATH < <(find_paths)
  if (( ${#WITH_PATH[@]} == 0 )); then
    echo "   already rewritten"
  else
    echo "   ${#WITH_PATH[@]} files point at $ORIGINAL and will be rewritten to $HOME:"
    printf '     %s\n' "${WITH_PATH[@]#$DOT/}"
    if ask "Rewrite them?"; then
      sed -i "s|$ORIGINAL|$HOME|g" "${WITH_PATH[@]}"
      # Check, because a silent half-done sed is worse than not doing it
      left=$(find_paths | wc -l)
      if (( left )); then
        red "   $left files were left unrewritten"; exit 1
      fi
      green "   done — they will show up as changes in git, which is expected"
    else
      red "   without this matugen will write to $ORIGINAL and nothing gets coloured"
    fi
  fi
fi

# ---------------------------------------------------------------------------
blue "== 2/6  Packages from the official repos =="
echo "   $(wc -l < "$DOT/packages/pacman.txt") packages in packages/pacman.txt"
if ask "Install them (plus stow)?"; then
  sudo pacman -S --needed --noconfirm stow
  # --needed skips the ones already installed; < feeds the list to stdin
  sudo pacman -S --needed - < "$DOT/packages/pacman.txt"
  green "   done"
fi

# ---------------------------------------------------------------------------
blue "== 3/6  AUR packages =="
if ask "Install yay and the ones in packages/aur.txt?"; then
  if ! command -v yay >/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
    ( cd "$tmp/yay" && makepkg -si --noconfirm )
    rm -rf "$tmp"
  fi
  # yay installs itself, dropping it from the list keeps it from rebuilding
  grep -v '^yay$' "$DOT/packages/aur.txt" | yay -S --needed -
  green "   done"
fi

# ---------------------------------------------------------------------------
blue "== 4/6  Link the configuration (stow) =="
echo "   packages: ${PACKAGES[*]}"
if ask "Link them?"; then
  command -v stow >/dev/null || { red "   stow is missing"; exit 1; }
  # --no-folding: creates real directories and links file by file, instead of
  # linking the whole directory. That way an app writing a new file into
  # ~/.config/something does not drop it inside the repo by accident.
  if ! stow --no-folding -v -t "$HOME" -d "$DOT" "${PACKAGES[@]}"; then
    red "   stow found conflicts: those files already exist."
    echo "   Check what they are and move them, or re-run with --adopt so stow"
    echo "   absorbs them into the repo (CAREFUL: that overwrites the repo copy)."
    exit 1
  fi
  # The *.target.wants links are not versioned (they point at absolute paths
  # of the original home and would dangle for another user). Recreated here.
  systemctl --user daemon-reload
  systemctl --user enable --now wallpaper-rotate.timer
  systemctl --user enable --now hyprpolkitagent.service 2>/dev/null || true
  green "   done"
fi

# ---------------------------------------------------------------------------
blue "== 5/6  Neovim (separate repo) =="
if [[ -e "$HOME/.config/nvim" ]]; then
  echo "   ~/.config/nvim already exists, leaving it alone"
elif ask "Clone Johanx22x/nvim into ~/.config/nvim?"; then
  git clone https://github.com/Johanx22x/nvim.git "$HOME/.config/nvim"
  green "   done"
fi

# ---------------------------------------------------------------------------
blue "== 6/6  Generate the colour palette =="
echo "   Without this, colors.css, colors.lua, gtk.css... are missing and"
echo "   several apps come up grey. Needs at least one image in"
echo "   ~/Pictures/wallpapers."
if ask "Generate it now?"; then
  mkdir -p "$HOME/Pictures/wallpapers"
  if ! find -L "$HOME/Pictures/wallpapers" -maxdepth 2 -type f \
       \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
       | grep -q .; then
    red "   No images in ~/Pictures/wallpapers."
    echo "   Drop one in and then run: wallpaper-switch random"
  else
    "$HOME/.local/bin/wallpaper-switch" random
    green "   done"
  fi
fi

# ---------------------------------------------------------------------------
echo
green "== Ready =="
cat <<'END'

Left to do by hand:

  1. /etc  — see system/ and the table in the README. The fstab UUIDs belong
             to the original machine: do NOT copy it as is.
  2. Monitors — hyprland.lua matches them by EDID description. On another
             machine that block has to be adjusted.
  3. zsh as the default shell, if it is not already:
             chsh -s /usr/bin/zsh
END
