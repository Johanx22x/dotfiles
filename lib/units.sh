# shellcheck shell=bash
# The runner: registration, dependency order, state, and dispatch.
#
# THIS FILE KNOWS NOTHING ABOUT ANY PARTICULAR UNIT, and that is the whole
# design. It can name them, order them, ask each one how it is and tell each
# one to act -- and if it ever grows a `case "$id" in packages)` the separation
# is gone and the next unit is a change in three files instead of one new one.
#
# THE CONTRACT. Every lib/units/NN-<id>.sh defines six functions prefixed with
# its id. Five are required:
#
#   <id>_meta       prints two lines: a title, then one line of detail
#   <id>_requires   prints the ids this unit needs applied first, or nothing
#   <id>_available  0 if it applies to this machine, 1 if not -- and when it
#                   says 1 it may print a short reason, which is what the
#                   status column shows. Writes nothing.
#   <id>_check      prints exactly one of:
#                     ok              nothing to do
#                     missing:<n>     n things are not there
#                     drift:<what>    it is there and it is not what it should be
#                     na:<why>        cannot be answered here
#                   MUST NOT use sudo and MUST NOT write anything.
#   <id>_apply      does it. 0 on success. Must be safe to run twice.
#
# and the sixth, <id>_post, is optional: reload hooks that run after a
# successful apply, whose RETURN VALUE is never allowed to fail the run.
#
# HOW A UNIT SAYS HOW BADLY IT FAILED, which is not part of the six. Returning
# non-zero from _apply means "this did not work" and nothing more; the runner
# records it as a note and goes on. A unit that has found something a person
# must deal with before the machine is usable calls fail_stop itself, which
# prints the reason with what to do about it and ends the run. That is
# available from _apply and from _post alike -- a _post whose return value
# cannot fail the run can still have discovered that /boot is half written --
# and it is deliberately not a seventh function here, because severity belongs
# to the individual failure and not to the unit: `packages` failing to install
# one name and `packages` finding pacman's sync databases empty are not the
# same kind of news. See lib/fail.sh.
#
# NEITHER MAY BE CALLED FROM _check OR _available. Both of those run in command
# substitutions, where `exit` ends only the subshell; they report their troubles
# by what they print, which is what the four words above are for.
#
# WHY `_check` IS THE HARD ONE. It is called by `check`, which must be safe to
# run at any moment on a working machine, and by the menu, which calls it for
# every unit before drawing a single line. So it runs constantly, on a machine
# in any state, with no privileges -- and a unit that cannot answer without
# root says `na:needs root` rather than asking for it.

UNIT_IDS=()
declare -A UNIT_SEEN=()
declare -A UNIT_TITLE=()
declare -A UNIT_DETAIL=()

# Called at the bottom of each unit file. The NN- prefix on the filename fixes
# the order they are sourced in, which is the order they are listed in; the
# order they are APPLIED in comes from _requires and is worked out below.
unit_register() {
  local id="$1"
  if [[ -n ${UNIT_SEEN[$id]:-} ]]; then
    ui_bad "two units are called '$id'" >&2
    exit 1
  fi
  UNIT_SEEN[$id]=1
  UNIT_IDS+=("$id")
}

unit_exists() { [[ -n ${UNIT_SEEN[${1:-}]:-} ]]; }

# ---------------------------------------------------------------------------
# THE CONTRACT AT THE TOP OF THIS FILE, ASSERTED RATHER THAN ASSUMED.
#
# unit_register only ever asked whether two units answered to the same id, so
# the other half of registration -- that the unit actually defines the five
# functions everything below calls -- was left to be discovered by calling one
# of them. A missing `<id>_check` failed as `command not found`, which
# unit_state turns into `drift:the check itself failed`: the same row, in the
# same red, as a machine whose configuration has genuinely been changed under
# it. The reader is told to go and look at a machine that is fine.
#
# CHEAP ENOUGH TO DO ON EVERY RUN. Five `declare -F` per unit is a few dozen
# lookups in the shell's own function table -- no file is opened and no unit
# function is called -- and it happens once, at startup, before any mode has
# decided anything. That buys the same answer for all four modes, which is the
# point: a unit file that is short of a function is a defect in this repository
# and every mode should say so in the same words rather than three of them
# limping on and the fourth blaming the machine.
#
# _post IS NOT IN THE LIST because it is documented as optional, and
# unit_apply asks `declare -F` before queueing it for exactly that reason.
UNIT_CONTRACT_FNS=(meta requires available check apply)

unit_assert_contract() {
  local id fn missing=0
  for id in "${UNIT_IDS[@]}"; do
    for fn in "${UNIT_CONTRACT_FNS[@]}"; do
      declare -F "${id}_${fn}" >/dev/null && continue
      ui_bad "unit '$id' does not define ${id}_${fn}" >&2
      missing=1
    done
  done
  (( missing )) && {
    ui_say "Every lib/units/NN-<id>.sh must define all of: ${UNIT_CONTRACT_FNS[*]}" >&2
    exit 1
  }
  return 0
}

