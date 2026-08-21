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
# Every stow package EXCEPT the compositor's, which is chosen below and
# appended. seeds/ is deliberately NOT one of them -- it is copied, not linked,
# see seeds/README.md and the seed step below. There is no `qt` or `xdg` package
# any more either: qt6ct.conf and mimeapps.list were all they held, and both are
# seeds now.
PACKAGES=(zsh quickshell kitty matugen shell gtk media openrgb systemd bin ranger icons zen gaming)

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
# THE COMPOSITOR. Asked first because it decides two later steps -- which
# packages get installed and which configuration gets linked -- and asking it
# halfway down would mean backtracking.
#
# Hyprland is the default and the one everything else in this repo was built
# against. niri is a second flavor: the same keybinds, the same shell, the same
# scripts, on a scrollable-tiling compositor instead of a dynamic-tiling one.
# See niri/.config/niri/config.kdl for what is identical and what cannot be.
#
# BOTH IS A REAL ANSWER AND NOT A HEDGE. The two stow packages touch different
# directories (~/.config/hypr and ~/.config/niri), the two sessions appear
# separately in the display manager, and neither knows the other exists -- so
# "both" costs one extra directory and buys the ability to try the second one
# without dismantling the first. That is the only way to answer the question
# these dotfiles cannot answer for anybody: whether scrollable tiling suits the
# hands attached to this keyboard.
#
# Answered with a number rather than y/N because there are three of them, and
# read with a default so a bare Enter is the safe path -- the same shape yay
# uses for its own prompts, which is where the muscle memory already is.
blue "== Compositor =="
echo "   1) Hyprland  (default)"
echo "   2) niri"
echo "   3) Both"
echo
COMPOSITOR=""
while [[ -z $COMPOSITOR ]]; do
  read -rp "$(printf '\033[1;33m==> Choose one [1]: \033[0m')" choice
  # A bare Enter is 1. Anything unrecognised asks again instead of guessing:
  # this decides what gets linked into $HOME, and a typo that silently meant
  # "both" would leave a session in the display manager nobody asked for.
  case "${choice:-1}" in
    1) COMPOSITOR="hyprland" ;;
    2) COMPOSITOR="niri" ;;
    3) COMPOSITOR="both" ;;
    *) red "   Not one of 1, 2 or 3." ;;
  esac
done

case "$COMPOSITOR" in
  hyprland) PACKAGES+=(hypr) ;;
  niri)     PACKAGES+=(niri) ;;
  both)     PACKAGES+=(hypr niri) ;;
esac
green "   $COMPOSITOR"

# Used by the steps below to ask "is this flavor in play?" without repeating
# the case statement four times.
want_hyprland() { [[ $COMPOSITOR == hyprland || $COMPOSITOR == both ]]; }
want_niri()     { [[ $COMPOSITOR == niri     || $COMPOSITOR == both ]]; }

# ---------------------------------------------------------------------------
# READING A LIST. The files under packages/ are grouped by PURPOSE -- what the
# entry is there to do -- and not by where it comes from, because "which
# repository is gimp in" is a question the machine can answer and nobody should
# have to keep in their head. Each list carries a header saying what the group
# is for and why the awkward entries are in it, so comments and blank lines are
# stripped before the names are used.
#
# The comment strip runs to end of line rather than only on whole lines: a
# pacman package name cannot contain '#', so there is nothing to lose by it and
# it means a note can sit beside the name it is about.
read_list() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1"
}

# ---------------------------------------------------------------------------
# WHERE EACH NAME COMES FROM. The lists say what the machine needs; working out
# where to get it is this script's job. There are three answers -- a configured
# pacman repository, the AUR, or [multilib] on a machine that has not enabled
# it -- and only the first two can be acted on.
#
# WHY `pacman -Sl` AND NOT `pacman -Si`
# The first version of this asked `pacman -Si` for each package and read the
# name back out of the "Name : foo" line. That output is TRANSLATED: on a
# Spanish system the field is "Nombre", the match found nothing, and the script
# announced that all 129 packages were unavailable -- failing silently in the
# worst possible direction, since "skip it" is what it does with a package it
# cannot see. `pacman -Sl` prints "<repo> <name> <version>" with no field
# labels at all, so there is nothing left to translate, and it hands over the
# repository name for free. One call, 0.13s for the ~15k names in the repos.
declare -A PKG_REPO=()

