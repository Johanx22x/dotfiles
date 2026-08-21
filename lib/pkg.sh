# shellcheck shell=bash
# Packages: reading the lists, working out where each name comes from, and
# installing what is missing.
#
# The lists under packages/ are grouped by PURPOSE and say nothing about where
# a name lives. That is deliberate -- "which repository is gimp in" is a
# question the machine can answer, and its answer moves over time -- so this
# file is what answers it.

# ---------------------------------------------------------------------------
# READING A LIST. Every list carries a header explaining what the group is for,
# so comments and blank lines come off here. The strip runs to end of line
# rather than only on whole lines: a pacman package name cannot contain '#', so
# nothing is lost by it and a note can sit beside the name it is about.
pkg_read_list() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1"
}

# The first line of a list's header, which is its one-line description. Kept
# where it cannot go out of step with the list it describes.
pkg_list_summary() {
  sed -n '1s/^# *//p' "$1"
}

# Every name across a set of list files, in file order.
pkg_names_in() {
  local file
  for file in "$@"; do
    [[ -f $file ]] || continue
    pkg_read_list "$file"
  done
}

# ---------------------------------------------------------------------------
# WHAT THE REPOSITORIES HAVE.
#
# WHY `pacman -Sl` AND NOT `pacman -Si`
# The first version of this asked `pacman -Si` for each package and read the
# name back out of the "Name : foo" line. That output is TRANSLATED: on a
# Spanish system the field is "Nombre", the match found nothing, and the script
# announced that all 129 packages were unavailable -- failing silently in the
# worst possible direction, since "skip it" is what it does with a package it
# cannot see. `pacman -Sl` prints "<repo> <name> <version>" with no field
# labels at all, so there is nothing left to translate, and it hands over the
# repository name for free.
declare -A PKG_REPO=()
PKG_REPO_LOADED=0

