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

  # A mode that has switched questions off takes the default and says which one
  # it took, so a log of an `update` run reads as a decision rather than as a
  # gap where a prompt should have been.
  if (( ${UI_ASK:-1} == 0 )); then
    printf '%s%s%s [%s] %s(not asking)%s\n' \
      "$C_DIM" "$question" "$C_RESET" "$default" "$C_DIM" "$C_RESET"
    [[ $default == y ]]
    return
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

# ---------------------------------------------------------------------------
# TICK BOXES.
#
# TWO IMPLEMENTATIONS OF ONE FUNCTION, and the plain one is the real one. `gum`
# is extra/gum, 13.21 MiB, and depends on nothing but glibc -- so it is a
# perfectly good thing to want and a terrible thing to need. The machine this
# installer is for is a fresh Arch install; if the menu that installs packages
# needs a package, there is nothing to be done about it from inside the menu.
#
# So the fallback is not a degraded mode. It is what gets tested, and it is what
# runs here, because gum is not installed on the machine this was written on.
ui_have_gum() { command -v gum >/dev/null; }

# Asked once and remembered, so a machine that has said no is not asked again
# every time the menu opens. Never asked without a terminal, and never during
# --dry-run: offering to install something is only useful where the answer can
# be acted on.
ui_offer_gum() {
  ui_have_gum && return 0
  ui_has_tty || return 0
  (( ${DRY_RUN:-0} )) && return 0
  [[ "$(state_get ui.gum ask)" == ask ]] || return 0

  ui_dim "   The menu below is plain bash. 'gum' draws a nicer one -- 13 MiB"
  ui_dim "   from extra, depending on nothing but glibc."
  if ui_confirm "   Install gum?" n; then
    if run_sudo pacman -S --needed --noconfirm gum; then
      state_set ui.gum yes
    else
      ui_bad "   gum could not be installed; carrying on with the plain menu."
      state_set ui.gum no
    fi
  else
    state_set ui.gum no
  fi
  state_save
}

# A comma-separated list back into one item per line. The separator is a comma
# because that is what `gum choose --selected` takes; nothing this menu shows
# contains one, and the labels are built in this file so it stays that way.
ui_csv_lines() {
  local csv="$1"
  [[ -z $csv ]] && return 0
  printf '%s\n' "${csv//,/$'\n'}"
}

# ui_multi_select <header> <preselected-csv> <label>...
#
# Prints the chosen labels on stdout, one per line, and everything else on
# stderr -- same rule as ui_choose_one, and for the same reason.
#
# NO TERMINAL MEANS THE PRESELECTION STANDS. That is the honest answer: the
# boxes come from the profile, or from the state of the machine on a first run,
# and a mode with nobody at the keyboard has nothing to add to them. It is also
# what makes the whole thing usable from a script.
ui_multi_select() {
  local header="$1" preselected="$2"; shift 2
  local labels=("$@")

  if ! ui_has_tty; then
    ui_no_tty_notice >&2
    ui_dim "   $header: keeping the boxes as they are" >&2
    ui_csv_lines "$preselected"
    return 0
  fi

  if ui_have_gum; then
    ui_multi_select_gum "$header" "$preselected" "${labels[@]}"
  else
    ui_multi_select_plain "$header" "$preselected" "${labels[@]}"
  fi
}

# NOT TESTED, AND SAID SO PLAINLY. gum is not installed on the machine this was
# written on, so this path has been written against `gum choose`'s documented
# flags and never run. They are: --no-limit for tick boxes rather than a single
# choice, --selected for the boxes that start ticked, --output-delimiter so the
# answer comes back one per line instead of joined by a comma that would have to
# be split again, and `--` so a label beginning with a dash could never be read
# as a flag.
#
# gum exits non-zero when the menu is cancelled with Escape or ^C, and that is
# treated as "leave the boxes alone" rather than as an error -- the same answer
# the plain menu gives to an empty line.
ui_multi_select_gum() {
  local header="$1" preselected="$2"; shift 2
  local out
  if out="$(gum choose --no-limit \
              --header "$header" \
              --selected "$preselected" \
              --output-delimiter=$'\n' \
              -- "$@")"; then
    printf '%s' "$out"
    [[ -n $out ]] && printf '\n'
    return 0
  fi
  ui_csv_lines "$preselected"
}

# ---------------------------------------------------------------------------
# THE PLAIN ONE. A numbered list with boxes, toggled by typing numbers.
#
# TYPING A NUMBER TOGGLES, IT DOES NOT SELECT. The difference matters on a first
# run: the boxes arrive already ticked -- everything that is not `ok` -- so the
# common answer is Enter, and the second most common is "all of it except that
# one". A menu where typing 4 meant "only 4" would make the common case the
# longest thing to type.
#
# Ranges and several numbers at once are accepted because a dozen entries is
# enough that "2 5 7-9" is worth having, and because it costs one loop.
ui_multi_select_plain() {
  local header="$1" preselected="$2"; shift 2
  local labels=("$@")
  local on=() i reply token lo hi

  # The starting boxes. Compared whole-line, so a label with spaces in it --
  # all of them have -- is matched as one thing rather than word by word.
  for i in "${!labels[@]}"; do
    on[i]=0
    while IFS= read -r token; do
      [[ $token == "${labels[i]}" ]] && on[i]=1
    done < <(ui_csv_lines "$preselected")
  done

  while true; do
    printf '\n%s%s%s\n' "$C_BLUE" "$header" "$C_RESET" >&2
    for i in "${!labels[@]}"; do
      if (( on[i] )); then
        printf '  %2d) %s[x]%s %s\n' "$(( i + 1 ))" "$C_GREEN" "$C_RESET" "${labels[i]}" >&2
      else
        printf '  %2d) [ ] %s%s%s\n' "$(( i + 1 ))" "$C_DIM" "${labels[i]}" "$C_RESET" >&2
      fi
    done
    printf '%s  numbers toggle (2 5 7-9), a = all, n = none, Enter = accept%s\n' \
      "$C_DIM" "$C_RESET" >&2

    # `|| reply=""` so that a stdin that ends mid-menu -- a pipe closing, a
    # terminal going away -- accepts what is on screen instead of spinning.
    read -rp "$(printf '%s==> %s' "$C_YELLOW" "$C_RESET")" reply || reply=""
    [[ -z $reply ]] && break

    case "$reply" in
      a|A) for i in "${!labels[@]}"; do on[i]=1; done; continue ;;
      n|N) for i in "${!labels[@]}"; do on[i]=0; done; continue ;;
    esac

    # Deliberately unquoted: this is the one place where splitting the answer on
    # whitespace is the point.
    # shellcheck disable=SC2206
    for token in $reply; do
      if [[ $token =~ ^([0-9]+)-([0-9]+)$ ]]; then
        lo="${BASH_REMATCH[1]}"; hi="${BASH_REMATCH[2]}"
      elif [[ $token =~ ^[0-9]+$ ]]; then
        lo="$token"; hi="$token"
      else
        ui_bad "  '$token' is not a number or a range." >&2
        continue
      fi
      for (( i = lo; i <= hi; i++ )); do
        if (( i >= 1 && i <= ${#labels[@]} )); then
          on[i-1]=$(( 1 - on[i-1] ))
        else
          ui_bad "  there is no $i." >&2
        fi
      done
    done
  done

  for i in "${!labels[@]}"; do
    (( on[i] )) && printf '%s\n' "${labels[i]}"
  done
  return 0
}