load_repo_index() {
  local repo name rest
  while read -r repo name rest; do
    PKG_REPO["$name"]="$repo"
  done < <(pacman -Sl 2>/dev/null)

  # EMPTY SYNC DATABASES READ AS "NOTHING EXISTS ANYWHERE", and that is exactly
  # the machine this script is written for. A box that has never run
  # `pacman -Sy` prints nothing here, every single name falls through to the
  # AUR branch, and yay is asked to build the whole desktop from source. The
  # version of this that compared against `pacman -Slq` had the same hole and
  # was quieter about it: it reported all 129 packages as unavailable, skipped
  # them, and carried on to the stow step as if nothing had happened.
  if (( ${#PKG_REPO[@]} == 0 )); then
    red "   pacman knows of no packages at all -- the sync databases are empty."
    echo "   Run 'sudo pacman -Sy' and then this script again."
    return 1
  fi
}

# Is [multilib] switched on? Asked once, because the answer changes what an
# unresolved lib32-* name means.
MULTILIB_ON=0
grep -q '^\[multilib\]' /etc/pacman.conf && MULTILIB_ON=1

# A DISABLED REPOSITORY IS NOT IN `pacman -Sl` EITHER, so once [multilib] is
# off its packages are indistinguishable from names that only exist in the AUR.
# The rule below is a heuristic and is written down as one: everything 32-bit
# is called lib32-*, and the Steam client is a 32-bit binary, which is the
# entire reason [multilib] is in play on this machine at all. A multilib
# package that is neither would be handed to yay and reported as an AUR build
# that failed -- loudly, and with the name in the message, which is a long way
# from silence.
needs_multilib() {
  [[ $1 == lib32-* || $1 == steam ]]
}

# Collected as the run goes and printed once at the end. A package that cannot
# be installed is not a reason to skip the stow step, which is the part that
# actually matters -- but it is a reason to say so where it will still be on
# screen when the script finishes.
FAILED=()

# yay builds itself from source the first time, which needs git and base-devel
# and a few minutes. Only called when something in a list actually turns out to
# come from the AUR.
ensure_yay() {
  command -v yay >/dev/null && return 0

  local tmp built=1
  sudo pacman -S --needed --noconfirm git base-devel
  tmp="$(mktemp -d)"
  if git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay" &&
     ( cd "$tmp/yay" && makepkg -si --noconfirm ); then
    green "   yay installed"
    built=0
  else
    red "   yay could not be built, the AUR packages are skipped"
  fi
  rm -rf "$tmp"
  return $built
}

# ---------------------------------------------------------------------------
# INSTALL A SET OF NAMES, wherever each of them lives. Takes a label for the
# messages and the names themselves.
#
# NOTHING IN HERE IS ALLOWED TO END THE SCRIPT. Under `set -e` a function that
# returns non-zero inside an `if` body takes the whole run down with it, and
# every caller below sits inside one -- so a single package dropped from the
# repositories used to mean no symlinks, no seeds and no palette. Every
# fallible command is tested rather than run bare, and what went wrong goes
# into FAILED to be reported at the end.
install_names() {
  local label="$1"; shift
  local names=("$@") repo=() aur=() blocked=() n

  (( ${#names[@]} )) || return 0

  for n in "${names[@]}"; do
    if [[ -n ${PKG_REPO[$n]:-} ]]; then
      repo+=("$n")
    elif (( ! MULTILIB_ON )) && needs_multilib "$n"; then
      blocked+=("$n")
    else
      aur+=("$n")
    fi
  done

  if (( ${#blocked[@]} )); then
    red "   $label: ${#blocked[@]} package(s) need [multilib], which is not enabled:"
    printf '     %s\n' "${blocked[@]}"
    echo "     Uncomment these two lines in /etc/pacman.conf, run 'sudo pacman -Sy',"
    echo "     and this script again:"
    echo
    echo "       [multilib]"
    echo "       Include = /etc/pacman.d/mirrorlist"
    echo
    FAILED+=("$label: ${blocked[*]} (needs [multilib])")
  fi

  # --needed skips the ones that are already installed, which is what makes
  # re-running this script cheap.
  if (( ${#repo[@]} )); then
    if sudo pacman -S --needed "${repo[@]}"; then
      green "   $label: ${#repo[@]} package(s) from the repositories"
    else
      red "   $label: pacman did not finish, see the output above"
      FAILED+=("$label: pacman failed")
    fi
  fi

  if (( ${#aur[@]} )); then
    echo "   $label: ${#aur[@]} package(s) come from the AUR"
    if ensure_yay; then
      # THE NAMES GO AS ARGUMENTS AND NOT DOWN STDIN. `yay -S --needed -` reads
      # the list from stdin, and then reads its own prompts -- which provider,
      # edit the PKGBUILD, proceed with the build -- from the same stdin, which
      # by then is at end of file. The answers it got were whatever was left of
      # the list.
      if yay -S --needed "${aur[@]}"; then
        green "   $label: AUR done"
      else
        red "   $label: some AUR packages failed, see the output above"
        FAILED+=("$label: an AUR build failed")
      fi
    else
      FAILED+=("$label: ${#aur[@]} AUR package(s), and no yay to build them")
    fi
  fi
}

# ---------------------------------------------------------------------------
blue "== 1/7  Packages =="

# THE COMPOSITOR'S OWN PACKAGES LIVE IN THEIR OWN LISTS, and only the chosen
# one is installed. The shared lists used to carry hyprland, hyprsunset, uwsm
# and xdg-desktop-portal-hyprland, so a machine that answered "niri" would have
# pulled in the whole other compositor to leave it sitting there unused.
#
# The two portal backends, on the other hand, coexist happily and BOTH are
# installed under "both" -- checked rather than assumed: each compositor ships
# its own /usr/share/xdg-desktop-portal/<name>-portals.conf and xdg-desktop-
# portal picks the file by XDG_CURRENT_DESKTOP, so hyprland-portals.conf routes
# ScreenCast to hyprland in one session and niri-portals.conf routes it to
# gnome in the other, with nothing to switch by hand. The reasoning behind each
# list is written at the top of the list itself.
REQUIRED_LISTS=("$DOT"/packages/required/*.txt)
want_hyprland && REQUIRED_LISTS+=("$DOT/packages/compositor/hyprland.txt")
want_niri     && REQUIRED_LISTS+=("$DOT/packages/compositor/niri.txt")

REQUIRED_NAMES=()
for list in "${REQUIRED_LISTS[@]}"; do
  mapfile -t -O "${#REQUIRED_NAMES[@]}" REQUIRED_NAMES < <(read_list "$list")
  echo "   $(read_list "$list" | wc -l) in ${list#"$DOT"/}"
done

if ask "Install them (plus stow)?"; then
  # stow first and on its own: step 3 is the part that matters, and it is the
  # one thing here with no alternative route.
  sudo pacman -S --needed --noconfirm stow || FAILED+=("stow could not be installed")
  if load_repo_index; then
    install_names "required" "${REQUIRED_NAMES[@]}"
  fi
fi

# ---------------------------------------------------------------------------
# THE OPTIONAL GROUPS. Each file under packages/optional/ is one pack, asked
# for as a whole, and skipping any of them still leaves a desktop that works --
# which is the line that decides whether a list belongs here or in required/.
blue "== 2/7  Optional package groups =="
echo "   Each one is a pack. Skipping any of them leaves a working desktop."
echo

for list in "$DOT"/packages/optional/*.txt; do
  group="$(basename "$list" .txt)"
  count="$(read_list "$list" | wc -l)"

  # The first line of the header, which is the one-line description of what the
  # group is for. Written where it cannot go out of step with the list.
  summary="$(sed -n '1s/^# *//p' "$list")"
  echo "   $group -- $count packages: $summary"

  if ask "   Install the $group group?"; then
    mapfile -t names < <(read_list "$list")
    # Deferred until something is actually wanted: a run that says no to every
    # group should not pay for the index, and a machine with empty databases
    # should not be stopped by a question it never asked.
    if [[ ${#PKG_REPO[@]} -gt 0 ]] || load_repo_index; then
      install_names "$group" "${names[@]}"
    fi
  fi
  echo
done

# ---------------------------------------------------------------------------
blue "== 3/7  Link the configuration (stow) =="
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
         systemctl --user enable --now wallpaper-rotate.timer &&
         systemctl --user enable --now airpods-battery.timer; }; then
    red "   the wallpaper timer could not be enabled (no user session?)"
    echo "   Once logged in: systemctl --user enable --now wallpaper-rotate.timer"
  fi
  # Best-effort on their own lines: these units belong to packages, which are
  # not there if step 1 was skipped.
  # The polkit agent is a plain D-Bus service and belongs to neither flavor:
  # it works the same under both.
  systemctl --user enable --now hyprpolkitagent.service 2>/dev/null || true

  # The blue light filter's daemon. Shipped by the hyprsunset package and
  # bound to graphical-session.target, so it comes and goes with the session;
  # the `night-light` script only talks to it. Enabled here rather than
  # started from hyprland.lua because the unit already exists and already
  # knows when to run -- see the note at the top of that script.
  #
  # ONLY UNDER HYPRLAND, and not because it would fail loudly otherwise: it
  # would come up perfectly and do nothing at all. hyprsunset changes the
  # colour temperature through hyprland-ctm-control-v1, and under niri that
  # protocol simply is not there, so the daemon sits running with no effect
  # while `night-light` reports success. Enabling it in a niri session would
  # buy a unit that lies.
  if want_hyprland; then
    systemctl --user enable --now hyprsunset.service 2>/dev/null || true
  fi
  if want_niri; then
    # NOTHING TO ENABLE, and that is deliberate rather than missing.
    # wl-gammarelay-rs ships no unit, and `night-light` starts it on demand as a
    # transient systemd-run unit precisely so nothing binds it to
    # graphical-session.target -- a unit that did would also come up under
    # Hyprland, where it would fight hyprsunset for gamma control of the same
    # outputs. It is in packages/required/shell.txt, so step 1 is what installs it.
    echo "   niri: the blue light filter is wl-gammarelay-rs, started on demand"
  fi
  green "   done"
fi

# ---------------------------------------------------------------------------
# THE ONE QUESTION A TRACKED CONFIG CANNOT ANSWER FOR ITSELF. These dotfiles
# are shared between a desktop and a laptop, and the two pieces of hardware
# that differ most are a battery and a backlight. Detection alone is not
# enough to decide: a desktop with a UPS reports a battery, and a laptop whose
# driver has not loaded yet reports none, so the machine would grow and lose
# widgets for reasons nobody asked for.
#
# Asked here rather than defaulted, and OFF unless answered. The widgets also
# hide themselves when the hardware is genuinely absent, so a wrong answer
# costs nothing -- it is the intention that is being recorded, not a guess.
blue "== Laptop widgets =="
echo "   A battery indicator on the bar and a brightness slider in the island."
echo "   Off by default; they are only useful on a machine that has both."
if ask "Is this a laptop?"; then
  "$DOT/bin/.local/bin/laptop-modules" on >/dev/null
  green "   on -- they appear once the shell restarts"
else
  "$DOT/bin/.local/bin/laptop-modules" off >/dev/null
  echo "   off"
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
blue "== 4/7  Seed the files the applications rewrite =="
echo "   seeds/ -> \$HOME, and only where there is nothing already"

# Where each seed goes. A destination cannot be derived from a seed's name --
# qt6ct.conf sits a directory deeper than mimeapps.list -- so there is a list,
# and a list is a thing to forget.
#
# WHICH IS WHY THE LOOP BELOW IS OVER THE DIRECTORY AND NOT OVER THIS. Dropping
# a third file into seeds/ used to copy nothing at all: the loop iterated the
# pairs, so an unlisted seed was not skipped with a warning, it was never
# looked at. Now the directory decides what gets considered and this only
# decides where it lands, so the failure is a message instead of a silence.
#
# The other way out would be to mirror $HOME inside seeds/ and derive the
# destination from the path, the way every stow package does. Rejected on
# purpose: it would make `stow seeds` -- the one thing seeds/README.md forbids
# in capitals -- produce a working set of symlinks instead of obvious garbage,
# and the whole point of a seed is that it must not be a link.
declare -A SEED_DEST=(
  ["qt6ct.conf"]="$HOME/.config/qt6ct/qt6ct.conf"
  ["mimeapps.list"]="$HOME/.config/mimeapps.list"
)

if ask "Copy the missing ones?"; then
  seeded=0
  unmapped=()

  for src in "$DOT"/seeds/*; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src")"

    # The directory's own documentation, not a seed.
    [[ "$name" == "README.md" ]] && continue

    dst="${SEED_DEST[$name]:-}"
    if [[ -z "$dst" ]]; then
      unmapped+=("$name")
      continue
    fi

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

  # Loud rather than fatal. A seed with nowhere to go is a mistake in this
  # script, not in the machine being set up, and stopping the install over it
  # would punish the wrong person -- but saying nothing is how it went
  # unnoticed in the first place.
  if (( ${#unmapped[@]} )); then
    red "   ${#unmapped[@]} file(s) in seeds/ have no destination and were skipped:"
    printf '     %s\n' "${unmapped[@]}"
    echo "     Add them to SEED_DEST above, and to the table in seeds/README.md."
  fi

  # qt6ct's colour scheme lands in ~/.config/qt6ct/colors/, which nothing else
  # creates any more: qt6ct stopped being a stow package when its config became
  # a seed, and the seed only makes the directory its own file sits in.
  #
  # matugen does create missing parents, so this is insurance rather than a
  # fix -- but it is insurance against a silent one. A palette that fails to
  # write leaves Qt applications on the factory grey with nothing on screen to
  # say why, which is a long way to walk back from.
  mkdir -p "$HOME/.config/qt6ct/colors"
fi

# ---------------------------------------------------------------------------
blue "== 5/7  Neovim (separate repo) =="
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
blue "== 6/7  Cursor themes =="
echo "   28 Bibata themes coloured from Material 3 roles, one per accent"
echo "   family. cursor-match picks the one closest to the wallpaper after"
echo "   every change; without them the pointer stays whatever the system"
echo "   ships. 83 MB to download, 845 MB once unpacked into ~/.icons."

# NOT VERSIONED IN THIS REPOSITORY, and not built here either. The pack is
# nearly a gigabyte of compiled bitmaps -- an XCursor file carries the pointer
# at all 19 sizes -- which is the same reason packages/xwayland-satellite/
# ignores its own build output. Building instead of downloading would mean
# librsvg, xcursorgen, fish and about half an hour for 28 themes.
#
# PINNED TO A TAG on purpose: `latest` would change the pointers on a machine
# that only re-ran the installer. Bump it here when there is a reason to.
CURSOR_PACK_VERSION="v1.3.0"
CURSOR_PACK_URL="https://github.com/SakibShahariar/material-bibata-cursor/releases/download/$CURSOR_PACK_VERSION/bibata-material-dark-$CURSOR_PACK_VERSION.tar.gz"

# The dark half only. matugen runs with --mode dark on this desktop, so the
# -Light counterparts would never come out of the matcher -- they would only
# double both the disk and the length of the picker in the settings window.
if compgen -G "$HOME/.icons/Bibata-Material-*" >/dev/null; then
  echo "   already installed in ~/.icons, leaving it alone"
elif ask "Download and install them?"; then
  # curl OR wget, whichever the machine has. Neither is guaranteed: curl comes
  # in as a dependency of half of Arch but is in no list here, and wget is in
  # packages/optional/hardware.txt, which is a group that can be skipped whole.
  fetch=""
  command -v curl >/dev/null && fetch="curl -fL --progress-bar -o"
  [[ -z "$fetch" ]] && command -v wget >/dev/null && fetch="wget -q --show-progress -O"

  if [[ -z "$fetch" ]]; then
    red "   neither curl nor wget is installed, skipping"
  else
    # Same shape as the Neovim clone below: fallible, wrapped, and never
    # allowed to take `set -e` and the rest of the script with it.
    tmp="$(mktemp -d)"
    if $fetch "$tmp/pack.tar.gz" "$CURSOR_PACK_URL"; then
      mkdir -p "$HOME/.icons"
      # --strip-components=1 drops the versioned top directory, so the themes
      # land as ~/.icons/Bibata-Material-<name> and the name in the settings
      # window does not carry a release number that means nothing to it.
      if tar xzf "$tmp/pack.tar.gz" -C "$HOME/.icons" \
           --strip-components=1 --exclude='INSTALL.txt'; then
        green "   done"
      else
        red "   the archive could not be unpacked, ~/.icons may be half-written"
      fi
    else
      red "   the download failed, the cursor themes are not installed"
    fi
    rm -rf "$tmp"
  fi
fi

# ---------------------------------------------------------------------------
blue "== 7/7  Generate the colour palette =="
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
# TWO FILES NAME MONITORS UNDER HYPRLAND, and a check that reads only one of
# them is wrong. hyprland.lua carries the hand-written block for the machine
# this repo was set up on: tracked, commented, and NOT where a second machine
# should record its own screens -- editing a tracked file is what leaves a clone
# permanently dirty and turns every pull into a conflict. On top of that block
# hyprland.lua dofile()s ~/.config/hypr/monitors.lua, which `desktop-monitors`
# generates and .gitignore keeps out of the repo, and a later hl.monitor for
# the same output wins. So a machine set up the current way names its screens
# ONLY there, and grepping hyprland.lua alone would report it as broken.
#
# Which is why the question below is asked of the HARDWARE and not of the file:
# for each monitor actually attached, does either file name it? One that
# neither names still lights up -- the fallback rule at the end of the block
# gives it preferred mode and automatic position -- it just sits wherever
# Hyprland decided to put it, at whatever refresh rate.
#
# UNDER NIRI IT IS ONE FILE, AND THE NAMES ARE NOT THE SAME NAMES. Both points
# matter and both are easy to get wrong:
#
#   - ~/.config/niri/monitors.kdl is the ONLY place an output is declared.
#     config.kdl declares none on purpose, because an `output` block in an
#     include is ignored when the including file names the same monitor -- so
#     there is no layering here, and "not recorded" means "not configured at
#     all" rather than "no override on top of the hand-written one".
#   - The two compositors build a monitor's name from the same three EDID
#     fields and do NOT produce the same string: Hyprland normalises the
#     manufacturer and niri does not, so this machine's portrait screen is
#     "GIGA-BYTE TECHNOLOGY CO. LTD. GS27FA ..." in one and "GIGA-BYTE
#     TECHNOLOGY CO., LTD. GS27FA ..." -- with the comma -- in the other.
#     Copying a name across gets a monitor that silently keeps its preferred
#     mode and no rotation.
#
# `desktop-monitors` knows both of those, which is why each branch below asks it
# rather than grepping for itself.
echo
blue "== Monitors =="
HYPR_CONF="$HOME/.config/hypr/hyprland.lua"
HYPR_OVERRIDES="$HOME/.config/hypr/monitors.lua"
NIRI_CONF="$HOME/.config/niri/config.kdl"

if command -v niri >/dev/null && [[ -n ${NIRI_SOCKET:-} ]]; then
  # In a live niri session. Every attached monitor is compared against the
  # records in ~/.config/niri/monitors.kdl -- untracked and generated, so
  # writing to it is the RIGHT advice here rather than something that leaves a
  # clone dirty.
  #
  # A screen with no record still lights up: niri gives it its preferred mode,
  # no rotation and an automatic position. It just does not keep the layout
  # anybody chose.
  if [[ ! -f $NIRI_CONF ]]; then
    echo "   $NIRI_CONF not found — run step 3 (stow) first."
  elif ! command -v jq >/dev/null; then
    echo "   jq is not installed, so the monitors cannot be read."
    echo "   It is in packages/required/shell.txt: install it and re-run this script."
  elif [[ ! -x $HOME/.local/bin/desktop-monitors ]]; then
    echo "   ~/.local/bin/desktop-monitors is missing — run step 3 (stow) first."
  else
    # The recorded names, read out of the script's own `show` rather than out
    # of the generated file: one parser for that format, and it lives with the
    # thing that writes it.
    RECORDED=()
    mapfile -t RECORDED < <("$HOME/.local/bin/desktop-monitors" | grep -v '^\( \|Main monitor:\|No monitors recorded\)')

    in_recorded() {
      local needle="$1" item
      for item in "${RECORDED[@]}"; do
        if [[ $item == "$needle" ]]; then return 0; fi
      done
      return 1
    }

    NIRI_UNCONFIGURED=0
    while IFS= read -r desc; do
      if in_recorded "$desc"; then
        green "   recorded (monitors.kdl): $desc"
      else
        red   "   not recorded:            $desc"
        NIRI_UNCONFIGURED=1
      fi
    done < <("$HOME/.local/bin/desktop-monitors" list --json | jq -r '.[].description')

    if (( NIRI_UNCONFIGURED )); then
      echo
      echo "   Those screens work — niri gives them preferred mode, no rotation"
      echo "   and an automatic position — but nothing places them or sets a rate."
      echo
      echo "   Arrange them the way you like them, then record what is on screen:"
      echo
      echo "       desktop-monitors seed"
      echo
      echo "   That writes ~/.config/niri/monitors.kdl, which config.kdl includes"
      echo "   FIRST and .gitignore keeps out of the repo. Do NOT put output"
      echo "   blocks in config.kdl: it is tracked, and an output named there is"
      echo "   ignored in the include, which would leave the settings window"
      echo "   applying changes that every reload undoes."
      echo
      echo "   The settings window (SUPER + C) does the same thing from a display"
      echo "   page that applies a change live and puts it back unless you confirm"
      echo "   it."
    else
      green "   every attached monitor is recorded, nothing to change"
    fi
  fi
elif ! command -v hyprctl >/dev/null || ! hyprctl monitors -j >/dev/null 2>&1; then
  echo "   No compositor is running, so the monitors cannot be read."
  echo "   Log in and re-run this script, or run 'desktop-monitors' by hand."
elif ! command -v jq >/dev/null; then
  # Everything below reads hyprctl's JSON through jq. Said here rather than
  # discovered halfway down, where a missing jq would abort the script under
  # `set -e` and take the closing notes with it.
  echo "   jq is not installed, so the monitors cannot be read."
  echo "   It is in packages/required/shell.txt: install it and re-run this script."
elif [[ ! -f $HYPR_CONF ]]; then
  echo "   $HYPR_CONF not found — run step 3 (stow) first."
else
  # Read once: hyprctl is talking to a live compositor over a socket.
  MONITORS_JSON="$(hyprctl monitors -j)"

  # The descriptions each file names. hyprland.lua writes them "desc:like
  # this" and desktop-monitors generates them 'desc:like this', so both quotes end
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
      "       desktop-monitors set \"\(.description)\" \(.width)x\(.height)@\(.refreshRate|round) \(.x)x\(.y) \(.scale*100|round/100) \(.transform)"' \
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

# EVERYTHING THAT WENT WRONG, ONCE, AT THE BOTTOM. A package that could not be
# installed is not a reason to skip the symlinks -- so nothing above stops the
# run -- but half an hour of pacman output has scrolled past by now and a
# failure buried in it is a failure nobody sees.
if (( ${#FAILED[@]} )); then
  red "   ${#FAILED[@]} thing(s) did not work:"
  printf '     %s\n' "${FAILED[@]}"
  echo
fi

cat <<'END'

Left to do by hand:

  1. /etc  — see system/ and the table in the README. The fstab UUIDs belong
             to the original machine: do NOT copy it as is.
  2. Monitors — if the check above listed a screen as not configured, record
             it with 'desktop-monitors set ...' (the command is printed for you),
             with 'desktop-monitors seed', or from the settings window, SUPER + C.
             That writes ~/.config/hypr/monitors.lua under Hyprland and
             ~/.config/niri/monitors.kdl under niri, both generated and
             gitignored; the tracked configs do not need editing.
  3. The GPU driver. Deliberately not installed by this script: it is the one
             thing that depends on hardware nothing here can see, and a driver
             for a card you do not have is not a harmless mistake. The lists
             are there for when you have looked:

               lspci -k | grep -A2 -E '(VGA|3D)'
               sudo pacman -S --needed $(sed 's/#.*//' packages/gpu/nvidia.txt)

             Only packages/gpu/nvidia.txt has been run on real hardware; the
             amd and intel lists resolve against the repositories and no more,
             and each says so at the top.
  4. zsh as the default shell, if it is not already:
             chsh -s /usr/bin/zsh
END
