#
# ~/.zshenv
#
# PATH, AND ONLY PATH. zsh reads this file for EVERY shell it starts --
# interactive or not, login or not -- which is the one property the rest of the
# session depends on. Everything else stays in .zshrc.
#
# WHY IT CANNOT LIVE IN .zshrc, WHICH IS WHERE IT USED TO BE. That file opens
# with `[[ $- != *i* ]] && return`, so a non-interactive shell never reaches its
# PATH block -- and a non-interactive LOGIN shell is exactly what starts the
# graphical session. niri-session re-execs itself through `exec -l "$SHELL" -c`
# before doing anything else, and then runs `systemctl --user import-environment`
# with no arguments, which copies that shell's whole environment into the user
# manager and OVERWRITES what environment.d had generated (see
# systemd/.config/environment.d/10-path.conf). niri.service, niri, and every
# child of it -- the shell included -- inherit the result.
#
# WHAT IT COSTS TO GET WRONG: the shell calls this repository's own scripts BY
# NAME -- `night-light`, `wallpaper-switch`, `desktop-tweak`, `compositor` --
# through QProcess, which searches PATH and reports nothing when the search
# fails. So the buttons do nothing, with no error anywhere. That is how the
# night light came to be silently dead under niri while `night-light on` worked
# perfectly from a terminal.

# typeset -U avoids duplicate entries when this is read more than once, which
# happens as a matter of course: a login shell inside a session that already
# exported PATH reads this file again.
typeset -U path PATH
path=("$HOME/.local/bin" $path)
export PATH
