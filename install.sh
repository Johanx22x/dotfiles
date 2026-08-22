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
# any moment on a working machine. Three things were quietly wrong on the
# machine this repo comes from the first time it ran, and it found all three.
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
PULL=0
WITH_REQUIRES=0
COMPOSITOR=""

# THE FLAGS THAT MUST SURVIVE A RE-EXEC, kept as they were typed rather than
# rebuilt from the variables they set. `update --pull` re-runs this script once
# the pull has landed, and what it hands the new copy is the whole of what that
# copy knows about the run: anything not in here is a flag the operator gave and
# the second half of the run never saw. See mode_update.
REEXEC_ARGS=()

# Whether a question may be put on screen at all. `update` turns this off: it is
# the mode meant to run from a script or out of a keybind, and a mode that is
# non-interactive in principle and blocks on a prompt in practice is worse than
# one that never claimed to be. With it off, every question takes its default --
# which for anything destructive is "no" -- and --yes is still there for a run
# that means it.
UI_ASK=1

# WHAT WENT WRONG LIVES IN lib/fail.sh, and it is two ledgers rather than one
# array. A package that will not build is not a reason to abandon the symlinks;
# symlinks that would not link IS a reason to abandon everything after them --
# and the version of this that collected both into one array called FAILED
# could not tell the reader which of the two they had just had. fail_note and
# fail_stop are the whole interface; see the header of that file for why the
# stopping one exits rather than setting a flag.

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

# And the one place a command that needs ROOT goes through, so that "ask for the
# password at the moment it is first needed" is one condition here instead of a
# thing every caller has to remember.
#
# WHY THERE IS A SECOND WRAPPER AND NOT JUST `run sudo`. run_units called
# sudo_begin before every list of units it was handed, whatever was in the list,
# so `./install.sh apply symlinks` -- stow, into a home directory, root nowhere
# near it -- opened with a password prompt. A password asked for to do something
# that does not need one is how people learn to type it without reading what is
# asking.
#
# sudo_begin is idempotent, so the first of these pays for the prompt and starts
# the keepalive and every one after it is free. Everything that argued for
# asking early is still true: the timestamp is still held open for the length of
# the run, which is what an AUR build half an hour in depends on, and `check`
# and --dry-run still never reach a sudo that executes.
run_sudo() {
  sudo_begin
  run sudo "$@"
}

# ---------------------------------------------------------------------------
source "$DOT/lib/ui.sh"
# After ui.sh, which it prints through; before everything that records a
# failure, which is nearly everything else.
source "$DOT/lib/fail.sh"
source "$DOT/lib/state.sh"
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

# AND THEY ARE ASKED, ONCE, WHETHER THEY ARE UNITS AT ALL. A unit file short of
# one of the five required functions used to be found out by calling it: a
# missing `_check` came back as `drift:the check itself failed`, which is the
# same row in the same red as a machine that has genuinely drifted, so the
# reader was sent to look at a machine that was fine. It is a defect in this
# repository and it now says so, in the same words, before any mode has decided
# anything. See unit_assert_contract.
unit_assert_contract

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
# DETECTED BEFORE IT IS ASKED, which is what `check` needs. A doctor that opened
# with a question would be useless in a script and tiresome at a terminal, and
# the machine already knows the answer: whichever compositor is installed is the
# one this machine chose. The flag beats the profile, the profile beats the
# detection, and only a machine with none of the three gets asked.
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

  COMPOSITOR="$(state_get compositor)"
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

# Every stow package except two, and the two are left out for different
# reasons. The compositor's is not missing, only late: it is appended once the
# compositor is known. backup/ IS a stow package and is genuinely not here --
# borgmatic's configuration is linked by hand, along with the machine's own two
# values that never reach git, which README.md sets out under Backups. Putting
# it in this list would start linking a backup policy onto every machine that
# runs this, so its absence is a decision rather than an oversight to tidy up.
#
# seeds/ is not a stow package at all -- it is copied, not linked, see
# seeds/README.md and the seeds unit. There is no `qt` or `xdg` package any
# more either: qt6ct.conf and mimeapps.list were all they held, and both are
# seeds now.
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
  ./install.sh update [OPTIONS]       catch up on what the profile says it wants
  ./install.sh apply <unit>... [OPTS] apply exactly the units you name

