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
# Every stow package. seeds/ is deliberately NOT one of them -- it is copied,
# not linked, see seeds/README.md and the seed step below. There is no `qt` or
# `xdg` package any more either: qt6ct.conf and mimeapps.list were all they
# held, and both are seeds now.
PACKAGES=(zsh hypr quickshell kitty matugen shell gtk media openrgb systemd bin ranger icons zen)

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

blue "== 1/6  Packages from the official repos =="
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
blue "== 2/6  AUR packages =="
# Everything from here to the end of the block is best-effort on purpose. An
# AUR package that fails to build is a normal Tuesday, and with `set -e` a bare
# failing command here would take the whole script down BEFORE the stow step --
# losing the configuration linking, which is the part that actually matters --
# over one PKGBUILD. Same rule as install_list: do what can be done, report the
# rest.
if ask "Install yay and the ones in packages/aur.txt?"; then
  if ! command -v yay >/dev/null; then
    sudo pacman -S --needed --noconfirm git base-devel
    tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay" &&
       ( cd "$tmp/yay" && makepkg -si --noconfirm ); then
      green "   yay installed"
    else
      red "   yay could not be built, the AUR list is skipped"
    fi
    rm -rf "$tmp"
  fi

  if command -v yay >/dev/null; then
    # yay installs itself, dropping it from the list keeps it from rebuilding.
    # grep exits 1 when nothing is left after that, and with `set -o pipefail`
    # that alone would abort the script, so it is caught here.
    aur="$(grep -v '^yay$' "$DOT/packages/aur.txt" || true)"
    if [[ -z $aur ]]; then
      green "   nothing in the list beyond yay itself"
    elif yay -S --needed - <<<"$aur"; then
      green "   done"
    else
      red "   some AUR packages failed, see the output above"
    fi
  fi
fi

