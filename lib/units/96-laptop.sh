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
  local modules="$DOT/bin/.local/bin/laptop-modules"

  if [[ ! -x $modules ]]; then
    ui_bad "   $modules is missing"
    FAILED+=("laptop: laptop-modules is not in the repo")
    return 0
  fi

  ui_say "   Off by default; they are only useful on a machine that has both."
  if ui_confirm "Is this a laptop?"; then
    run "$modules" on >/dev/null
    ui_did "   on -- they appear once the shell restarts"
  else
    run "$modules" off >/dev/null
    ui_say "   off"
  fi
}

unit_register laptop
