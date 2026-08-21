# shellcheck shell=bash
# The user units: the two timers this repository ships, and the two daemons
# that belong to the session.
#
# The *.target.wants links are deliberately not versioned -- they point at
# absolute paths in the original home and would dangle for anybody else -- so
# enabling them is a step rather than a file.

services-user_meta() {
  echo "User services"
  echo "the wallpaper and battery timers, the polkit agent, the blue light filter"
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
# ONLY UNDER HYPRLAND FOR hyprsunset, and not because it would fail loudly
# otherwise: it would come up perfectly and do nothing at all. hyprsunset
# changes the colour temperature through hyprland-ctm-control-v1, and under
# niri that protocol simply is not there, so the daemon would sit running with
# no effect while `night-light` reports success. Enabling it in a niri session
# buys a unit that lies.
#
# AND NOTHING FOR NIRI, which is deliberate rather than missing.
# wl-gammarelay-rs ships no unit, and `night-light` starts it on demand as a
# transient systemd-run unit precisely so nothing binds it to
# graphical-session.target -- a unit that did would also come up under
# Hyprland, where it would fight hyprsunset for gamma control of the same
# outputs.
services-user_units() {
  printf '%s\n' wallpaper-rotate.timer airpods-battery.timer
  # A plain D-Bus agent, which belongs to neither flavor and works the same
  # under both.
  printf '%s\n' hyprpolkitagent.service
  if want_hyprland; then printf '%s\n' hyprsunset.service; fi
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

  if want_niri; then
    ui_dim "   niri: the blue light filter is wl-gammarelay-rs, started on demand"
  fi
}

unit_register services-user