MODES
  (none)    The menu. Every unit with its state and a box, the boxes remembered
            in the profile, then everything ticked that is not already in place,
            in dependency order.
  check     Asks every unit how it is and prints a table. Uses no sudo, writes
            nothing, and is safe to run at any moment. Exits 1 when a unit that
            applies to this machine is not ok.
  update    No questions. Applies the units the profile says this machine wants
            and whose check is not already ok, then their reload hooks. Does NOT
            pull unless you ask it to -- see --pull.
  apply     Exactly the units you name, in the right order among themselves.
            It does NOT pull in their requirements -- see --with-requires --
            because the point of it is repairing one row of the check table.

OPTIONS
  -y, --yes             Answer yes to everything. Needed when there is no
                        terminal to ask on.
  -n, --dry-run         Say what would be done and do none of it.
      --pull            update only. git pull --ff-only first.
      --with-requires   apply only. Also apply whatever the named units require.
      --compositor=X    hyprland, niri or both. Taken from the profile, or from
                        what is installed, when it is not given.
      --profile=PATH    Somewhere other than
                        ${XDG_STATE_HOME:-~/.local/state}/dotfiles-profile.
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

  git pull && ./install.sh        the normal way to take an update, with a menu
  git pull && ./install.sh update the same with no questions at all
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
    check|apply|update)
      [[ -n $MODE ]] && { ui_bad "two modes given: $MODE and $1" >&2; exit 2; }
      MODE="$1"
      ;;
    --pull)        PULL=1 ;;
    --with-requires) WITH_REQUIRES=1 ;;
    -y|--yes)      ASSUME_YES=1; REEXEC_ARGS+=("$1") ;;
    -n|--dry-run)  DRY_RUN=1 ;;
    --json)        JSON=1 ;;
    --compositor=*)
      COMPOSITOR="${1#*=}"
      case "$COMPOSITOR" in
        hyprland|niri|both) ;;
        *) ui_bad "--compositor takes hyprland, niri or both, not '$COMPOSITOR'" >&2; exit 2 ;;
      esac
      REEXEC_ARGS+=("$1")
      ;;
    --compositor)
      ui_bad "write it as --compositor=hyprland" >&2; exit 2 ;;
    --profile=*)   PROFILE_PATH="${1#*=}"; REEXEC_ARGS+=("$1") ;;
    --profile)
      ui_bad "write it as --profile=/path/to/file" >&2; exit 2 ;;
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
# SUDO, ONCE, AT THE FIRST THING THAT NEEDS IT, AND KEPT ALIVE UNTIL THE END.
#
# Between the first sudo and the end of an AUR build there can be half an hour,
# which is well past the five-minute default timeout -- so pacman stops in the
# middle of a run and sits waiting for a password behind a wall of build output,
# on a terminal nobody is watching any more. That is what the keepalive is for
# and it has not changed.
#
# WHAT CHANGED IS WHO CALLS IT. This used to run at the top of run_units, for
# every list of units, so a run that needed no root at all still opened with a
# password prompt. It is called from run_sudo now, which means the prompt lands
# on the first command that actually needs root and never appears at all in a
# run that has none.
#
# IDEMPOTENT, because that is what makes calling it from every root command
# cheap: the second call finds the keepalive already running and returns.
#
# NEVER FOR `check` OR UNDER `--dry-run`: neither reaches a run_sudo that
# executes anything, and the DRY_RUN branch below is the belt to that brace.
SUDO_KEEPALIVE_PID=""

