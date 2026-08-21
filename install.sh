#!/usr/bin/env bash
# Sets this desktop up on an Arch machine -- and afterwards tells you whether it
# is still set up.
#
# THE ENGINE IS SEPARATE FROM THE INTERFACE, and that is the whole design. What
# there is to do lives in lib/units/, one file per unit, each answering the same
# six questions and knowing nothing about how it is being driven. What is on
# screen lives in this file and lib/ui.sh. Everything in between -- ordering,
# dependencies, dispatch -- is lib/units.sh, which knows the name of no unit at
# all.
#
# It buys the mode this repository did not have. `check` is a read-only doctor:
# it asks every unit how it is, needs no sudo, writes nothing, and can be run at
# any moment on a working machine. Four things were quietly wrong on the machine
# this repo comes from when that mode was first written, and it found all four.
#
# Idempotent throughout. Every unit is safe to apply twice, so re-running this
# after a pull is the normal way to use it rather than an emergency measure.
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Defaults, set before anything is sourced because lib/ and the units read
# them. ASSUME_YES and DRY_RUN are what the flags below move.
ASSUME_YES=0
DRY_RUN=0
JSON=0
COMPOSITOR=""

# Everything that went wrong, collected as the run goes and printed once at the
# end. A package that will not install is not a reason to abandon the symlinks,
# but half an hour of pacman output scrolls past and a failure buried in it is a
# failure nobody sees.
FAILED=()

# The one place a command that CHANGES something goes through, so that
# --dry-run is one condition here rather than a condition in every unit.
#
# The notice goes to stderr on purpose: a caller that sends a command's output
# to /dev/null -- which several of these do -- would otherwise silence the dry
# run's only reason to exist.
run() {
  if (( DRY_RUN )); then
    printf '%s   would run: %s%s\n' "$C_DIM" "$*" "$C_RESET" >&2
    return 0
  fi
  "$@"
}

# ---------------------------------------------------------------------------
source "$DOT/lib/ui.sh"
source "$DOT/lib/pkg.sh"
source "$DOT/lib/units.sh"

