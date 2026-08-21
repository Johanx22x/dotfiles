# shellcheck shell=bash
# Neovim's configuration, which is a separate repository.
#
# Cloned rather than stowed because it is not part of this one: it has its own
# history, its own plugin lockfile and its own release cadence, and vendoring it
# here would mean every plugin update showing up as a change to the dotfiles.

nvim_meta() {
  echo "Neovim config"
  echo "clones Johanx22x/nvim into ~/.config/nvim"
}

# git comes from packages/required/base.txt, and the clone is the only thing
# this unit does.
nvim_requires() { echo packages; }
nvim_available() { :; }

nvim_check() {
  # ANY ~/.config/nvim COUNTS AS DONE, and that is on purpose rather than lax.
  # This unit's whole job is "there is a Neovim config here"; whether it is the
  # right remote, on the right branch or dirty is that repository's business,
  # and a doctor that reported drift because somebody was mid-rebase in there
  # would be reporting on something it does not own.
  if [[ -e "$HOME/.config/nvim" ]]; then
    echo ok
  else
    echo "missing:1 clone"
  fi
}

nvim_apply() {
  if [[ -e "$HOME/.config/nvim" ]]; then
    ui_say "   ~/.config/nvim already exists, leaving it alone"
    return 0
  fi

  # Not fatal: no network, or no git if the packages step was skipped.
  # Everything after this is worth running anyway.
  if run git clone https://github.com/Johanx22x/nvim.git "$HOME/.config/nvim"; then
    ui_did "   cloned"
  else
    ui_bad "   the clone failed, ~/.config/nvim is not set up"
    # NOT FATAL, and the comment above already said why: this is one editor's
    # configuration. The desktop comes up, logs in and draws without it, and
    # the two things that break the clone -- no network, no git because the
    # packages step was skipped -- are both things the person can see.
    fail_note "nvim" "the clone of ~/.config/nvim failed" \
      "Check the network, then: ./install.sh apply nvim"
  fi
}

unit_register nvim