sudo_begin() {
  (( DRY_RUN )) && return 0
  [[ -n $SUDO_KEEPALIVE_PID ]] && return 0

  ui_say "   This step needs root. Asking for sudo once, now."
  # ALREADY FATAL BEFORE ANY OF THIS EXISTED, and now it says so in the same
  # shape as every other stop. Nothing below installs, links or enables
  # anything without it, so there is no half of the run left to attempt.
  sudo -v || fail_stop "sudo" \
    "sudo refused, and everything below it needs root." \
    "Check this user is in the wheel group and that /etc/sudoers grants it, then run this again."

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

# WHAT THE PLAN LEAVES OUT, SAID OUT LOUD. Any requirement of the units about to
# run that is not among them and is not already ok, one line each.
#
# All three modes that apply anything now run exactly the list they announce and
# nothing else, so all three owe the reader this: a step that is about to fail
# for a reason already on the table should say so before it does, rather than
# leaving somebody to work out from the output that `symlinks` failed because
# `packages` was never run. <suffix> is how to get the missing one, which is the
# only part that differs between the modes.
notice_unmet_requires() {
  local suffix="$1"; shift
  local dep state
  while IFS=$'\t' read -r dep state; do
    [[ -z $dep ]] && continue
    ui_warn "  note: this needs '$dep', which is $state"
    ui_dim  "        ./install.sh apply $dep$suffix"
  done < <(unit_unmet_requires "$@")
}

# Applies one list of units, skipping the ones this machine has no use for.
# Shared by `apply` and the full run so that the two cannot drift apart.
run_units() {
  local id
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

  # AND THE DEPENDENCY GRAPH IS PART OF WHAT IT CHECKS, over every unit there
  # is and not only over the ones some mode is about to run.
  #
  # WHY HERE. lib/units.sh has two guards -- a cycle, and a requirement naming a
  # unit that does not exist -- and both live in unit_visit, which only
  # `update` and `apply` ever reached. So a malformed `_requires` merged green
  # through CI, which runs `check`, and stopped the machine that ran `update`:
  # the mode whose whole job is to say what is wrong was the one mode that could
  # not see it. A cycle was worse still, because `apply <one unit>` cannot see
  # it either -- unit_order_within does not follow a requirement outside the set
  # it was given -- so the full walk below is the only place in this script that
  # asks the question at all.
  #
  # IT COSTS `check` NOTHING IT DOES NOT ALREADY SPEND, and breaks none of its
  # promises: `_requires` prints ids and is documented to do nothing else, so
  # this walk writes nothing, needs no root, and asks the machine no questions.
  #
  # IT STOPS THE RUN RATHER THAN FILLING A COLUMN, which is unit_visit's own
  # behaviour and is right for what this is: a broken graph is a bug in these
  # files, not a state of this machine, and there is no row it belongs on. Under
  # --json that means an error on stderr and a non-zero exit instead of an
  # array -- which is what a reader piping this into jq should get, rather than
  # well-formed JSON reporting on a registry that cannot be ordered.
  unit_order "${UNIT_IDS[@]}"

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
# apply: exactly the named units, in the right order among themselves.
#
# WHAT IT DOES NOT DO IS PULL IN THEIR REQUIREMENTS, and that is the whole
# design of this mode. `apply` is what somebody reaches for after reading a
# `check` table and seeing one row that is wrong. Expanding the request into its
# dependencies is correct in principle and useless in practice: `symlinks`
# requires `packages`, `packages` is not `ok` while one name out of its
# hundred-odd is missing -- 107 shared, plus the three or four the chosen
# compositor brings -- and so asking to relink one file produced an offer to run
# `pacman -S --needed` over the entire desktop plus four AUR builds. Nobody
# takes that offer, so the mode was unusable for the thing it is best at.
#
# The requirements are still read: they decide the order when several units are
# named together, and any that are outside the set and not already `ok` are
# named on screen with their state, so a step that is about to fail for a known
# reason says so first. `--with-requires` is the way back.
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

  if (( WITH_REQUIRES )); then
    unit_order "${UNIT_ARGS[@]}"
    if (( ${#UNIT_ORDER[@]} > ${#UNIT_ARGS[@]} )); then
      ui_dim "  with what they require: ${UNIT_ORDER[*]}"
    fi
  else
    unit_order_within "${UNIT_ARGS[@]}"
    notice_unmet_requires "   -- or --with-requires to chain them" "${UNIT_ARGS[@]}"
  fi

  run_units "${UNIT_ORDER[@]}"
  fail_report

  # THE STATUS SAYS WHETHER IT DID WHAT IT WAS ASKED, and that is a different
  # audience from the yellow block above. `apply` is the mode a script reaches
  # for -- `./install.sh apply symlinks && hyprctl reload` is an ordinary line
  # -- and a 0 that means "the symlinks unit failed" is a lie told to the one
  # reader that cannot read the words. See fail_clean.
  fail_clean
}

# ---------------------------------------------------------------------------
# update: catch this machine up on what the profile says it wants, and ask
# nobody anything.
#
# THIS IS THE MODE THE PROFILE EXISTS FOR. `check` says what is wrong and does
# nothing; the menu does something and needs somebody at the keyboard. `update`
# is the one in between -- it reads the answers that were given once, applies
# what is both wanted and not already in place, and runs the reload hooks
# afterwards. It is meant to be reachable from a keybind, a cron job or the end
# of a `git pull`.
#
# IT DOES NOT PULL. That is a decision and not an oversight: this repository is
# worked on from several sessions at once, and a `git pull` hidden inside a
# command that also installs things is a surprise at exactly the wrong moment --
# it can bring in a half-finished branch and apply it in the same breath. The
# documented shape is two commands, so the person can see what arrived before it
# runs:
#
#     git pull && ./install.sh update
#
# --pull is there for the unattended case, and is --ff-only so it can never
# produce a merge commit nobody asked for.
mode_update() {
  local id kind todo=() again=()

  # NO QUESTIONS, whatever is attached to stdin. A mode that is non-interactive
  # in principle and blocks on a prompt in practice is worse than one that never
  # claimed to be -- so every question takes its default, which for anything
  # destructive is "no", and --yes remains the way to mean it.
  UI_ASK=0

  state_load
  compositor_resolve update
  stow_packages_resolve

  if (( PULL )); then
    ui_head "pull"
    if ! run git -C "$DOT" pull --ff-only; then
      ui_bad "  the pull did not fast-forward; nothing applied."
      ui_say "  Sort the working tree out and run this again."
      return 1
    fi
    # WHAT ARRIVED IS NOT WHAT IS RUNNING. Everything below this line was
    # sourced before the pull, so a release that changes a unit would be only
    # half in effect -- the new unit files on disk, the old ones in memory.
    # Re-exec with the same arguments minus the pull and let what arrived do the
    # work. Skipped under --dry-run, where nothing was pulled to re-read.
    #
    # AND WITH THE FLAGS IT WAS GIVEN, which it was not. The line that rebuilt
    # this said `again=(update)` plus --yes and dropped everything else, so
    # `update --pull --compositor=hyprland` re-ran as a bare `update` and the
    # second half of the run resolved the compositor from the profile or from
    # what happened to be installed -- on this machine that stowed BOTH
    # compositor packages, linking configuration nobody had asked for, in the
    # mode meant for a cron job and a keybind. --profile went the same way,
    # which is worse in kind: the run reads and writes a different file after
    # the pull from the one it read before it.
    #
    # --pull IS THE ONE FLAG DELIBERATELY LEFT OUT, because it has already
    # happened and passing it on would pull again on every re-exec. Of what is
    # left, --json and a unit id are refused for this mode by the argument
    # parser, --dry-run never reaches this line, and --with-requires belongs to
    # `apply` and is read nowhere in this mode -- so the three flags recorded
    # in REEXEC_ARGS are the whole of what an `update` can be told.
    if (( ! DRY_RUN )); then
      ui_dim "  re-running with what the pull brought in"
      again=(update "${REEXEC_ARGS[@]}")
      exec "$DOT/install.sh" "${again[@]}"
    fi
  fi

  ui_head "update -- $COMPOSITOR"

  # WANTED AND NOT ALREADY OK. The default when the profile has never heard of a
  # unit is "yes": a machine that has never opened the menu should still be
  # caught up by this, and the only thing that keeps a unit out is a "no" that
  # was said out loud.
  for id in "${UNIT_IDS[@]}"; do
    "${id}_available" >/dev/null || continue
    state_unit_wanted "$id" 1 || continue
    kind="$(unit_state_kind "$(unit_state "$id")")"
    [[ $kind == ok || $kind == na ]] && continue
    todo+=("$id")
  done

  if (( ${#todo[@]} == 0 )); then
    ui_ok "  nothing to do"
    return 0
  fi

  # THE LIST ANNOUNCED IS THE LIST APPLIED, which it was not. This said
  # "applying: symlinks seeds nvim cursors laptop" and then called unit_order,
  # which walks _requires and pulls the requirements back in whatever the
  # profile said and whatever `check` had just answered. With `unit.packages 0`
  # written down out loud, the next thing on screen was
  #
  #     applying: symlinks seeds nvim cursors laptop
  #     == Packages ==
  #
  # -- a "no" ignored, and a unit that was already ok done over again, which is
  # the "half an hour of pacman saying there is nothing to do" that mode_setup's
  # own comment says it avoids. unit_order_within orders the same set by
  # _requires and adds nothing to it; what it leaves out is named below rather
  # than being smuggled back in.
  unit_order_within "${todo[@]}"
  ui_say "  applying: ${UNIT_ORDER[*]}"
  notice_unmet_requires "   -- or tick it, so this mode takes it too" "${UNIT_ORDER[@]}"
  run_units "${UNIT_ORDER[@]}"
  fail_report

  # EXITS NON-ZERO WHEN ANYTHING AT ALL DID NOT WORK, notes included, because
  # this is the mode most likely to be run by something that is not a person
  # and will never read the output. A fatal failure never reaches this line:
  # fail_stop ends the run where it happens, with its own non-zero exit.
  fail_clean
}

# ---------------------------------------------------------------------------
# THE MENU. Every unit with its state and a box, the boxes remembered, and one
# confirmation before anything happens.
#
# THE BOX AND THE WORK ARE NOT THE SAME QUESTION, and keeping them apart is what
# makes the profile worth having. A ticked box means "this machine wants this
# unit" -- it is an intention, it survives into the profile, and it is what
# `update` reads later on a machine with nobody at the keyboard. Whether that
# unit needs doing right now is what `_check` answered a moment ago. So the
# boxes are the intention and the run is the intersection: ticked AND not
# already ok.
#
# ON A FIRST RUN there is no profile to read, so a box starts ticked when the
# unit is not ok -- which makes the first Enter mean "yes, set this machine up",
# and every Enter after it mean "yes, catch up on what has changed".
tui_units() {
  local id state kind labels=() ids=() pre="" chosen=() label had_work=()

  for id in "${UNIT_IDS[@]}"; do
    state="$(unit_state "$id")"
    kind="$(unit_state_kind "$state")"
    unit_print_row "$id" "$state"

    # A unit that does not apply to this MACHINE is shown -- knowing that the
    # monitors cannot be read from a TTY is worth knowing -- and is not offered
    # as a choice, because there is nothing to choose.
    #
    # ASKED OF _available AND NOT OF THE STATE, which are two different `na`s
    # and were worth separating. `monitors` says na because there is no
    # compositor to ask, and nothing anybody ticks will change that. `optional`
    # says na because no group has been chosen yet -- and ticking it is exactly
    # how that gets fixed, so leaving it out of the menu would make the one
    # thing it exists for unreachable.
    "${id}_available" >/dev/null || continue

    label="$(printf '%-15s %s' "$id" "$(unit_title "$id")")"
    ids+=("$id")
    labels+=("$label")

    # THE DEFAULT BOX IS "THERE IS WORK HERE": missing or drift start ticked, ok
    # and na start empty. na is not work -- a unit with nothing to say about
    # itself has nothing to do either -- and that is what makes the optional
    # groups opt-in rather than something a first Enter switches on.
    if [[ $kind == missing || $kind == drift ]]; then
      had_work+=("$id")
      state_unit_wanted "$id" 1 && pre+="${pre:+,}$label"
    else
      state_unit_wanted "$id" 0 && pre+="${pre:+,}$label"
    fi
  done
  echo

  (( ${#ids[@]} )) || return 0

  ui_offer_gum
  mapfile -t chosen < <(ui_multi_select "What should this machine have?" "$pre" "${labels[@]}")

  # Back from labels to ids, by exact string.
  #
  # AN EMPTY BOX IS NOT ALWAYS A "NO", and writing it down as one was a real
  # mistake in the first version of this. The units that are already `ok` arrive
  # with their boxes empty because there is nothing to do -- so recording that
  # as `unit.seeds 0` would tell `update`, months later, that this machine does
  # not want its seeds, and the day one of them went missing nothing would put
  # it back.
  #
  # So a "no" is only written when there was something to say no TO: the unit
  # had work outstanding and the box was left empty anyway. Everything else
  # leaves the profile as it found it, which is also what keeps the file down to
  # the lines that mean something.
  local i wanted
  for i in "${!ids[@]}"; do
    wanted=0
    for label in "${chosen[@]}"; do
      [[ $label == "${labels[i]}" ]] && wanted=1
    done

    if (( wanted )); then
      state_set "unit.${ids[i]}" 1
    elif [[ " ${had_work[*]} " == *" ${ids[i]} "* ]]; then
      state_set "unit.${ids[i]}" 0
    fi
  done
}

# ---------------------------------------------------------------------------
# THE OPTIONAL GROUPS, at two levels.
#
# The first is the one anybody wants: one box per pack. The second is
# for the case no set of groups drawn by somebody else can cover -- "gaming, but
# not Steam" -- and is deliberately behind a question, because a menu of a
# hundred package names as the FIRST thing anybody sees would be a worse menu
# for everybody in order to serve the exception.
#
# Both levels land in the profile, and the rule between them is that a package
# with no line of its own follows its group. So a pkg. line is only ever written
# when it disagrees with the group, which is what keeps the file readable and
# what lets a package added to a list in a later release reach the machines that
# ticked its group.
tui_optional() {
  local groups=() labels=() chosen=() pre="" group label count i wanted

  mapfile -t groups < <(optional_groups)
  (( ${#groups[@]} )) || return 0

  for i in "${!groups[@]}"; do
    group="${groups[i]}"
    count="$(pkg_read_list "$(optional_list "$group")" | wc -l)"
    # No comma anywhere in a label: the preselection is handed to `gum choose
    # --selected` as a comma-separated list, and a label carrying one would
    # split into two names that match nothing.
    label="$(printf '%-10s %s packages' "$group" "$count")"
    labels+=("$label")
    state_group_wanted "$group" && pre+="${pre:+,}$label"
  done

  mapfile -t chosen < <(ui_multi_select "Optional packages -- each one is a pack" "$pre" "${labels[@]}")

  for i in "${!groups[@]}"; do
    wanted=0
    for label in "${chosen[@]}"; do
      [[ $label == "${labels[i]}" ]] && wanted=1
    done
    state_set "group.${groups[i]}" "$wanted"
  done

  # ---------------------------------------------------------------------
  # THE DRILL-DOWN, AND THE TWO RUNS IT IS NOT FOR.
  #
  # No terminal: there is nothing to drill with, and a run with nobody at the
  # keyboard has already had its answer from the profile.
  #
  # --yes: ui_confirm returns 0 under ASSUME_YES without reading anything,
  # which is exactly right for "shall I do this?" and fatal for a loop whose
  # condition is "shall I ask you again?" -- the answer can never be no, so the
  # loop can never end. On a pty with --yes and nothing typed it asked this
  # 1,864 times in fifteen seconds and had to be killed. The fix is not a
  # bound on the loop: --yes means "do not ask me", and a sub-menu that exists
  # only to be typed into is the one thing --yes cannot answer for. So it is
  # declined, out loud, and the packs above stand as the answer.
  ui_has_tty || return 0
  if (( ASSUME_YES )); then
    ui_dim "   --yes: the per-package menu needs typing, so it is skipped."
    ui_dim "   The packs above are the answer; edit $(state_path) to disagree."
    return 0
  fi

  while ui_confirm "  Open one of them and pick packages one at a time?" n; do
    group="$(ui_choose_one 1 "${groups[@]}")"
    tui_optional_packages "$group"
  done
}

# One group, package by package. What is written down is only the disagreement:
# a package that matches its group's answer has its line REMOVED rather than
# written as the same value, so the file says what is unusual about this machine
# and nothing else.
tui_optional_packages() {
  local group="$1" names=() chosen=() pre="" name label wanted group_default=0

  mapfile -t names < <(pkg_read_list "$(optional_list "$group")")
  (( ${#names[@]} )) || return 0
  state_group_wanted "$group" && group_default=1

  for name in "${names[@]}"; do
    state_pkg_wanted "$group" "$name" && pre+="${pre:+,}$name"
  done

  mapfile -t chosen < <(ui_multi_select "$group -- ${#names[@]} packages" "$pre" "${names[@]}")

  for name in "${names[@]}"; do
    wanted=0
    for label in "${chosen[@]}"; do
      [[ $label == "$name" ]] && wanted=1
    done
    if (( wanted == group_default )); then
      state_unset "pkg.$group.$name"
    else
      state_set "pkg.$group.$name" "$wanted"
    fi
  done
}

# ---------------------------------------------------------------------------
# The full run: the menu, then everything ticked that is not already in place.
mode_setup() {
  local id todo=() kind

  state_load
  compositor_resolve setup
  state_set compositor "$COMPOSITOR"
  stow_packages_resolve

  ui_head "$COMPOSITOR"
  echo

  tui_units

  # ASKED BEFORE THE PROFILE IS SAVED AND BEFORE ANYTHING RUNS, because the
  # groups decide what the optional unit will install and there is no sense
  # ticking the unit and then being asked nothing.
  if state_unit_wanted optional 0; then
    tui_optional
  fi

  state_save

  # THE INTERSECTION. Ticked says what this machine wants; _check says what it
  # is short of. Applying a unit that is already ok is harmless -- every one of
  # them is idempotent -- but it is also half an hour of pacman saying "there is
  # nothing to do", which is how a run stops being worth watching.
  for id in "${UNIT_IDS[@]}"; do
    kind="$(unit_state_kind "$(unit_state "$id")")"
    [[ $kind == ok || $kind == na ]] && continue
    state_unit_wanted "$id" 0 && todo+=("$id")
  done

  if (( ${#todo[@]} == 0 )); then
    echo
    ui_ok "  Nothing to do: everything ticked is already in place."
    ui_dim "  The profile is at $(state_path)"
    return 0
  fi

  # ORDERED AMONG THEMSELVES AND NOTHING ELSE ADDED, for the reason written out
  # in mode_update: unit_order would put a unit back that the boxes above said
  # no to, and the intersection three lines up is the whole point of the boxes.
  unit_order_within "${todo[@]}"

  echo
  ui_say "  Would apply: ${UNIT_ORDER[*]}"
  notice_unmet_requires "   -- or tick it and run this again" "${UNIT_ORDER[@]}"
  ui_confirm "  Go ahead?" || { ui_say "  Nothing done."; return 0; }

  run_units "${UNIT_ORDER[@]}"

  echo
  ui_ok "== Ready =="
  cat <<'END'

One thing is still yours, and it is a decision rather than a chore:

  The monitor layout, if the table above listed a screen as not recorded.
  Which screen is the main one and where the others sit around it cannot be
  read off an EDID. Arrange them, then:

      desktop-monitors seed

  or do it from the settings window, SUPER + C, which applies a change live and
  puts it back unless you confirm it.

Outside $HOME, nothing here is automated at all: no unit writes to /etc or
reports on what is there. Two of them read it to answer a question about this
machine -- whether zsh is in /etc/shells, whether [multilib] is on -- and that
is the whole of the traffic. system/ is a tracked record of what this machine
needs out there, kept as documentation and applied by hand -- read
system/README.md when you need it.

Everything else has a unit. To see where this machine stands at any moment:

      ./install.sh check
END

  # LAST, AND NOT BEFORE THE HAND-OFF ABOVE. The notes are the part with
  # something to act on; the paragraph above them is the same on every machine.
  # Printed first, the notes scroll away behind advice nobody needed twice --
  # which is how "2 thing(s) did not work" came to be something people read
  # after the fact in a screenshot.
  fail_report
  # And the same non-zero status the other two modes give, for the same reason:
  # `git pull && ./install.sh && reboot` is a line somebody will write.
  fail_clean
}

# ---------------------------------------------------------------------------
case "$MODE" in
  check)  mode_check ;;
  update) mode_update ;;
  apply)
    (( ${#UNIT_ARGS[@]} )) || { ui_bad "apply needs at least one unit id" >&2; usage >&2; exit 2; }
    mode_apply
    ;;
  *) mode_setup ;;
esac
