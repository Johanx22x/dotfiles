# shellcheck shell=bash
# THE ONE QUESTION A TRACKED CONFIG CANNOT ANSWER FOR ITSELF.
#
# These dotfiles are shared between a desktop and a laptop, and the two pieces
# of hardware that differ most are a battery and a backlight. Detection alone is
# not enough to decide: a desktop with a UPS reports a battery, and a laptop
# whose driver has not loaded yet reports none, so the machine would grow and
# lose widgets for reasons nobody asked for.
#
# Asked rather than defaulted, and OFF unless answered. The widgets also hide
# themselves when the hardware is genuinely absent, so a wrong answer costs
# nothing -- it is the intention that is being recorded, not a guess.

laptop_meta() {
  echo "Laptop widgets"
  echo "a battery indicator on the bar and a brightness slider in the island"
}

# `laptop-modules` is run out of the repository rather than out of $HOME, so
# this works before anything is linked.
laptop_requires() { :; }
laptop_available() { :; }

LAPTOP_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/laptop-modules"

laptop_check() {
  # THE ANSWER IS THE POINT, NOT WHICH ANSWER IT IS. A machine that has said
  # "no" is as configured as one that has said "yes"; what this catches is the
  # machine that has never been asked, whose widgets are then off by accident
  # rather than on purpose.
  if [[ -f $LAPTOP_STATE ]]; then
    echo ok
  else
    echo "missing:nobody has said whether this is a laptop"
  fi
}

laptop_apply() {
  local modules="$DOT/bin/.local/bin/laptop-modules" answer

  if [[ ! -x $modules ]]; then
    ui_bad "   $modules is missing"
    # NOT FATAL. What this unit decides is whether two widgets -- battery and
    # backlight -- are drawn in the bar. Every other unit is indifferent to the
    # answer, and a desktop with a battery widget it cannot use is a cosmetic
    # complaint rather than a broken machine.
    fail_note "laptop" "laptop-modules is not in the repo at $modules" \
      "Check the checkout is complete (git status), then: ./install.sh apply laptop"
    return 0
  fi

  # TESTED, BECAUSE `set -e` IS SUSPENDED INSIDE AN _apply. Unguarded, a
  # laptop-modules that failed still reached the "on" line below and the state
  # file it writes -- the one thing _check looks at -- was never written, so the
  # unit reported success now and "nobody has said whether this is a laptop"
  # forever after.
  ui_say "   Off by default; they are only useful on a machine that has both."
  if ui_confirm "Is this a laptop?"; then
    answer=on
  else
    answer=off
  fi

  if run "$modules" "$answer" >/dev/null; then
    if [[ $answer == on ]]; then
      ui_did "   on -- they appear once the shell restarts"
    else
      ui_say "   off"
    fi
  else
    ui_bad "   laptop-modules $answer did not finish"
    fail_note "laptop" "laptop-modules could not record '$answer', so the widgets follow no decision" \
      "$modules $answer   -- then: ./install.sh check"
  fi
}

unit_register laptop
