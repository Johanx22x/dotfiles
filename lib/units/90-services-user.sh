# shellcheck shell=bash
# The user units: the two timers this repository ships, and the two daemons
# that belong to the session.
#
# The *.target.wants links are deliberately not versioned -- they point at
# absolute paths in the original home and would dangle for anybody else -- so
# enabling them is a step rather than a file.

services-user_meta() {
  echo "User services"
  echo "the wallpaper and battery timers, and the polkit agent"
}

# The unit files for the two timers come out of the systemd stow package, so
# there is nothing to enable until the links exist. This is also what makes the
# common failure legible: a timer that has never been linked reports as
# not-found rather than as disabled.
services-user_requires() { echo symlinks; }

# `systemctl --user` needs a running user manager, and there is not one inside
# a chroot, over a plain ssh session with no lingering enabled, or in a
# container. That is a real machine state and not an error: the links are what
# matter and they are already made, so this says "not here" and the run carries
# on.
services-user_available() {
  if ! systemctl --user show --property=Version >/dev/null 2>&1; then
    echo "no user systemd session"
    return 1
  fi
}

# Which units this machine should have enabled, one per line.
#
# hyprsunset.service IS NOT ONE OF THEM, ON ANY MACHINE, and that is the one
# decision in this file worth reading before changing.
#
# THERE IS ONE USER MANAGER AND THERE ARE TWO SESSIONS. `systemctl --user` is
# per user, not per session, so `enable` puts a link into
# graphical-session.target.wants once and it fires in WHICHEVER session comes up
# -- and this repository's whole point is that both can be installed at the same
# time. The unit's own guard cannot tell them apart either: it is
# `ConditionEnvironment=WAYLAND_DISPLAY`, which is set in both.
#
# What happens then was measured on this machine rather than reasoned about.
# hyprsunset drives the filter through hyprland-ctm-control-v1, which only
# Hyprland implements, so in a niri session it starts, prints "Compositor
# doesn't support hyprland-ctm-control-v1, are you running on Hyprland?", exits
# 1, and `Restart=on-failure` brings it back four more times until systemd gives
# up with start-limit-hit. The journal from 08:59 has all five. A unit sitting
# `failed` for three hours is exactly the sort of quiet wrongness `check` exists
# to find, so it must not be this script that creates it.
#
# AND ENABLING IT BUYS NOTHING, which is what makes the answer easy. `night-
# light` already calls `systemctl --user start hyprsunset.service` and polls for
# the daemon before it sends anything -- ensure_hyprsunset(), in bin/ -- so under
# Hyprland the filter comes up the first time it is used, and under niri the
# dispatch never reaches that branch at all because `compositor can gamma`
# answers no. Started on demand, exactly like wl-gammarelay-rs on the other
# side; the two flavors end up symmetric instead of one being a special case.
#
# THE OTHER WAY OUT WAS A DROP-IN adding
# `ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland`, which would let the unit
# stay enabled and skip itself cleanly in the wrong session. It is a real
# option -- the user manager does carry that variable, it reads `niri` here --
# but it cannot be verified from a niri session, it depends on uwsm exporting
# exactly the string `Hyprland`, and it would add a file to keep for a daemon
# that already starts itself. Not taken.
#
# NOTHING FOR NIRI EITHER, for the reason that has always been written down:
# wl-gammarelay-rs ships no unit, and `night-light` starts it as a transient
# systemd-run unit precisely so nothing binds it to graphical-session.target --
# a unit that did would also come up under Hyprland and fight hyprsunset for
# gamma control of the same outputs.
services-user_units() {
  printf '%s\n' wallpaper-rotate.timer airpods-battery.timer
  # A plain D-Bus agent, which belongs to neither flavor and works the same
  # under both.
  printf '%s\n' hyprpolkitagent.service
}

services-user_check() {
  local unit state missing=0 notfound=0 total=0

  while IFS= read -r unit; do
    total=$(( total + 1 ))
    # is-enabled exits non-zero for everything that is not enabled, so its exit
    # status is thrown away and the word it prints is what is read. It reads
    # the unit files and the .wants links and writes nothing -- which is what
    # lets this run on every draw of the menu.
    state="$(systemctl --user is-enabled "$unit" 2>/dev/null || true)"
    case "$state" in
      enabled|enabled-runtime|static|indirect) ;;
      "" | not-found) notfound=$(( notfound + 1 )); missing=$(( missing + 1 )) ;;
      *)              missing=$(( missing + 1 )) ;;
    esac
  done < <(services-user_units)

  if (( notfound )); then
    # WORTH SEPARATING FROM "disabled". A unit systemd cannot find is not a
    # switch left off; it is a file that is not there, which means either the
    # package that ships it is missing or the symlinks step has not been run
    # since it was added. Both are fixed somewhere else.
    echo "drift:$notfound unit file(s) missing, $(( missing - notfound )) disabled, of $total"
  elif (( missing )); then
    echo "missing:$missing of $total user units not enabled"
  else
    echo ok
  fi
}

services-user_apply() {
  local unit failures=0

  # A unit file that arrived through stow since the manager last looked is
  # invisible until this runs, which on a first install is every one of them.
  run systemctl --user daemon-reload || true

  while IFS= read -r unit; do
    if run systemctl --user enable --now "$unit"; then
      ui_did "   enabled $unit"
    else
      ui_bad "   could not enable $unit"
      failures=$(( failures + 1 ))
    fi
  done < <(services-user_units)

  if (( failures )); then
    # Best-effort on purpose. These units belong to packages and to the stow
    # step, and losing the rest of the run over a timer that can be enabled
    # later is a bad trade -- but it is written down where it will be read.
    FAILED+=("services-user: $failures unit(s) could not be enabled")
  fi

  # Said out loud because the absence is deliberate and looks like an omission.
  # See the note above services-user_units: neither filter is enabled, both are
  # started by `night-light` when they are first used, and enabling hyprsunset
  # on a machine that can boot into niri is how it ends up sitting `failed`.
  ui_dim "   The blue light filter is not enabled under either compositor:"
  ui_dim "   night-light starts hyprsunset or wl-gammarelay-rs on demand."
}

unit_register services-user
