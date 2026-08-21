# shellcheck shell=bash
# The system units: the display manager, the network, bluetooth, and the timers
# that keep the machine tidy.
#
# NONE OF THIS WAS ANYWHERE IN THE OLD SCRIPT. Installing snapper without
# enabling snapper-timeline.timer gets a machine with a snapshot tool and no
# snapshots; installing reflector and system/reflector.conf without
# reflector.timer gets a carefully written configuration that nothing ever
# reads. Both look exactly like a working install from the outside, which is why
# they belong in a check rather than in a paragraph at the end.
#
# EVERY UNIT IS GATED ON ITS PACKAGE. A machine that skipped snapper is not
# missing snapper's timers -- it has no opinion about them -- so the gate is
# "is the package installed", asked of the local database, and nothing here
# reports a unit that could not exist.

services-system_meta() {
  echo "System services"
  echo "the display manager, network, bluetooth, and the maintenance timers"
}

services-system_requires() { echo packages; }
services-system_available() { :; }

# One unit per line. The pairing is package -> unit, and the comment beside each
# says what stops working when it is off.
services-system_units() {
  # The display manager: without it a machine boots to a text console and the
  # sessions this repo installs are not reachable at all.
  pkg_is_installed sddm && echo sddm.service

  # The network, and the applet's D-Bus counterpart.
  pkg_is_installed networkmanager && echo NetworkManager.service

  # Bluetooth. system/bluetooth-main.conf's whole subject -- a PS5 pad that
  # comes back on its own -- needs this running to mean anything.
  pkg_is_installed bluez && echo bluetooth.service

  # TRIM on a schedule. btrfs on SSDs here, and the fstab entries carry
  # discard=async, so this is the weekly sweep rather than the mechanism.
  pkg_is_installed util-linux && echo fstrim.timer

  # The pacman cache, which is otherwise unbounded and lives on the root
  # subvolume -- so it goes into every snapshot as well.
  pkg_is_installed pacman-contrib && echo paccache.timer

  # The mirrorlist. system/reflector.conf is the configuration this reads; with
  # the timer off, a machine keeps whatever mirrors the ISO shipped with.
  pkg_is_installed reflector && echo reflector.timer

  # Snapshots on a schedule, and their cleanup. snap-pac covers the pre/post
  # pair around each pacman transaction and needs nothing enabled; these two are
  # the hourly timeline and the retention that keeps it from filling the disk.
  if pkg_is_installed snapper; then
    echo snapper-timeline.timer
    echo snapper-cleanup.timer
  fi

  # The daemon that writes a GRUB submenu of the snapshots. Without it the
  # snapshots exist and there is no way to boot one from the menu, which is the
  # entire point of taking them before a pacman transaction.
  pkg_is_installed grub-btrfs && echo grub-btrfsd.service
}

# READ-ONLY AND WITHOUT SUDO. `systemctl is-enabled` reads the unit files and
# the .wants links; it needs no privilege and changes nothing, which is what
# lets this run on every draw of the menu.
services-system_check() {
  local unit state missing=0 total=0 notfound=0

  while IFS= read -r unit; do
    [[ -z $unit ]] && continue
    total=$(( total + 1 ))
    state="$(systemctl is-enabled "$unit" 2>/dev/null || true)"
    case "$state" in
      enabled|enabled-runtime|static|indirect|generated) ;;
      "" | not-found) notfound=$(( notfound + 1 )); missing=$(( missing + 1 )) ;;
      *)              missing=$(( missing + 1 )) ;;
    esac
  done < <(services-system_units)

  (( total )) || { echo "na:none of the packages these belong to are installed"; return 0; }

  if (( notfound )); then
    # A unit file that is not there when its package IS installed means the
    # package changed its unit names, which is a different problem from a
    # switch left off and is worth saying differently.
    echo "drift:$notfound unit file(s) missing, $(( missing - notfound )) disabled, of $total"
  elif (( missing )); then
    echo "missing:$missing of $total system units not enabled"
  else
    echo ok
  fi
}

services-system_apply() {
  local unit failed=() pending=()

  while IFS= read -r unit; do
    [[ -z $unit ]] && continue
    [[ "$(systemctl is-enabled "$unit" 2>/dev/null || true)" == enabled ]] && continue
    pending+=("$unit")
  done < <(services-system_units)

  if (( ${#pending[@]} == 0 )); then
    ui_say "   every one of them is already enabled"
    return 0
  fi

  # ENABLED ONE AT A TIME rather than in a single systemctl call, so that one
  # unit a package renamed does not take the other eight with it -- `systemctl
  # enable a b c` fails the whole invocation on the first name it cannot find.
  #
  # EVERYTHING GETS --now EXCEPT sddm, AND THAT EXCEPTION IS THE IMPORTANT LINE
  # IN THIS FILE. `systemctl enable --now sddm` on a machine that is already
  # logged in starts a display manager on top of the session running this
  # script: the greeter takes the console, and everything open goes with it,
  # halfway through an install. Enabling it without --now is the whole of what
  # was wanted anyway -- the question is which target the machine boots into,
  # and that is answered at the next boot.
  for unit in "${pending[@]}"; do
    if [[ $unit == sddm.service ]]; then
      run sudo systemctl enable "$unit" && ui_did "   enabled $unit (from the next boot)" \
        || { ui_bad "   could not enable $unit"; failed+=("$unit"); }
    elif run sudo systemctl enable --now "$unit"; then
      ui_did "   enabled $unit"
    else
      ui_bad "   could not enable $unit"
      failed+=("$unit")
    fi
  done

  # ONE NAME IN THIS LIST IS FATAL AND THE OTHERS ARE NOT, which is why the
  # severity is decided here rather than for the unit as a whole. The list
  # above says it about sddm itself: "without it a machine boots to a text
  # console and the sessions this repo installs are not reachable at all".
  # That is the definition of a machine that has not been set up, and it is
  # worth stopping on because the person is still at the keyboard now and will
  # not be at the next boot, which is when they would find out.
  #
  # The rest are the network, bluetooth, TRIM, the pacman cache, the mirrors
  # and the snapshot timers. Every one of them is a thing that keeps working
  # without the machine failing to come up, and all of them can be enabled
  # afterwards with one command -- so they are named and the run carries on.
  if (( ${#failed[@]} )); then
    if [[ " ${failed[*]} " == *" sddm.service "* ]]; then
      fail_stop "services-system" \
        "sddm.service could not be enabled, so this machine would boot to a text console." \
        "systemctl status sddm.service  -- then 'sudo systemctl enable sddm.service' and run this again."
    fi
    fail_note "services-system" \
      "${#failed[@]} system unit(s) could not be enabled: ${failed[*]}" \
      "systemctl status ${failed[0]}   -- then: ./install.sh apply services-system"
  fi
  return 0
}

unit_register services-system
