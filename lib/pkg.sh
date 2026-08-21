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

# THE CACHE IS A LIE THE MOMENT PACMAN RUNS, and until this existed nothing said
# so. Every reader above goes through PKG_INSTALLED, which is filled once and
# kept, which is right for `check` -- it asks a hundred questions of a machine
# nobody is changing. It is wrong immediately after an install, and asking the
# local database again is what makes it possible to answer "which of these
# actually went in" without parsing anybody's output.
pkg_reload_installed() {
  PKG_INSTALLED=()
  PKG_INSTALLED_LOADED=0
  pkg_load_installed
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

# ---------------------------------------------------------------------------
# WHICH OF THESE DID NOT GO IN, asked of the local database rather than of the
# installer's output.
#
# THE ALTERNATIVES WERE WEIGHED AND THIS IS THE CHEAPEST TRUE ONE.
#
#   ONE INVOCATION PER PACKAGE would attribute a failure by construction, and
#   it costs the batching, which is not a small thing here: `yay -S a b c`
#   resolves the dependency graph across all three at once and builds a shared
#   AUR dependency ONCE. Split up, a common -git dependency is re-resolved and
#   rebuilt for every package that wants it, and each invocation asks its own
#   round of "which provider / edit the PKGBUILD / proceed" questions. On the
#   required list that is minutes turning into a long evening.
#
#   PARSING THE OUTPUT is free and wrong. pacman's messages are TRANSLATED --
#   this file already carries the scar of that, in the note on `pacman -Sl`
#   above -- and yay's are neither translated nor stable nor documented as an
#   interface. A parser that works today is a parser that reports "nothing
#   failed" after the next release.
#
#   ASKING AGAIN AFTERWARDS, which is this, keeps the batch, costs one
#   `pacman -Qq` per install step, and is not a guess: "is it installed" is the
#   question that was being asked in the first place. Its one blind spot is a
#   package that was already installed at an older version and failed to
#   UPDATE, which would not show up here -- and that is exactly the case
#   `--needed` tells the caller it is not attempting, so the answer stays
#   consistent with what was asked for.
pkg_still_missing() {
  pkg_reload_installed
  pkg_missing "$@"
}

# THE INSTALLER FAILED AND EVERYTHING IS INSTALLED is a real outcome and not a
# contradiction: pacman and yay both exit non-zero for a failing hook, an
# orphaned dependency warning or a post-transaction script, with the
# transaction itself committed. So the message has two shapes and the caller
# picks neither -- $1 is the subject, and what follows it depends on whether
# the re-check found anything actually missing.
pkg_failure_line() {
  local subject="$1"; shift

  if (( $# )); then
    printf '%s: %s' "$subject" "$*"
  else
    printf '%s, though every name on the list is installed afterwards -- see the output above' "$subject"
  fi
}

# And the same fork for the way out, because "install them one at a time" is
# not advice when there is nothing left to install.
pkg_failure_remedy() {
  local one_at_a_time="$1"; shift

  if (( $# )); then
    printf '%s %s' "$one_at_a_time" "$*"
  else
    printf '%s' "Read the output above: the packages went in, so what failed was a hook or a post-transaction step."
  fi
}

# ---------------------------------------------------------------------------
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
# WHETHER PACMAN AND YAY ARE ALLOWED TO ASK A QUESTION.
#
# `pacman -S` ends with ":: Proceed with installation? [Y/n]" and reads the
# answer from stdin. With nothing on stdin it does NOT fall back to the
# default it is printing in capitals -- it gives up:
#
#     :: Proceed with installation? [Y/n]    required: pacman did not finish
#        stow is not installed, so nothing can be linked
#
# So `./install.sh -y` installed no packages at all with no terminal attached,
# which is the exact case --yes exists for, and `update` -- documented as
# something to reach from a keybind or a cron job -- could not install
# anything either. Verified against the real pacman, in a throwaway root:
# with stdin at end of file it stops on that line and exits 1; with
# --noconfirm and the same stdin it walks straight past it into the
# transaction.
#
# NOT UNCONDITIONAL, AND THE CONDITION IS THE ONE ui_confirm ALREADY USES.
# --noconfirm answers every question pacman has and not only that one: which
# provider to take for a name that several packages provide, whether to
# replace a package, whether to remove something that conflicts. On a terminal,
# with no --yes, those are worth seeing -- pacman's own transaction list is the
# last look at 119 names and a download size before any of it arrives, and this
# script cannot put those questions on screen for it. So the rule is that
# pacman is told to take its defaults in exactly the three cases where this
# script would not ask a question either: --yes was given, questions are
# switched off (which is what `update` does), or there is no terminal to ask
# on. Those are ui_confirm's three branches, in ui.sh, and they stay in step
# by being the same three.
pkg_noconfirm() {
  (( ${ASSUME_YES:-0} )) && return 0
  (( ${UI_ASK:-1} == 0 )) && return 0
  ! ui_has_tty
}

# ---------------------------------------------------------------------------
# yay builds itself from source the first time, which needs git, base-devel and
# a few minutes. Only called when a list actually turns out to contain
# something from the AUR.
pkg_ensure_yay() {
  command -v yay >/dev/null && return 0

  local tmp built=1
  run_sudo pacman -S --needed --noconfirm git base-devel
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
# NOTHING IN HERE ENDS THE RUN ON ITS OWN, and that stays true. Under `set -e` a
# function that returns non-zero inside an `if` body takes the whole script down
# with it, and that is precisely how one package dropped from the repositories
# used to mean no symlinks, no seeds and no palette. Every fallible command is
# tested rather than run bare. What CHANGED is that the caller now says how much
# the set matters, and a set that matters enough goes through fail_stop -- which
# does end the run, deliberately, by the one route that is impossible to forget.
#
# $1 IS `stop` OR `note`, AND IT BELONGS TO THE CALLER. This file has no way to
# know whether a list is the desktop or a nice-to-have; the units do, because
# the answer is written down in the directory the list came from. See the note
# in 15-optional.sh on what separates packages/required/ from packages/optional/.
#
# $2 is the unit id, which is what the summary groups by and what a person would
# run again. $3 is the label -- "required", "gaming", "gpu/nvidia" -- which is
# what they saw scroll past.
#
# Returns 0 when the severity is `note`, even though packages failed. "Some of
# it did not install" is a report, not a reason to abandon the rest of the run.
pkg_install() {
  local severity="$1" unit="$2" label="$3"; shift 3
  local names=("$@") repo=() aur=() blocked=() failed=() name confirm=()

  (( ${#names[@]} )) || return 0

  # Worked out once for both installers below, so the two cannot disagree
  # about whether this run is one somebody is watching.
  pkg_noconfirm && confirm=(--noconfirm)

  # ALWAYS FATAL, WHATEVER THE CALLER SAID. An empty sync database is not this
  # list failing, it is pacman being unable to install anything at all: every
  # later pkg_install hits the same wall, and every name in every list would
  # fall through to the AUR branch and be built from source. There is no
  # version of carrying on here that is not worse than stopping.
  pkg_load_repo_index || fail_stop "$unit" \
    "pacman knows of no packages at all -- the sync databases are empty." \
    "sudo pacman -Sy"

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
    pkg_record "$severity" "$unit" \
      "$label: ${blocked[*]} -- [multilib] is not enabled" \
      "Uncomment [multilib] and its Include line in /etc/pacman.conf, run 'sudo pacman -Sy', then: ./install.sh apply $unit"
  fi

  # --needed skips what is already installed, which is what makes re-running
  # this cheap enough to be the normal way to use it.
  if (( ${#repo[@]} )); then
    if run_sudo pacman -S --needed "${confirm[@]}" "${repo[@]}"; then
      ui_did "   $label: ${#repo[@]} package(s) from the repositories"
    else
      mapfile -t failed < <(pkg_still_missing "${repo[@]}")
      ui_bad "   $label: pacman did not finish, see the output above"
      pkg_record "$severity" "$unit" \
        "$(pkg_failure_line "$label: pacman could not install" "${failed[@]}")" \
        "$(pkg_failure_remedy "A mirror, a renamed package or a conflict -- try them one at a time: sudo pacman -S --needed" "${failed[@]}")"
    fi
  fi

  if (( ${#aur[@]} )); then
    ui_say "   $label: ${#aur[@]} package(s) come from the AUR"
    if (( ${DRY_RUN:-0} )); then
      run yay -S --needed "${confirm[@]}" "${aur[@]}"
    elif pkg_ensure_yay; then
      # THE NAMES GO AS ARGUMENTS AND NOT DOWN STDIN. `yay -S --needed -` reads
      # the list from stdin, and then reads its own prompts -- which provider,
      # edit the PKGBUILD, proceed with the build -- from that same stdin,
      # which by then is at end of file. The answers it got were whatever was
      # left of the list.
      # THE SAME ANSWER GOES TO yay, and for a stronger reason than symmetry:
      # it asks more questions than pacman does -- which provider, whether to
      # show the diff, whether to edit the PKGBUILD, whether to proceed -- and
      # every one of them lands on the same stdin. A run with --yes that
      # stalled on the first AUR package would be the same bug one line down.
      if yay -S --needed "${confirm[@]}" "${aur[@]}"; then
        ui_did "   $label: AUR done"
      else
        # BY NAME, WHICH IS WHAT THE NOTE ON pkg_needs_multilib ALREADY
        # PROMISED. It says a misclassified multilib package would be "reported
        # as an AUR build that failed -- by name, which is a long way from
        # silence", and ninety lines below it the code recorded exactly "an AUR
        # build failed" with no name at all. Thirty names go to yay in one
        # batch; the promise was worth keeping and the comment was the only
        # part of it that existed.
        mapfile -t failed < <(pkg_still_missing "${aur[@]}")
        ui_bad "   $(pkg_failure_line "$label: the AUR build failed" "${failed[@]}")"
        pkg_record "$severity" "$unit" \
          "$(pkg_failure_line "$label: the AUR build failed" "${failed[@]}")" \
          "$(pkg_failure_remedy "Build them one at a time to see which one and why: yay -S" "${failed[@]}")"
      fi
    else
      pkg_record "$severity" "$unit" \
        "$label: no yay, so ${#aur[@]} AUR package(s) were skipped: ${aur[*]}" \
        "Install yay by hand -- git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si -- then: ./install.sh apply $unit"
    fi
  fi
}

# The one place the severity a caller chose turns into a ledger entry, so that
# no branch above has to remember which of the two functions it wanted.
pkg_record() {
  local severity="$1" unit="$2" what="$3" remedy="$4"

  if [[ $severity == stop ]]; then
    fail_stop "$unit" "$what" "$remedy"
  else
    fail_note "$unit" "$what" "$remedy"
  fi
}
