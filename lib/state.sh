# shellcheck shell=bash
# The profile: what this machine was told it wants.
#
# WHY THERE IS ONE AT ALL. Everything the installer does is either derivable
# from the machine or it is a decision, and the decisions are the ones that used
# to be lost the moment the script exited: which compositor, whether this is a
# laptop, which optional package groups. Without somewhere to keep them,
# `update` cannot exist -- a non-interactive mode has nothing to be
# non-interactive ABOUT.
#
# THE FORMAT IS THE ONE THIS REPOSITORY ALREADY USES. `desktop-tweak` and
# `laptop-modules` keep TSV, one `key<TAB>value` per line, sorted, under
# ~/.local/state. Same shape here, for the same reasons: it diffs, it greps, it
# can be edited in any editor, and `sort` makes the file's order independent of
# the order things were written in -- so a run that changes one value produces a
# one-line diff instead of a reshuffle.
#
#   compositor          niri
#   gpu.vendor          nvidia
#   group.apps          1
#   pkg.apps.gimp       0
#   unit.optional       1
#
# THE pkg. LINES ARE OVERRIDES AND NOT A MANIFEST. A package with no pkg. line
# follows its group, so ticking a whole pack -- the common case by far -- costs
# one line rather than twelve, and adding a package to a list in a later release
# reaches machines that ticked the group without anyone re-running a menu.

declare -A PROFILE=()
PROFILE_PATH=""
PROFILE_LOADED=0

state_path() {
  if [[ -n $PROFILE_PATH ]]; then
    printf '%s\n' "$PROFILE_PATH"
  else
    printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-profile"
  fi
}

# A MISSING FILE IS A VALID PROFILE and not an error: it is what a first run
# looks like, and everything below has a default for exactly that reason.
state_load() {
  (( PROFILE_LOADED )) && return 0
  PROFILE_LOADED=1

  local path key value
  path="$(state_path)"
  [[ -f $path ]] || return 0

  # IFS is a literal tab, so a value may contain spaces -- which matters
  # already: nothing here does today, but a monitor description would, and the
  # format is shared with files that hold them.
  #
  # `|| [[ -n $key ]]` IS WHAT READS A LAST LINE WITH NO NEWLINE ON IT. `read`
  # returns non-zero at end of file even when it has just filled the variables
  # from a final unterminated line, so without this the loop exited before the
  # body ran and the line was silently gone. state_save always terminates what
  # it writes, so a file this script wrote could never show it -- but this file
  # is documented as one to edit by hand, in as many words, at the end of a run
  # ("edit $(state_path) to disagree"), and an editor that leaves off the final
  # newline is an ordinary thing to have. What it lost was the quietest possible
  # half of a profile: `unit.seeds<TAB>0` written last read as never having been
  # said at all, and `update` went and applied the unit that had been told no.
  while IFS=$'\t' read -r key value || [[ -n $key ]]; do
    [[ -z $key || $key == '#'* ]] && continue
    PROFILE["$key"]="$value"
  done < "$path"
}

state_get() {
  state_load
  printf '%s\n' "${PROFILE[$1]:-${2:-}}"
}

state_has() {
  state_load
  [[ -n ${PROFILE[$1]+set} ]]
}

state_set() {
  state_load
  PROFILE["$1"]="$2"
}

state_unset() {
  state_load
  unset "PROFILE[$1]"
}

# ---------------------------------------------------------------------------
# WRITTEN THROUGH A TEMPORARY FILE AND ONE mv, which is the same rule the
# monitor store follows. A profile truncated halfway through -- the machine
# losing power, the terminal being closed, the disk filling -- would come back
# as a file that parses perfectly and says something different from what the
# person chose, and a half-written preferences file is worse than none because
# nothing about it looks wrong.
#
# LC_ALL=C on the sort, so the file a Spanish system writes is byte-identical to
# the one an English system writes. The collation of `.` against a letter is not
# the same in every locale, and this file is compared across machines.
state_save() {
  local path dir tmp key
  path="$(state_path)"
  dir="$(dirname "$path")"

  if (( ${DRY_RUN:-0} )); then
    printf '%s   would write %s\n' "$C_DIM" "$path$C_RESET" >&2
    return 0
  fi

  mkdir -p "$dir"
  tmp="$(mktemp "$path.XXXXXX")"
  {
    for key in "${!PROFILE[@]}"; do
      printf '%s\t%s\n' "$key" "${PROFILE[$key]}"
    done
  } | LC_ALL=C sort > "$tmp"
  mv "$tmp" "$path"
}

# ---------------------------------------------------------------------------
# THE THREE QUESTIONS THE REST OF THE INSTALLER ASKS THIS FILE.
#
# Each takes the answer the machine would give as its default, so a profile that
# has never been written behaves exactly as it did before there was one.

# Is this unit ticked? Unticked is a deliberate "no, not on this machine" and is
# respected by `update`; never having been asked is not.
state_unit_wanted() {
  local id="$1" default="${2:-1}"
  [[ "$(state_get "unit.$id" "$default")" == 1 ]]
}

# Is this optional group ticked? Groups are opt-in, so the default is off.
state_group_wanted() {
  [[ "$(state_get "group.$1" 0)" == 1 ]]
}

# Is this package from this group wanted? The group's answer unless the package
# has a line of its own, which is what keeps the file short.
state_pkg_wanted() {
  local group="$1" pkg="$2" group_default=0
  state_group_wanted "$group" && group_default=1
  [[ "$(state_get "pkg.$group.$pkg" "$group_default")" == 1 ]]
}
