# shellcheck shell=bash
# WHAT WENT WRONG, AND WHETHER IT MATTERS.
#
# This file exists because those were the same thing for too long. Everything
# that failed went into one array called FAILED and the run carried on, so a
# run that could not link a single dotfile and a run that could not build GIMP
# both ended with
#
#   2 thing(s) did not work:
#     symlinks: did not finish
#     apps: an AUR build failed
#
# -- two lines of equal weight, no way to tell which one leaves the machine
# unusable, and nothing at all about what to do next. The rule this replaces it
# with is the one the owner stated: a failure is always reported; if the thing
# that failed is indispensable the run STOPS so it gets corrected, and if it is
# not, it is said plainly and the run carries on.
#
# TWO LEDGERS, AND ONLY ONE OF THEM ACCUMULATES.
#
#   fail_note   the machine still comes up. Recorded, printed at the end, exit
#               status unaffected. There can be any number of these.
#   fail_stop   the machine would be left half configured. Printed with what to
#               do about it, together with every note collected so far, and the
#               run ENDS. There is at most one, because it is the last thing
#               that happens.
#
# WHY fail_stop EXITS RATHER THAN SETTING A FLAG. A flag would have to be
# checked by every caller between the failure and the top of the run --
# pkg_install, the unit's _apply, unit_apply, run_units -- and the first caller
# that forgot would carry on into exactly the half-configured state this is
# meant to prevent. Exiting cannot be forgotten. The cost is that it must never
# be called from a subshell, where `exit` would leave only the subshell and the
# run would continue as if nothing had happened; that is what the BASHPID guard
# below is for, and it is the reason the contract in lib/units.sh says _check
# and _available report their troubles by what they PRINT.
#
# The EXIT trap installed by sudo_begin still runs, so the sudo keepalive is
# killed on the way out.

# Each record is one line: unit, TAB, what happened, TAB, what to do about it
# (which may be empty). A tab because a package name cannot contain one and a
# remedy is a whole sentence that may well contain a colon.
FAIL_NOTES=()

# ---------------------------------------------------------------------------
# A failure the machine survives.
#
# <unit> is the id it belongs to, so the summary can group by the thing the
# reader would run again. <what> says what did not happen, by name wherever a
# name exists -- "an AUR build failed" was the shape of the old messages and it
# is the shape that sent someone to a second machine with no idea which package
# to look at. <remedy> is optional only because a few failures genuinely have
# no next step beyond running this again.
fail_note() {
  local unit="$1" what="$2" remedy="${3:-}"
  FAIL_NOTES+=("$(printf '%s\t%s\t%s' "$unit" "$what" "$remedy")")
}

# ---------------------------------------------------------------------------
# A failure the machine does not survive. DOES NOT RETURN.
#
# <remedy> is not optional here, and that is deliberate: the whole reason for
# stopping is that a person has to intervene, so a stop with nothing to do next
# is a dead end with extra steps.
fail_stop() {
  local unit="$1" what="$2" remedy="$3"

  # `exit` in a subshell ends the subshell and nothing else, which would turn a
  # fatal failure into a silent one -- the worst possible direction. Nothing in
  # the run calls this from a subshell today; this is here so that the day
  # somebody does, they are told rather than left with a run that quietly
  # carried on past a stop.
  if [[ ${BASHPID:-$$} != "$$" ]]; then
    ui_bad "   BUG: fail_stop called from a subshell ($unit), so the run cannot" >&2
    ui_bad "   actually be stopped. Report this." >&2
  fi

  echo
  ui_bad "== Stopped at $unit =="
  echo
  ui_bad "  $what"
  echo
  ui_say "  This one is indispensable, so the run stops here rather than leaving"
  ui_say "  the machine half configured and letting it be found out later."
  echo
  ui_say "  What to do next:"
  printf '    %s\n' "$remedy"
  echo
  ui_say "  Then run this again. Everything that already worked is skipped."

  # The notes come after the stop and not before it, so the thing that ended
  # the run is not the first thing to scroll off the top.
  fail_report_notes

  exit 1
}

# ---------------------------------------------------------------------------
# The notes, aligned so the unit column can be read down rather than across.
#
# SILENT WHEN THERE ARE NONE. A summary that prints "0 notes" on every clean run
# teaches people to skip the summary, which is the one habit that makes all of
# this pointless.
fail_report_notes() {
  local record unit what remedy width=0

  (( ${#FAIL_NOTES[@]} )) || return 0

  for record in "${FAIL_NOTES[@]}"; do
    IFS=$'\t' read -r unit what remedy <<<"$record"
    (( ${#unit} > width )) && width=${#unit}
  done

  echo
  ui_warn "== ${#FAIL_NOTES[@]} thing(s) to know =="
  ui_dim "  None of these stop the desktop coming up."
  echo

  for record in "${FAIL_NOTES[@]}"; do
    IFS=$'\t' read -r unit what remedy <<<"$record"
    printf '  %s%-*s%s  %s\n' "$C_YELLOW" "$width" "$unit" "$C_RESET" "$what"
    [[ -n $remedy ]] && printf '  %*s  %s-> %s%s\n' "$width" "" "$C_DIM" "$remedy" "$C_RESET"
  done

  # NOT THE `[[ -n $remedy ]]` TEST'S ANSWER. Without this the function returns
  # whatever the last note's test evaluated to, so a note with no remedy -- the
  # third argument is optional -- would make this return 1, and install.sh runs
  # under `set -e` with fail_report called as a bare command at the end of a
  # mode. The summary would take the run down with it on its very last line.
  return 0
}

# What a completed run prints. There can be no stop here by construction -- a
# stop ends the run where it happens -- so this is the notes and a word about
# what they mean.
fail_report() {
  (( ${#FAIL_NOTES[@]} )) || return 0
  fail_report_notes
  echo
  ui_dim "  The run finished. Nothing above needed it to stop."
}

# For `update`, which is the one mode meant to be read by a machine rather than
# a person. Its existing rule is kept exactly: anything at all that did not work
# is a non-zero exit, note or not, because the caller will never see the words.
# The interactive modes do not do this -- a note is a note, and a person who has
# just been told about it in yellow does not also need a failing exit status.
fail_clean() {
  (( ${#FAIL_NOTES[@]} == 0 ))
}