# _meta is called once per unit and cached. It is called for every unit on
# every run -- the help text lists them all -- so it must stay two `echo`s and
# never look at the machine.
unit_load_meta() {
  local id="$1" line n=0
  [[ -n ${UNIT_TITLE[$id]:-} ]] && return 0
  while IFS= read -r line; do
    case $n in
      0) UNIT_TITLE[$id]="$line" ;;
      1) UNIT_DETAIL[$id]="$line" ;;
    esac
    n=$(( n + 1 ))
  done < <("${id}_meta")
  UNIT_TITLE[$id]="${UNIT_TITLE[$id]:-$id}"
  UNIT_DETAIL[$id]="${UNIT_DETAIL[$id]:-}"
}

unit_title()  { unit_load_meta "$1"; printf '%s\n' "${UNIT_TITLE[$1]}"; }
unit_detail() { unit_load_meta "$1"; printf '%s\n' "${UNIT_DETAIL[$1]}"; }

# ---------------------------------------------------------------------------
# ORDER. Depth-first over _requires, so a unit is always listed after
# everything it needs. Duplicates collapse, which is what makes
# `apply palette symlinks` and `apply symlinks palette` the same run.
#
# A CYCLE IS A BUG IN THIS REPOSITORY, not something a user can fix, so it
# stops the run and names the unit rather than recursing until bash gives up.
UNIT_ORDER=()
declare -A UNIT_MARK=()

# When this is set, the walk uses _requires to decide who goes FIRST and never
# to decide who goes at all: a requirement outside the set is looked at, used
# for ordering, and not added. See unit_order_within.
declare -A UNIT_ORDER_SET=()
UNIT_ORDER_RESTRICT=0

unit_order() {
  local id
  UNIT_ORDER=()
  UNIT_MARK=()
  UNIT_ORDER_SET=()
  UNIT_ORDER_RESTRICT=0
  for id in "$@"; do
    unit_visit "$id"
  done
}

# ORDER AMONG EXACTLY THESE, AND PULL IN NOTHING ELSE.
#
# `apply` is the surgical tool: somebody has read a `check` table, seen one row
# that is wrong and named it. Expanding that into its requirements is correct in
# principle and useless in practice -- `apply symlinks` reaches `packages`, and
# a `packages` that is one name short of 119 is not `ok`, so asking for one
# missing symlink produced an offer to run `pacman -S --needed` over the whole
# desktop plus four AUR builds. The requirement was real and the answer was
# still wrong.
#
# So the named set is the plan, ordering still comes from _requires, and
# anything required from outside the set is REPORTED rather than added -- see
# unit_unmet_requires. `--with-requires` is the way back to the other behaviour
# for somebody who wants it.
unit_order_within() {
  local id
  UNIT_ORDER=()
  UNIT_MARK=()
  UNIT_ORDER_SET=()
  UNIT_ORDER_RESTRICT=1
  for id in "$@"; do UNIT_ORDER_SET["$id"]=1; done
  for id in "$@"; do unit_visit "$id"; done
}

unit_visit() {
  local id="$1" dep
  case "${UNIT_MARK[$id]:-}" in
    done) return 0 ;;
    open) ui_bad "dependency cycle at unit '$id'" >&2; exit 1 ;;
  esac
  UNIT_MARK[$id]=open

  while IFS= read -r dep; do
    [[ -z $dep ]] && continue
    if ! unit_exists "$dep"; then
      ui_bad "unit '$id' requires '$dep', which does not exist" >&2
      exit 1
    fi
    if (( UNIT_ORDER_RESTRICT )) && [[ -z ${UNIT_ORDER_SET[$dep]:-} ]]; then
      continue
    fi
    unit_visit "$dep"
  done < <("${id}_requires")

  UNIT_MARK[$id]="done"
  UNIT_ORDER+=("$id")
}

# Requirements of the given units that are NOT among them and are not already
# ok, as "<id>\t<state>". What `apply` prints instead of quietly growing.
unit_unmet_requires() {
  local id dep state seen=()
  declare -A want=()
  for id in "$@"; do want["$id"]=1; done

  for id in "$@"; do
    while IFS= read -r dep; do
      [[ -z $dep ]] && continue
      [[ -n ${want[$dep]:-} ]] && continue
      [[ " ${seen[*]} " == *" $dep "* ]] && continue
      seen+=("$dep")
      state="$(unit_state "$dep")"
      [[ "$(unit_state_kind "$state")" == ok ]] && continue
      printf '%s\t%s\n' "$dep" "$state"
    done < <("${id}_requires")
  done
}

# ---------------------------------------------------------------------------
# STATE. One line, always, whatever the unit does.
#
# _available is asked first and its answer wins: a unit that does not apply to
# this machine is not asked how it is, because the answer would be about
# something that is not there. Its stdout when it declines is the reason, which
# is why it is captured rather than let through.
unit_state() {
  local id="$1" reason out

  if ! reason="$("${id}_available")"; then
    printf 'na:%s\n' "${reason:-not applicable on this machine}"
    return 0
  fi

  # A check that crashes is a defect in this repository and must not read as
  # "fine". It is reported as drift, which is the state that means "look at
  # this", and the shell's own error output is left alone so it can be found.
  if ! out="$("${id}_check")"; then
    printf 'drift:the check itself failed\n'
    return 0
  fi

  # First line only. A unit that prints two has a bug, and truncating it here
  # keeps that bug from tearing the table apart.
  printf '%s\n' "${out%%$'\n'*}"
}

