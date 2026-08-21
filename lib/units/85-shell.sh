# shellcheck shell=bash
# zsh as the login shell.
#
# THE LAST LINE OF THE OLD SCRIPT'S "left to do by hand" LIST, and the one with
# the least reason to be there. Everything else on that list needs a decision or
# hardware nothing can see; this one is `chsh -s /usr/bin/zsh`, and leaving it
# undone means the zsh package is linked into $HOME and a terminal still opens
# bash -- with the prompt, the aliases and the completions all present and none
# of them loaded.

shell_meta() {
  echo "Login shell"
  echo "zsh, so the config the zsh package links is the one that runs"
}

shell_requires() { echo packages; echo symlinks; }

# chsh will only accept a shell that is listed in /etc/shells, and zsh adds
# itself there when it is installed -- so this is the same test as "is zsh
# installed", asked in the form the thing that does the work will ask it.
shell_available() {
  if ! grep -qx '/usr/bin/zsh' /etc/shells 2>/dev/null; then
    echo "zsh is not in /etc/shells"
    return 1
  fi
}

# `getent passwd` and not $SHELL. $SHELL is what the CURRENT session was started
# with, which is whatever the terminal emulator was told, whatever a `su`
# inherited, or whatever a test harness exported -- so on a machine where the
# login shell has never been changed but the terminal is configured to run zsh,
# $SHELL says zsh and the answer is wrong. The passwd entry is the thing chsh
# writes and the thing login reads.
shell_check() {
  local current
  current="$(getent passwd "$USER" | cut -d: -f7)"

  if [[ $current == /usr/bin/zsh ]]; then
    echo ok
  else
    echo "missing:the login shell is ${current:-unknown}"
  fi
}

shell_apply() {
  # ASKS FOR YOUR PASSWORD, NOT FOR ROOT'S, and it will not take the cached sudo
  # ticket either -- chsh authenticates the user through PAM on its own. Said
  # out loud because an unexplained password prompt in the middle of a long run
  # is the kind of thing people type their root password into.
  ui_say "   chsh asks for YOUR password. It does not go through sudo."

  if run chsh -s /usr/bin/zsh; then
    ui_did "   the login shell is zsh -- from the next login, not this session"
  else
    ui_bad "   chsh did not finish; the login shell is unchanged"
    FAILED+=("shell: chsh did not finish")
  fi
}

unit_register shell
