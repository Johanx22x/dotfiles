# shellcheck shell=bash
# Everything that reaches a person: colour, headings, questions.
#
# KEPT APART FROM THE ENGINE ON PURPOSE. The modes are front-ends over one
# registry of units, and a unit that drew its own decorations would tie the two
# back together -- `check --json` would grow escape codes, and a unit could not
# be run from a script without its output being written for a terminal.
# Everything in here is what a unit is allowed to call to say something.

# COLOUR ONLY WHEN SOMEBODY IS LOOKING AT IT. `check` is meant to be piped into
# grep and `check --json` into jq, and escape codes in either is a bug, not a
# cosmetic problem. NO_COLOR is honoured because it costs one condition and
# every other tool on this machine honours it.
if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  C_RESET=$'\033[0m'
  C_BLUE=$'\033[1;34m'
  C_GREEN=$'\033[1;32m'
  C_RED=$'\033[1;31m'
  C_YELLOW=$'\033[1;33m'
  C_DIM=$'\033[2m'
else
  C_RESET='' C_BLUE='' C_GREEN='' C_RED='' C_YELLOW='' C_DIM=''
fi

ui_head() { printf '%s== %s ==%s\n' "$C_BLUE" "$*" "$C_RESET"; }
ui_ok()   { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
ui_bad()  { printf '%s%s%s\n' "$C_RED" "$*" "$C_RESET"; }
ui_warn() { printf '%s%s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
ui_dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
ui_say()  { printf '%s\n' "$*"; }

# Says what just happened -- and stays quiet under --dry-run, where nothing
# did. "linked" printed underneath "would run: stow ..." is a small lie, and a
# dry run whose output cannot be trusted is worse than no dry run at all.
ui_did()  { (( ${DRY_RUN:-0} )) || ui_ok "$*"; }

# ---------------------------------------------------------------------------
# QUESTIONS, AND THE MACHINE THAT CANNOT BE ASKED ONE.
#
# The compositor prompt in the previous version of this script was a bare
# `read` inside a `while`, which means: with no terminal on stdin, `read`
# returns non-zero immediately, the loop spins on an empty answer, and under
# `set -e`... the script exits 1 without printing one word about why. That is
# what happens over ssh with a redirected stdin, in a chroot, and in CI, and it
# is indistinguishable from a crash.
#
# So every question goes through here, every question has a default, and no
# terminal is a state that is DETECTED and SAID rather than fallen into.
ui_has_tty() { [[ -t 0 ]]; }

# Printed at most once. A run with twelve questions and no terminal should
# explain itself, not repeat itself twelve times.
UI_NOTTY_SAID=0
ui_no_tty_notice() {
  (( UI_NOTTY_SAID )) && return 0
  UI_NOTTY_SAID=1
  ui_warn "   Nothing is attached to stdin, so nothing can be asked."
  ui_say  "   Every question below is answered with its default. Pass --yes to"
  ui_say  "   say yes to all of them instead."
}

# ui_confirm <question> [default]
#
# default is "y" or "n" and is what an empty answer, --yes, or the absence of a
# terminal produces. Returns 0 for yes.
ui_confirm() {
  local question="$1" default="${2:-n}" reply

  if (( ${ASSUME_YES:-0} )); then
    printf '%s%s%s [y/N] %sy (--yes)%s\n' \
      "$C_YELLOW" "$question" "$C_RESET" "$C_DIM" "$C_RESET"
    return 0
  fi

  if ! ui_has_tty; then
    ui_no_tty_notice
    [[ $default == y ]]
    return
  fi

  read -rp "$(printf '%s%s%s [%s] ' "$C_YELLOW" "$question" "$C_RESET" \
    "$([[ $default == y ]] && echo 'Y/n' || echo 'y/N')")" reply
  reply="${reply:-$default}"
  [[ $reply =~ ^[yY]$ ]]
}

# ui_choose_one <default-index> <label>...
#
# Prints the chosen label ON STDOUT, and nothing else on stdout -- the menu,
# the prompt and any complaint go to stderr, because the caller reads the
# answer through a command substitution and would otherwise get the menu back
# as well. (`read -p` already writes its prompt to stderr; the list has to be
# told to.)
#
# A bare Enter, or no terminal, takes the default -- never a loop that cannot
# end, which is what the compositor question used to be.
ui_choose_one() {
  local default="$1"; shift
  local options=("$@") reply i

  for i in "${!options[@]}"; do
    if (( i + 1 == default )); then
      printf '   %d) %s%s  (default)%s\n' "$(( i + 1 ))" "${options[i]}" "$C_DIM" "$C_RESET" >&2
    else
      printf '   %d) %s\n' "$(( i + 1 ))" "${options[i]}" >&2
    fi
  done

  if ! ui_has_tty; then
    ui_no_tty_notice >&2
    printf '%s\n' "${options[$(( default - 1 ))]}"
    return 0
  fi

  # Three tries and then the default, rather than the old unbounded loop. A
  # person who has typed the wrong thing three times is not going to type the
  # right thing on the fourth, and a script that can never finish is worse than
  # one that takes the documented default and says so.
  for (( i = 0; i < 3; i++ )); do
    read -rp "$(printf '%s==> Choose one [%d]: %s' "$C_YELLOW" "$default" "$C_RESET")" reply
    reply="${reply:-$default}"
    if [[ $reply =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= ${#options[@]} )); then
      printf '%s\n' "${options[$(( reply - 1 ))]}"
      return 0
    fi
    ui_bad "   Not one of 1..${#options[@]}." >&2
  done

  ui_warn "   Taking the default." >&2
  printf '%s\n' "${options[$(( default - 1 ))]}"
}