# SOURCED IN FILENAME ORDER, which is what the NN- prefix is for: it fixes the
# order units are listed in, in the help, in the table and in the menu. The
# order they are APPLIED in is a different question and comes from _requires.
for unit_file in "$DOT"/lib/units/*.sh; do
  # shellcheck source=/dev/null
  source "$unit_file"
done
unset unit_file

# ---------------------------------------------------------------------------
# THE COMPOSITOR decides which packages go in and which configuration gets
# linked, so it has to be settled before any unit is asked anything.
#
# Hyprland is the default and the one everything else in this repo was built
# against. niri is a second flavor: the same keybinds, the same shell, the same
# scripts, on a scrollable-tiling compositor instead of a dynamic-tiling one.
#
# BOTH IS A REAL ANSWER AND NOT A HEDGE. The two stow packages touch different
# directories (~/.config/hypr and ~/.config/niri), the two sessions appear
# separately in the display manager, and neither knows the other exists -- so
# "both" costs one extra directory and buys the ability to try the second one
# without dismantling the first.
#
# DETECTED BEFORE IT IS ASKED, which is new and is what `check` needs. A doctor
# that opened with a question would be useless in a script and tiresome at a
# terminal, and the machine already knows the answer: whichever compositor is
# installed is the one this machine chose. The flag overrides the detection, and
# only a machine with neither installed gets asked.
compositor_detect() {
  local hypr=0 niri=0
  pkg_is_installed hyprland && hypr=1
  pkg_is_installed niri && niri=1

  if   (( hypr && niri )); then echo both
  elif (( niri ));         then echo niri
  elif (( hypr ));         then echo hyprland
  else                          echo ""
  fi
}

compositor_resolve() {
  local mode="$1"

  [[ -n $COMPOSITOR ]] && return 0

  COMPOSITOR="$(compositor_detect)"
  [[ -n $COMPOSITOR ]] && return 0

  # Nothing installed yet, so this is a first run. `check` still must not ask
  # anybody anything, so it takes the default and gets on with it.
  if [[ $mode == check ]]; then
    COMPOSITOR=hyprland
    return 0
  fi

  ui_head "Compositor"
  ui_say "   It decides which packages go in and which configuration is linked."
  COMPOSITOR="$(ui_choose_one 1 hyprland niri both)"
  ui_ok "   $COMPOSITOR"
}

want_hyprland() { [[ $COMPOSITOR == hyprland || $COMPOSITOR == both ]]; }
want_niri()     { [[ $COMPOSITOR == niri     || $COMPOSITOR == both ]]; }

# Every stow package EXCEPT the compositor's, which is appended once the
# compositor is known. seeds/ is deliberately NOT one of them -- it is copied,
# not linked, see seeds/README.md and the seeds unit. There is no `qt` or `xdg`
# package any more either: qt6ct.conf and mimeapps.list were all they held, and
# both are seeds now.
STOW_PACKAGES=()
stow_packages_resolve() {
  STOW_PACKAGES=(zsh quickshell kitty matugen shell gtk media openrgb systemd
                 bin ranger icons zen gaming)
  want_hyprland && STOW_PACKAGES+=(hypr)
  want_niri     && STOW_PACKAGES+=(niri)
  return 0
}

# ---------------------------------------------------------------------------
usage() {
  local id
  cat <<'EOF'
Sets this desktop up on an Arch machine, and tells you whether it still is.

USAGE
  ./install.sh [OPTIONS]              set the machine up
  ./install.sh check [--json]         read-only: say what is and is not in place
  ./install.sh apply <unit>... [OPTS] apply named units and what they require

MODES
  (none)    Every unit that applies to this machine and is not already ok gets
            applied, in dependency order, after showing you the list.
  check     Asks every unit how it is and prints a table. Uses no sudo, writes
            nothing, and is safe to run at any moment. Exits 1 when a unit that
            applies to this machine is not ok.
  apply     One or more units by id, plus whatever they require, in order.

OPTIONS
  -y, --yes             Answer yes to everything. Needed when there is no
                        terminal to ask on.
  -n, --dry-run         Say what would be done and do none of it.
      --compositor=X    hyprland, niri or both. Detected from what is installed
                        when it is not given.
      --json            check only. A JSON array instead of the table, for
                        anything that would rather read this than look at it.
  -h, --help            This.

UNITS
EOF

  for id in "${UNIT_IDS[@]}"; do
    printf '  %-16s %s\n' "$id" "$(unit_detail "$id")"
  done

  cat <<'EOF'

EXAMPLES
  ./install.sh check              is this machine still what the repo says
  ./install.sh check --json       the same, for a script
  ./install.sh apply symlinks     just relink the configuration
  ./install.sh -n                 what a full run would do, without doing it

  git pull && ./install.sh        the normal way to take an update
EOF
}

# ---------------------------------------------------------------------------
# ARGUMENTS. This script used to accept none at all -- not even --help -- so
# every answer had to be given at a prompt and nothing about a run could be
# written down, scripted or repeated.
MODE=""
UNIT_ARGS=()

while (( $# )); do
  case "$1" in
    check|apply)
      [[ -n $MODE ]] && { ui_bad "two modes given: $MODE and $1" >&2; exit 2; }
      MODE="$1"
      ;;
    -y|--yes)      ASSUME_YES=1 ;;
    -n|--dry-run)  DRY_RUN=1 ;;
    --json)        JSON=1 ;;
    --compositor=*)
      COMPOSITOR="${1#*=}"
      case "$COMPOSITOR" in
        hyprland|niri|both) ;;
        *) ui_bad "--compositor takes hyprland, niri or both, not '$COMPOSITOR'" >&2; exit 2 ;;
      esac
      ;;
    --compositor)
      ui_bad "write it as --compositor=hyprland" >&2; exit 2 ;;
    -h|--help)     usage; exit 0 ;;
    --)            shift; UNIT_ARGS+=("$@"); break ;;
    -*)
      ui_bad "unknown option: $1" >&2
      ui_say "Try --help." >&2
      exit 2
      ;;
    *)
      UNIT_ARGS+=("$1")
      ;;
  esac
  shift
done

# A unit id given without `apply` in front of it is a typo worth catching: on
# its own it would silently mean "run everything".
if [[ $MODE != apply && ${#UNIT_ARGS[@]} -gt 0 ]]; then
  ui_bad "unexpected argument: ${UNIT_ARGS[0]}" >&2
  ui_say "To apply one unit: ./install.sh apply ${UNIT_ARGS[0]}" >&2
  exit 2
fi

if (( JSON )) && [[ $MODE != check ]]; then
  ui_bad "--json only means something with 'check'" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# THE TWO REFUSALS, kept from the first version of this script.
#
# Not root, because everything here writes into a home directory and doing that
# as root leaves files the person who owns the home cannot edit. sudo is asked
# for at the moment it is needed instead.
#
# CHECKED EVEN FOR `check`, which does neither -- because a `sudo ./install.sh
# check` that worked would teach a habit that goes badly wrong the next time the
# word after it is `apply`.
[[ -f /etc/arch-release ]] || { ui_bad "This is for Arch Linux."; exit 1; }
(( EUID == 0 )) && { ui_bad "Do not run this as root. It asks for sudo when it needs it."; exit 1; }

# ---------------------------------------------------------------------------
# SUDO, ONCE, AT THE TOP, AND KEPT ALIVE.
#
# Between the first sudo and the end of an AUR build there can be half an hour,
# which is well past the five-minute default timeout -- so pacman stops in the
# middle of a run and sits waiting for a password behind a wall of build output,
# on a terminal nobody is watching any more.
#
# NOT CALLED FOR `check` OR UNDER `--dry-run`, and that is the point of it
# living here rather than inside pkg_install: those two must be runnable by
# anybody at any time, and a password prompt is a side effect like any other.
SUDO_KEEPALIVE_PID=""

sudo_begin() {
  (( DRY_RUN )) && return 0

  ui_say "   This needs sudo for the packages. Asking once, now."
  sudo -v || { ui_bad "   sudo refused, and everything below needs it."; exit 1; }

  # The refresh runs until this script exits. `kill -0 $$` is what ends it if
  # the script dies without reaching the trap -- otherwise the loop would
  # outlive its reason to exist and hold the timestamp open for a terminal that
  # is long gone.
  while true; do
    sudo -n true 2>/dev/null || true
    sleep 50
    kill -0 "$$" 2>/dev/null || exit 0
  done &
  SUDO_KEEPALIVE_PID=$!
  trap 'sudo_end' EXIT
}

sudo_end() {
  [[ -n $SUDO_KEEPALIVE_PID ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
  SUDO_KEEPALIVE_PID=""
  return 0
}

# ---------------------------------------------------------------------------
report_failures() {
  (( ${#FAILED[@]} )) || return 0
  echo
  ui_bad "${#FAILED[@]} thing(s) did not work:"
  printf '  %s\n' "${FAILED[@]}"
}

# Applies one list of units, skipping the ones this machine has no use for.
# Shared by `apply` and the full run so that the two cannot drift apart.
run_units() {
  local id
  sudo_begin
  for id in "$@"; do
    if ! "${id}_available" >/dev/null; then
      ui_dim "  $id does not apply to this machine, skipped"
      continue
    fi
    unit_apply "$id"
  done
  unit_run_post
}

# ---------------------------------------------------------------------------
# check: the read-only doctor.
#
# NOT ONE THING IN THIS PATH WRITES, and every unit's _check is held to the same
# rule -- no sudo, no files, no systemctl verb that changes anything. That is
# what makes it worth having: a mode that can be run on a working machine in the
# middle of the day, from a script or from a keybind, without thinking about it
# first.
#
# `na` IS NOT A FAILURE. A desktop is not broken for not being a laptop, and a
# machine with no compositor running has not lost its monitors. The exit status
# is about the units that apply here; the rest are printed dim and counted
# separately, because a doctor that always exits 1 is a doctor nobody runs
# twice.
mode_check() {
  local id state kind ok=0 bad=0 na=0

  compositor_resolve check
  stow_packages_resolve

  if (( JSON )); then
    unit_print_json "${UNIT_IDS[@]}"
    for id in "${UNIT_IDS[@]}"; do
      kind="$(unit_state_kind "$(unit_state "$id")")"
      [[ $kind == ok || $kind == na ]] || return 1
    done
    return 0
  fi

  ui_head "check -- $COMPOSITOR"
  echo

  for id in "${UNIT_IDS[@]}"; do
    state="$(unit_state "$id")"
    kind="$(unit_state_kind "$state")"
    case "$kind" in
      ok) ok=$(( ok + 1 )) ;;
      na) na=$(( na + 1 )) ;;
      *)  bad=$(( bad + 1 )) ;;
    esac
    unit_print_row "$id" "$state"
  done

  echo
  if (( bad )); then
    ui_bad "  $bad of $(( ok + bad )) applicable unit(s) need attention; $na do not apply here"
    ui_dim "  Fix one with: ./install.sh apply <unit>"
    return 1
  fi
  ui_ok "  everything applicable is in place ($ok ok, $na not applicable here)"
  return 0
}

# ---------------------------------------------------------------------------
# apply: named units, plus what they require.
mode_apply() {
  local id

  for id in "${UNIT_ARGS[@]}"; do
    if ! unit_exists "$id"; then
      ui_bad "no unit called '$id'" >&2
      ui_say "The ones there are: ${UNIT_IDS[*]}" >&2
      exit 2
    fi
  done

  compositor_resolve apply
  stow_packages_resolve
  unit_order "${UNIT_ARGS[@]}"

  # WHAT WILL RUN, BEFORE IT RUNS. `apply seeds` pulling in packages and
  # symlinks is correct and is also a surprise, so the expanded list is shown
  # rather than discovered halfway down.
  if (( ${#UNIT_ORDER[@]} > ${#UNIT_ARGS[@]} )); then
    ui_dim "  with what they require: ${UNIT_ORDER[*]}"
  fi

  run_units "${UNIT_ORDER[@]}"
  report_failures
}

# ---------------------------------------------------------------------------
# The full run: everything that applies here and is not already in place.
mode_setup() {
  local id state kind todo=()

  compositor_resolve setup
  stow_packages_resolve

  ui_head "$COMPOSITOR"
  echo

  for id in "${UNIT_IDS[@]}"; do
    state="$(unit_state "$id")"
    kind="$(unit_state_kind "$state")"
    unit_print_row "$id" "$state"
    [[ $kind == ok || $kind == na ]] || todo+=("$id")
  done
  echo

  if (( ${#todo[@]} == 0 )); then
    ui_ok "  Nothing to do: everything that applies here is already in place."
    return 0
  fi

  ui_say "  Would apply: ${todo[*]}"
  ui_confirm "  Go ahead?" || { ui_say "  Nothing done."; return 0; }

  unit_order "${todo[@]}"
  run_units "${UNIT_ORDER[@]}"

  echo
  ui_ok "== Ready =="
  report_failures
  cat <<'END'

Left to do by hand:

  1. /etc  — see system/. The fstab UUIDs belong to the original machine: do
             NOT copy it as is.
  2. The GPU driver. Deliberately not installed here: it is the one thing that
             depends on hardware nothing in this repo can see, and a driver for
             a card you do not have is not a harmless mistake.

               lspci -k | grep -A2 -E '(VGA|3D)'
               sudo pacman -S --needed $(sed 's/#.*//' packages/gpu/nvidia.txt)

  3. zsh as the default shell, if it is not already:
             chsh -s /usr/bin/zsh
END
}

# ---------------------------------------------------------------------------
case "$MODE" in
  check) mode_check ;;
  apply)
    (( ${#UNIT_ARGS[@]} )) || { ui_bad "apply needs at least one unit id" >&2; usage >&2; exit 2; }
    mode_apply
    ;;
  *) mode_setup ;;
esac