# ---------------------------------------------------------------------------
blue "== 3/6  Link the configuration (stow) =="
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
  #
  # THREE MESSAGES, NOT ONE. stow reports a conflict in one of several
  # wordings, and reading only the "cannot stow ... over existing target"
  # one -- a plain file in the way -- was a real hole: a dotfile that is
  # already a SYMLINK elsewhere (another clone of this repo at a different
  # path, a previous dotfiles manager) produces "existing target is not owned
  # by stow" instead, which matched nothing, so the script announced zero
  # conflicts and then died on the real run with "failed even after clearing
  # the conflicts above" -- a lie, and no way forward from it. All three
  # wordings below name a single file or link, which is what makes moving
  # them safe. Anything else stow may complain about is deliberately NOT
  # guessed at: it is printed as it came and the run stops.
  #
  # `|| true` because stow exits non-zero precisely when it has something to
  # report, which is the case this is here to handle.
  stow_out="$(stow "${STOW_ARGS[@]}" -n "${PACKAGES[@]}" 2>&1 || true)"
  conflicts=() unhandled=()
  mapfile -t conflicts < <(sed -n \
    -e 's/^.*cannot stow .* over existing target \(.*\) since .*$/\1/p' \
    -e 's/^.*existing target is not owned by stow: \(.*\)$/\1/p' \
    -e 's/^.*existing target is stowed to a different package: \(.*\) => .*$/\1/p' \
    <<<"$stow_out" | sort -u)
  mapfile -t unhandled < <(grep -E '^\s*\*' <<<"$stow_out" |
    grep -vE 'cannot stow .* over existing target .* since |existing target is (not owned by stow|stowed to a different package)')

  if (( ${#unhandled[@]} )); then
    red "   stow reports something this script will not touch on its own:"
    printf '   %s\n' "${unhandled[@]}"
    echo "   Sort it out by hand and run this again."
    exit 1
  fi

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
  #
  # None of it is fatal, and that is the point: `systemctl --user` needs a
  # running user manager, which there is not one of inside a chroot or over a
  # plain SSH session with no lingering enabled. The links are already made by
  # now, and losing the seeds, the palette and the closing notes over a timer
  # that can be enabled later is a bad trade. Whatever fails is said out loud.
  if ! { systemctl --user daemon-reload &&
         systemctl --user enable --now wallpaper-rotate.timer; }; then
    red "   the wallpaper timer could not be enabled (no user session?)"
    echo "   Once logged in: systemctl --user enable --now wallpaper-rotate.timer"
  fi
  # Best-effort on its own line: the unit belongs to the hyprpolkitagent
  # package, which is not there if step 1 was skipped.
  systemctl --user enable --now hyprpolkitagent.service 2>/dev/null || true
  green "   done"
fi

# ---------------------------------------------------------------------------
# Seeds: the files that CANNOT be symlinks, because the applications that own
# them rewrite them. qt6ct rewrites qt6ct.conf in full on every save -- it has
# already eaten the nine-line comment above color_scheme_path, URL-encoding it
# into one line, and it keeps the settings window's geometry in there -- and
# mimeapps.list is rewritten by anything that claims a default handler. Linked
# into the repo that meant a permanently dirty tree on every machine and a
# collision on every pull. So they are copied ONCE and belong to the machine
# afterwards. See seeds/README.md.
#
# After the stow step, deliberately: stow is what creates ~/.config, and the
# destination must not be a link before anything is written to it.
#
# Nothing here overwrites. -e alone is not enough to decide that: a machine
# upgraded from the version that STOWED these still has a symlink pointing at
# a repo file that no longer exists, and -e follows the link, so a dangling one
# reads as "nothing there" and falls into the cp branch. GNU cp then refuses
# ("not writing through dangling symlink") and, under `set -e`, takes the rest
# of the script with it -- over a link the user can delete in one command, and
# without ever saying which link it was. -L catches it first and says so.
blue "== 4/6  Seed the files the applications rewrite =="
echo "   seeds/ -> \$HOME, and only where there is nothing already"
if ask "Copy the missing ones?"; then
  seeded=0
  for pair in "qt6ct.conf:$HOME/.config/qt6ct/qt6ct.conf" \
              "mimeapps.list:$HOME/.config/mimeapps.list"; do
    src="$DOT/seeds/${pair%%:*}"
    dst="${pair#*:}"
    if [[ -L $dst && ! -e $dst ]]; then
      red "   $dst is a dangling symlink"
      echo "     It pointed at the repo copy that is now a seed. Delete it and"
      echo "     re-run this step; it is not removed for you, in case you made it."
    elif [[ -e $dst || -L $dst ]]; then
      echo "   $dst already exists, left alone"
    else
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      green "   seeded $dst"
      seeded=$(( seeded + 1 ))
    fi
  done
  green "   done, $seeded file(s) copied"
fi

# ---------------------------------------------------------------------------
blue "== 5/6  Neovim (separate repo) =="
if [[ -e "$HOME/.config/nvim" ]]; then
  echo "   ~/.config/nvim already exists, leaving it alone"
elif ask "Clone Johanx22x/nvim into ~/.config/nvim?"; then
  # Not fatal: no network, or no git if step 1 was skipped. Everything after
  # this step is worth running anyway.
  if git clone https://github.com/Johanx22x/nvim.git "$HOME/.config/nvim"; then
    green "   done"
  else
    red "   the clone failed, ~/.config/nvim is not set up"
  fi
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
  elif [[ ! -x $HOME/.local/bin/wallpaper-switch ]]; then
    # It is stowed by step 3, so this only shows up when that step was skipped.
    # Checked rather than run blindly: a missing command is exit 127, and under
    # `set -e` that would end the script here, before the monitor check and the
    # notes below it.
    red "   ~/.local/bin/wallpaper-switch is missing — run step 3 (stow) first."
  else
    # matugen, awww and a running Hyprland all have to be there for this to
    # work. If one is not, say so and carry on: it is one command to re-run.
    if "$HOME/.local/bin/wallpaper-switch" random; then
      green "   done"
    else
      red "   the palette could not be generated. Once logged into Hyprland,"
      echo "   run: wallpaper-switch random"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Monitors. NOT rewritten automatically, and that is deliberate: which screen
# is the main one, where the others sit around it and whether any is rotated is
# a layout decision, not something to guess from an EDID. What can be done for
# you is the mechanical half -- reading the descriptions and modes off the
# hardware that is actually plugged in, and saying whether the configuration
# already knows about each screen.
#
# TWO FILES NAME MONITORS, and a check that reads only one of them is wrong.
# hyprland.lua carries the hand-written block for the machine this repo was set
# up on: tracked, commented, and NOT where a second machine should record its
# own screens -- editing a tracked file is what leaves a clone permanently
# dirty and turns every pull into a conflict. On top of that block hyprland.lua
# dofile()s ~/.config/hypr/monitors.lua, which the `hypr-monitor` script
# generates and .gitignore keeps out of the repo, and a later hl.monitor for
# the same output wins. So a machine set up the current way names its screens
# ONLY there, and grepping hyprland.lua alone would report it as broken.
#
# Which is why the question below is asked of the HARDWARE and not of the file:
# for each monitor actually attached, does either file name it? One that
# neither names still lights up -- the fallback rule at the end of the block
# gives it preferred mode and automatic position -- it just sits wherever
# Hyprland decided to put it, at whatever refresh rate.
echo
blue "== Monitors =="
HYPR_CONF="$HOME/.config/hypr/hyprland.lua"
HYPR_OVERRIDES="$HOME/.config/hypr/monitors.lua"
if ! command -v hyprctl >/dev/null || ! hyprctl monitors -j >/dev/null 2>&1; then
  echo "   Hyprland is not running, so the monitors cannot be read."
  echo "   Log in and re-run this script, or run 'hypr-monitor' by hand."
elif ! command -v jq >/dev/null; then
  # Everything below reads hyprctl's JSON through jq. Said here rather than
  # discovered halfway down, where a missing jq would abort the script under
  # `set -e` and take the closing notes with it.
  echo "   jq is not installed, so the monitors cannot be read."
  echo "   It is in packages/pacman.txt: install it and re-run this script."
elif [[ ! -f $HYPR_CONF ]]; then
  echo "   $HYPR_CONF not found — run step 3 (stow) first."
else
  # Read once: hyprctl is talking to a live compositor over a socket.
  MONITORS_JSON="$(hyprctl monitors -j)"

  # The descriptions each file names. hyprland.lua writes them "desc:like
  # this" and hypr-monitor generates them 'desc:like this', so both quotes end
  # the match. They are kept apart because they mean different things: one is
  # this repo's own machine, the other is what THIS machine has recorded.
  NAMED=() OVERRIDDEN=()
  mapfile -t NAMED < <(grep -ohP "desc:\K[^\"']+" "$HYPR_CONF" | sort -u)
  if [[ -f $HYPR_OVERRIDES ]]; then
    mapfile -t OVERRIDDEN < <(grep -ohP "desc:\K[^\"']+" "$HYPR_OVERRIDES" | sort -u)
  fi

  # Descriptions carry spaces ("GIGA-BYTE TECHNOLOGY CO. LTD. GS27FA ..."), so
  # membership is compared element by element and never through word splitting.
  in_list() {
    local needle="$1" item
    shift
    for item in "$@"; do
      if [[ $item == "$needle" ]]; then return 0; fi
    done
    return 1
  }

  UNCONFIGURED=0
  while IFS= read -r desc; do
    if in_list "$desc" "${OVERRIDDEN[@]}"; then
      green "   configured here (monitors.lua): $desc"
    elif in_list "$desc" "${NAMED[@]}"; then
      green "   configured in hyprland.lua:     $desc"
    else
      red   "   not in the configuration:       $desc"
      UNCONFIGURED=1
    fi
  done < <(jq -r '.[].description' <<<"$MONITORS_JSON")

  if (( UNCONFIGURED )); then
    echo
    echo "   Those screens work -- the fallback rule gives them preferred mode"
    echo "   and automatic position -- but nothing places them or sets a rate."
    echo
    echo "   Below is every attached monitor as Hyprland sees it right now,"
    echo "   with the command that records it. Run the one you want, after"
    echo "   arranging the screens the way you like them:"
    echo
    # width/height are the PANEL's, before rotation: a monitor turned on its
    # side still reports 1920x1080, and that is also the form `mode` wants.
    # `transform` is what says which way it faces. The scale is rounded to two
    # decimals because the compositor reports a float and 1.2 comes back as
    # 1.2000000476837158.
    jq -r '.[] |
      "     \(.description)\n       " +
      (if (.transform % 2) == 1 then "rotated panel, transform \(.transform)"
       elif .width > .height then "landscape"
       else "portrait panel" end) + "\n" +
      "       hypr-monitor set \"\(.description)\" \(.width)x\(.height)@\(.refreshRate|round) \(.x)x\(.y) \(.scale*100|round/100) \(.transform)"' \
      <<<"$MONITORS_JSON"
    echo
    echo "   The settings window (SUPER + C) does the same thing from a display"
    echo "   page that applies the change live and puts it back unless you"
    echo "   confirm it. Either way it lands in monitors.lua, which is"
    echo "   generated and gitignored. Do NOT put the descriptions into the"
    echo "   MONITOR_* variables in hyprland.lua: that file is tracked, and the"
    echo "   override layer exists precisely so no machine has to edit it."
    echo
    echo "   Everything else adapts on its own: the shell picks its screen at"
    echo "   runtime (quickshell/Screens.qml) and gamescope reads the mode off"
    echo "   whichever monitor you are on."
  else
    green "   every attached monitor is accounted for, nothing to change"
  fi
fi

# ---------------------------------------------------------------------------
echo
green "== Ready =="
cat <<'END'

Left to do by hand:

  1. /etc  — see system/ and the table in the README. The fstab UUIDs belong
             to the original machine: do NOT copy it as is.
  2. Monitors — if the check above listed a screen as not configured, record
             it with 'hypr-monitor set ...' (the command is printed for you)
             or from the settings window, SUPER + C. That writes
             ~/.config/hypr/monitors.lua, which is generated and gitignored;
             hyprland.lua is tracked and does not need editing.
  3. The GPU driver. Deliberately not installed by this script: it is the one
             thing that depends on hardware nothing here can see, and a driver
             for a card you do not have is not a harmless mistake.
  4. zsh as the default shell, if it is not already:
             chsh -s /usr/bin/zsh
END