pkg_load_repo_index() {
  (( PKG_REPO_LOADED )) && return 0

  local repo name rest
  while read -r repo name rest; do
    PKG_REPO["$name"]="$repo"
  done < <(pacman -Sl 2>/dev/null)

  # EMPTY SYNC DATABASES READ AS "NOTHING EXISTS ANYWHERE", and that is exactly
  # the machine this script is written for. A box that has never run
  # `pacman -Sy` prints nothing here, every name falls through to the AUR
  # branch, and yay is asked to build the whole desktop from source. The
  # version that compared against `pacman -Slq` had the same hole and was
  # quieter about it: it reported every package as unavailable, skipped them
  # all, and carried on to the stow step as though nothing had happened.
  if (( ${#PKG_REPO[@]} == 0 )); then
    ui_bad "   pacman knows of no packages at all -- the sync databases are empty."
    ui_say "   Run 'sudo pacman -Sy' and then this script again."
    return 1
  fi

  PKG_REPO_LOADED=1
}

# ---------------------------------------------------------------------------
# WHAT IS INSTALLED. This is the half `_check` uses, so it must stay
# read-only and must never want sudo: `pacman -Qq` reads the local database and
# does neither.
declare -A PKG_INSTALLED=()
PKG_INSTALLED_LOADED=0

pkg_load_installed() {
  (( PKG_INSTALLED_LOADED )) && return 0
  local name
  while read -r name; do
    PKG_INSTALLED["$name"]=1
  done < <(pacman -Qq 2>/dev/null)
  PKG_INSTALLED_LOADED=1
}

pkg_is_installed() {
  pkg_load_installed
  [[ -n ${PKG_INSTALLED[$1]:-} ]]
}

# Names from the arguments that are not installed, one per line.
#
# BY NAME AND NOT BY WHAT PROVIDES IT. `pacman -Qq` lists what is installed
# under its own name, so a package satisfied by a provider would be reported as
# missing -- and then `pacman -S --needed` on it is a no-op that says so, which
# is a wrong answer that costs nothing. Resolving provides means one `pacman
# -Qi` per name and translated output again, which is a wrong answer that costs
# a great deal.
pkg_missing() {
  local name
  pkg_load_installed
  for name in "$@"; do
    [[ -n ${PKG_INSTALLED[$name]:-} ]] || printf '%s\n' "$name"
  done
}

# ---------------------------------------------------------------------------
# Is [multilib] switched on? Asked once, because the answer changes what an
# unresolved lib32-* name means.
PKG_MULTILIB_ON=-1
pkg_multilib_on() {
  if (( PKG_MULTILIB_ON < 0 )); then
    PKG_MULTILIB_ON=0
    grep -q '^\[multilib\]' /etc/pacman.conf && PKG_MULTILIB_ON=1
  fi
  (( PKG_MULTILIB_ON ))
}

# A DISABLED REPOSITORY IS NOT IN `pacman -Sl` EITHER, so once [multilib] is
# off its packages are indistinguishable from names that only exist in the AUR,
# and handing lib32-mesa to yay is not a good outcome. The rule is written down
# as the heuristic it is: everything 32-bit is called lib32-*, and the Steam
# client is a 32-bit binary, which is the entire reason [multilib] is in play on
# this machine. A multilib package that is neither would be handed to yay and
# reported as an AUR build that failed -- by name, which is a long way from
# silence.
pkg_needs_multilib() {
  [[ $1 == lib32-* || $1 == steam ]]
}

# ---------------------------------------------------------------------------
# yay builds itself from source the first time, which needs git, base-devel and
# a few minutes. Only called when a list actually turns out to contain
# something from the AUR.
pkg_ensure_yay() {
  command -v yay >/dev/null && return 0

  local tmp built=1
  sudo pacman -S --needed --noconfirm git base-devel
  tmp="$(mktemp -d)"
  if git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay" &&
     ( cd "$tmp/yay" && makepkg -si --noconfirm ); then
    ui_ok "   yay installed"
    built=0
  else
    ui_bad "   yay could not be built, the AUR packages are skipped"
  fi
  rm -rf "$tmp"
  return $built
}

# ---------------------------------------------------------------------------
# INSTALL A SET OF NAMES, wherever each of them lives.
#
# NOTHING IN HERE IS ALLOWED TO END THE RUN. Under `set -e` a function that
# returns non-zero inside an `if` body takes the whole script down with it, and
# that is precisely how one package dropped from the repositories used to mean
# no symlinks, no seeds and no palette. Every fallible command is tested rather
# than run bare, and what went wrong goes into FAILED to be said again at the
# end, where it will still be on screen.
#
# Returns 0 even when packages failed. "Some of it did not install" is a report,
# not a reason to abandon the rest of the run.
pkg_install() {
  local label="$1"; shift
  local names=("$@") repo=() aur=() blocked=() name

  (( ${#names[@]} )) || return 0
  pkg_load_repo_index || { FAILED+=("$label: the sync databases are empty"); return 0; }

  for name in "${names[@]}"; do
    if [[ -n ${PKG_REPO[$name]:-} ]]; then
      repo+=("$name")
    elif ! pkg_multilib_on && pkg_needs_multilib "$name"; then
      blocked+=("$name")
    else
      aur+=("$name")
    fi
  done

  if (( ${#blocked[@]} )); then
    ui_bad "   $label: ${#blocked[@]} package(s) need [multilib], which is not enabled:"
    printf '     %s\n' "${blocked[@]}"
    ui_say "     Uncomment these two lines in /etc/pacman.conf, run 'sudo pacman -Sy',"
    ui_say "     and this again:"
    ui_say ""
    ui_say "       [multilib]"
    ui_say "       Include = /etc/pacman.d/mirrorlist"
    ui_say ""
    FAILED+=("$label: ${blocked[*]} (needs [multilib])")
  fi

  # --needed skips what is already installed, which is what makes re-running
  # this cheap enough to be the normal way to use it.
  if (( ${#repo[@]} )); then
    if run sudo pacman -S --needed "${repo[@]}"; then
      ui_did "   $label: ${#repo[@]} package(s) from the repositories"
    else
      ui_bad "   $label: pacman did not finish, see the output above"
      FAILED+=("$label: pacman failed")
    fi
  fi

  if (( ${#aur[@]} )); then
    ui_say "   $label: ${#aur[@]} package(s) come from the AUR"
    if (( ${DRY_RUN:-0} )); then
      run yay -S --needed "${aur[@]}"
    elif pkg_ensure_yay; then
      # THE NAMES GO AS ARGUMENTS AND NOT DOWN STDIN. `yay -S --needed -` reads
      # the list from stdin, and then reads its own prompts -- which provider,
      # edit the PKGBUILD, proceed with the build -- from that same stdin,
      # which by then is at end of file. The answers it got were whatever was
      # left of the list.
      if yay -S --needed "${aur[@]}"; then
        ui_did "   $label: AUR done"
      else
        ui_bad "   $label: some AUR packages failed, see the output above"
        FAILED+=("$label: an AUR build failed")
      fi
    else
      FAILED+=("$label: ${#aur[@]} AUR package(s), and no yay to build them")
    fi
  fi
}