unit_state_kind() { printf '%s\n' "${1%%:*}"; }
unit_state_note() {
  local state="$1"
  [[ $state == *:* ]] && printf '%s\n' "${state#*:}" || printf '\n'
}

# ---------------------------------------------------------------------------
# THE TABLE. Two columns of state and then the unit, because the eye scans the
# left edge for the thing that is wrong.
unit_print_row() {
  local id="$1" state="$2" kind note colour
  kind="$(unit_state_kind "$state")"
  note="$(unit_state_note "$state")"

  case "$kind" in
    ok)      colour="$C_GREEN" ;;
    missing) colour="$C_YELLOW" ;;
    drift)   colour="$C_RED" ;;
    *)       colour="$C_DIM" ;;
  esac

  # The title is always there and the note is appended to it, rather than one
  # replacing the other. A row reading "drift  symlinks  15 in the way" is a
  # sentence with no subject the first time you see it; the unit's own name for
  # itself is what makes the count mean something.
  printf '  %s%-8s%s %-15s %s%s\n' \
    "$colour" "$kind" "$C_RESET" "$id" "$(unit_title "$id")" \
    "${note:+ -- $note}"
}

# ---------------------------------------------------------------------------
# JSON, for anything that wants to read this rather than look at it. Written by
# hand rather than through jq because jq is a package in one of these lists and
# `check` has to work on a machine that has not run the installer yet.
unit_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

unit_print_json() {
  local first=1 id state
  printf '[\n'
  for id in "$@"; do
    state="$(unit_state "$id")"
    (( first )) || printf ',\n'
    first=0
    printf '  {"id": "%s", "title": "%s", "state": "%s", "kind": "%s", "note": "%s"}' \
      "$(unit_json_escape "$id")" \
      "$(unit_json_escape "$(unit_title "$id")")" \
      "$(unit_json_escape "$state")" \
      "$(unit_json_escape "$(unit_state_kind "$state")")" \
      "$(unit_json_escape "$(unit_state_note "$state")")"
  done
  printf '\n]\n'
}

# ---------------------------------------------------------------------------
# APPLYING. One unit, with the dry run and the failure bookkeeping in one place
# so that no unit has to remember either.
#
# A UNIT THAT MERELY RETURNS NON-ZERO DOES NOT STOP THE RUN, and that is a
# statement about what silence means rather than about how serious failures
# are. The units are ordered by _requires, so anything that genuinely could not
# proceed said so through that; everything else is independent, and abandoning
# the symlinks because an AUR package would not build is how this script used
# to lose the part that mattered.
#
# A UNIT THAT MEANS "STOP" SAYS SO ITSELF, by calling fail_stop, which does not
# return. That is deliberately NOT a seventh member of the contract at the top
# of this file: a `<id>_severity` would be one answer for a whole unit, and the
# units that have a fatal path have a non-fatal one beside it -- `packages`
# failing to install one name is not the same as `packages` finding pacman's
# sync databases empty. The severity belongs to the failure, so it is chosen
# where the failure is detected, and this file goes on knowing the name of no
# unit at all.
#
# So the entry below is the DEFAULT, and it is the mild one on purpose: a unit
# that returned non-zero without saying anything about how bad it was has not
# earned the right to end the run.
UNIT_POST=()

unit_apply() {
  local id="$1"

  ui_head "$(unit_title "$id")"
  ui_dim "   $(unit_detail "$id")"

  if ! "${id}_apply"; then
    ui_bad "   $id did not finish"
    fail_note "$id" "it did not finish, and did not say why" \
      "./install.sh apply $id   -- the output above it is the only account of what happened"
    return 0
  fi

  # _post is optional and deferred: reloads are cheap but they are also loud,
  # and running them once at the end means a run that applies four units does
  # not reload the same daemon four times.
  if declare -F "${id}_post" >/dev/null; then
    UNIT_POST+=("$id")
  fi
  return 0
}

# Everything queued by unit_apply, in the order it was queued.
#
# NEVER FATAL, BY CONTRACT. A _post is a reload, and a reload that fails on a
# machine with no session running -- which is every machine being set up for
# the first time -- must not undo a run that otherwise worked.
unit_run_post() {
  local id
  (( ${#UNIT_POST[@]} )) || return 0
  for id in "${UNIT_POST[@]}"; do
    # RECORDED AS WELL AS PRINTED, WHICH IT WAS NOT BEFORE. Never fatal, by the
    # contract above -- but a reload that silently did not happen is the exact
    # shape of "it looks applied and does not behave applied", and a line in
    # yellow half an hour up the screen is not a report.
    "${id}_post" || fail_note "$id" \
      "the reload step did not work, so the change is on disk and not in effect" \
      "Log out and back in, or run: ./install.sh apply $id"
  done
  UNIT_POST=()
}
