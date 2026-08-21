# shellcheck shell=bash
# Everything in packages/required/, plus the list belonging to whichever
# compositor this machine answered.
#
# THE COMPOSITOR'S OWN PACKAGES LIVE IN THEIR OWN LISTS, and only the chosen one
# is installed. The shared lists used to carry hyprland, hyprsunset, uwsm and
# xdg-desktop-portal-hyprland, so a machine that answered "niri" pulled in a
# whole second compositor to leave it sitting there unused.
#
# The two portal backends, on the other hand, coexist happily and BOTH are
# installed under "both" -- checked rather than assumed: each compositor ships
# its own /usr/share/xdg-desktop-portal/<name>-portals.conf and
# xdg-desktop-portal picks the file by XDG_CURRENT_DESKTOP, so ScreenCast goes
# to hyprland in one session and to gnome in the other with nothing to switch
# by hand.

packages_meta() {
  echo "Packages"
  echo "packages/required/*.txt and the chosen compositor's own list"
}

packages_requires() { :; }
packages_available() { :; }

# The lists in play, one path per line. Written as ifs rather than
# `want_niri && printf`, because the last command of a function is its exit
# status and a machine on Hyprland alone would have this return 1.
packages_lists() {
  printf '%s\n' "$DOT"/packages/required/*.txt
  if want_hyprland; then printf '%s\n' "$DOT/packages/compositor/hyprland.txt"; fi
  if want_niri;     then printf '%s\n' "$DOT/packages/compositor/niri.txt"; fi
}

packages_names() {
  local lists=()
  mapfile -t lists < <(packages_lists)
  pkg_names_in "${lists[@]}"
}

packages_check() {
  local names=() missing=()
  mapfile -t names < <(packages_names)
  (( ${#names[@]} )) || { echo "na:no lists under packages/required"; return 0; }

  mapfile -t missing < <(pkg_missing "${names[@]}")
  if (( ${#missing[@]} )); then
    echo "missing:${#missing[@]} of ${#names[@]} packages"
  else
    echo ok
  fi
}

packages_apply() {
  local names=() lists=() list

  mapfile -t lists < <(packages_lists)
  for list in "${lists[@]}"; do
    ui_say "   $(pkg_read_list "$list" | wc -l) in ${list#"$DOT"/}"
  done

  # STOP, AND THE ARGUMENT FOR IT IS A DIRECTORY NAME. What separates
  # packages/required/ from packages/optional/ is written down in
  # 15-optional.sh as "one question -- does the desktop still work without it",
  # and the answer for everything installed here is no. A name in required/
  # that the desktop DOES work without is a name in the wrong directory, and
  # the fix for that is to move the file, not to teach the installer to shrug.
  # That is the trade the classification is making: one flaky build in
  # required/ now ends the run, and the pressure that puts is on the list
  # rather than on the person re-reading a summary.
  #
  # The compositor's own list comes through here too, which settles it on its
  # own: there is no useful sense in which this repository has been installed
  # on a machine that has no compositor.
  mapfile -t names < <(packages_names)
  pkg_install stop packages "required" "${names[@]}"
}

unit_register packages
