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
# pacman aborts the WHOLE transaction over a single package it cannot find, so
# one entry that does not exist on this machine means nothing at all gets
# installed -- which is exactly what happened the first time this ran on a box
# without the multilib repo: ten unavailable names took the other 129 with
# them. Everything that is available is installed and the rest is reported.
#
# This also covers the case the lists cannot anticipate: a package renamed or
# dropped from the repos.
#
# WHY -Slq AND NOT -Si
# The first version of this asked `pacman -Si` for each package and read the
# name back out of the "Name : foo" line. That output is TRANSLATED: on a
# Spanish system the field is "Nombre", the match found nothing, and the script
# announced that all 129 packages were unavailable -- failing silently in the
# worst possible direction, since "skip it" is what it does with a package it
# cannot see. -Slq prints one package name per line and no field labels at all,
# so there is nothing left to translate. It costs one call and 0.13s for the
# ~15k names in the sync repos.
install_list() {
  local file="$1" label="$2" pkgs=() available=() missing=()

  mapfile -t pkgs < <(grep -v '^[[:space:]]*$' "$file")
  (( ${#pkgs[@]} )) || return 0

  mapfile -t available < <(
    comm -12 <(printf '%s\n' "${pkgs[@]}" | sort -u) <(pacman -Slq | sort -u))
  mapfile -t missing < <(
    comm -23 <(printf '%s\n' "${pkgs[@]}" | sort -u) <(printf '%s\n' "${available[@]}"))

  if (( ${#missing[@]} )); then
    red "   not available in your repos, skipped:"
    printf '     %s\n' "${missing[@]}"
  fi

  if (( ${#available[@]} == 0 )); then
    red "   nothing from $label could be installed"
    return 0
  fi

  # --needed skips the ones already installed.
  sudo pacman -S --needed "${available[@]}"
  green "   $label: ${#available[@]} package(s) handled"
}

blue "== 2/6  Packages from the official repos =="
echo "   $(wc -l < "$DOT/packages/pacman.txt") packages in packages/pacman.txt"
if ask "Install them (plus stow)?"; then
  sudo pacman -S --needed --noconfirm stow
  install_list "$DOT/packages/pacman.txt" "core"
fi

# --- 32-bit libraries and Steam -------------------------------------------
# Their own list because they need the multilib repo, which is off by default
# on Arch. Enabling it means editing /etc/pacman.conf, and this script does not
# touch /etc -- same rule as system/.
echo
echo "   packages/multilib.txt holds Steam and the 32-bit libraries."
if grep -q '^\[multilib\]' /etc/pacman.conf; then
  if ask "Install them?"; then
    install_list "$DOT/packages/multilib.txt" "multilib"
  fi
else
  echo "   The multilib repo is NOT enabled, so these are unavailable."
  echo "   To enable it, uncomment these two lines in /etc/pacman.conf:"
  echo
  echo "     [multilib]"
  echo "     Include = /etc/pacman.d/mirrorlist"
  echo
  echo "   then run 'sudo pacman -Sy' and this script again. Skipping for now."
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
  STOW_ARGS=(--no-folding -v -t "$HOME" -d "$DOT")

  # Simulated first. stow plans the whole operation and aborts the LOT on the
  # first conflict, so a single pre-existing file means not one link gets made
  # -- and the usual culprit is there on any machine that has run Hyprland
  # once, because it writes a default config into ~/.config/hypr itself.
  #
  # -n also means the list below is complete: every conflict across every
  # package, found without having touched anything yet.
  conflicts=()
  mapfile -t conflicts < <(
    stow "${STOW_ARGS[@]}" -n "${PACKAGES[@]}" 2>&1 |
      sed -n 's/^.*cannot stow .* over existing target \(.*\) since .*$/\1/p')

  if (( ${#conflicts[@]} )); then
    red "   ${#conflicts[@]} file(s) are in the way, and stow will not touch them:"
    printf '     ~/%s\n' "${conflicts[@]}"
    echo
    echo "   They can be MOVED (not deleted) into a timestamped folder, and the"
    echo "   repo's versions linked in their place. Nothing is overwritten and"
    echo "   you can put any of them back afterwards."
    echo
    echo "   The other way round is 'stow --adopt', which keeps YOUR files and"
    echo "   overwrites the repo's copies with them. This script will not do"
    echo "   that for you: it edits the repo, and a git checkout is the way back."

    BACKUP="$HOME/dotfiles-replaced-$(date +%Y%m%d-%H%M%S)"
    if ask "Move them to $BACKUP and carry on?"; then
      for rel in "${conflicts[@]}"; do
        mkdir -p "$BACKUP/$(dirname "$rel")"
        mv "$HOME/$rel" "$BACKUP/$rel"
      done
      green "   moved ${#conflicts[@]} file(s) to $BACKUP"
    else
      red "   nothing linked. Move them by hand and run this again."
      exit 1
    fi
  fi

  if ! stow "${STOW_ARGS[@]}" "${PACKAGES[@]}"; then
    red "   stow failed even after clearing the conflicts above."
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
# Monitors. NOT rewritten automatically, and that is deliberate: which screen
# is the main one, where the others sit around it and whether any is rotated is
# a layout decision, not something to guess from an EDID. What can be done for
# you is the mechanical half -- reading the descriptions off the hardware that
# is actually plugged in, and saying whether the ones in the config match it.
echo
blue "== Monitors =="
HYPR_CONF="$HOME/.config/hypr/hyprland.lua"
if ! command -v hyprctl >/dev/null || ! hyprctl monitors -j >/dev/null 2>&1; then
  echo "   Hyprland is not running, so the monitors cannot be read."
  echo "   Log in and re-run this script, or edit the block by hand."
elif [[ ! -f $HYPR_CONF ]]; then
  echo "   $HYPR_CONF not found — run step 4 (stow) first."
else
  # Every description the config names, and whether it is attached right now.
  MISSING=0
  while IFS= read -r desc; do
    if hyprctl monitors -j | jq -e --arg d "$desc" 'any(.description == $d)' >/dev/null; then
      green "   attached: $desc"
    else
      red   "   NOT attached: $desc"
      MISSING=1
    fi
  done < <(grep -oP 'desc:\K[^"]+' "$HYPR_CONF" | sort -u)

  if (( MISSING )); then
    echo
    echo "   The lines below describe the monitors on THIS machine. Put the"
    echo "   descriptions into the MONITOR_* variables at the top of"
    echo "   hyprland.lua, then check mode/position/transform underneath:"
    echo
    # width/height are the PANEL's, before rotation: a monitor turned on its
    # side still reports 1920x1080. `transform` is what says which way it faces.
    hyprctl monitors -j | jq -r '.[] |
      "     desc:\(.description)\n       \(.width)x\(.height)@\(.refreshRate|round)  " +
      (if (.transform % 2) == 1 then "rotated, transform = \(.transform)"
       elif .width > .height then "landscape"
       else "portrait panel" end)'
    echo
    echo "   Everything else adapts on its own: the shell picks its screen at"
    echo "   runtime (quickshell/Screens.qml) and gamescope reads the mode off"
    echo "   whichever monitor you are on."
  else
    green "   the config matches the hardware, nothing to change"
  fi
fi

# ---------------------------------------------------------------------------
echo
green "== Ready =="
cat <<'END'

Left to do by hand:

  1. /etc  — see system/ and the table in the README. The fstab UUIDs belong
             to the original machine: do NOT copy it as is.
  2. Monitors — the layout block in hyprland.lua, if the check above said so.
  3. The GPU driver. Deliberately not installed by this script: it is the one
             thing that depends on hardware nothing here can see, and a driver
             for a card you do not have is not a harmless mistake.
  4. zsh as the default shell, if it is not already:
             chsh -s /usr/bin/zsh
END
