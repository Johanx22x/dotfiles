# shellcheck shell=bash
# The one package this repository builds itself.
#
# packages/xwayland-satellite/ is the Arch PKGBUILD for 0.8.2 plus the one-line
# fix from upstream PR #480, because without it DaVinci Resolve cannot be opened
# at all under niri: 0.8.2 misclassifies its project manager window as an
# xdg_popup and parents it to a hidden 1x1 window, so the splash appears, the
# splash closes, and nothing is left on screen.
#
# ITS pkgrel IS 1.1 AND THAT IS THE WHOLE MECHANISM. 1.1 beats the repositories'
# 0.8.2-1, so pacman installs this one; and it LOSES to any future 0.8.2-2 or
# 0.8.3, so a released fix replaces it on its own with no pin to remember and
# nothing in IgnorePkg to clean up. This unit's job is to notice both ends of
# that: whether the patched build is in place, and whether the repositories have
# overtaken it and the directory can be deleted.

aur_patched_pkgname="xwayland-satellite"
aur_patched_dir() { printf '%s\n' "$DOT/packages/xwayland-satellite"; }

aur-patched_meta() {
  echo "Patched AUR package"
  echo "builds packages/xwayland-satellite/ so Resolve opens under niri"
}

aur-patched_requires() { echo packages; }

aur-patched_available() {
  # xwayland-satellite is niri's X11 support and Hyprland has its own; on a
  # machine that answered hyprland there is nothing here to build.
  if ! want_niri; then
    echo "niri is not in play"
    return 1
  fi
  if [[ ! -f "$(aur_patched_dir)/PKGBUILD" ]]; then
    # THE EXPECTED END OF THIS UNIT'S LIFE. The PKGBUILD says to delete the
    # whole directory once the fix is in the repositories, so its absence is
    # success rather than breakage.
    echo "packages/xwayland-satellite/ is gone, which is how this ends"
    return 1
  fi
}

# The version this repository would build, read out of the PKGBUILD rather than
# written down twice. Bumping the PKGBUILD is then the only edit.
aur-patched_wanted_version() {
  local dir pkgver pkgrel
  dir="$(aur_patched_dir)"
  pkgver="$(sed -n 's/^pkgver=//p' "$dir/PKGBUILD" | head -n1)"
  pkgrel="$(sed -n 's/^pkgrel=//p' "$dir/PKGBUILD" | head -n1)"
  printf '%s-%s\n' "$pkgver" "$pkgrel"
}

aur-patched_check() {
  local have want cmp

  have="$(pacman -Q "$aur_patched_pkgname" 2>/dev/null | awk '{print $2}')"
  [[ -z $have ]] && { echo "missing:$aur_patched_pkgname is not installed"; return 0; }

  want="$(aur-patched_wanted_version)"

  # `vercmp` ships with pacman and implements pacman's own ordering, which is
  # not string order and not sort -V either: it is what actually decides whether
  # an upgrade happens, so it is the only honest comparison here.
  cmp="$(vercmp "$have" "$want")"

  if (( cmp == 0 )); then
    echo ok
  elif (( cmp > 0 )); then
    # The repositories have overtaken this build, which is what the PKGBUILD was
    # designed to let happen. Reported as drift rather than ok because there IS
    # something to do -- delete the directory -- and it is a change to the
    # repository rather than to the machine.
    echo "drift:$have is newer than $want -- packages/xwayland-satellite/ can go"
  else
    echo "missing:$have installed, $want is the patched build"
  fi
}

aur-patched_apply() {
  local dir have want
  dir="$(aur_patched_dir)"
  want="$(aur-patched_wanted_version)"
  have="$(pacman -Q "$aur_patched_pkgname" 2>/dev/null | awk '{print $2}')"

  if [[ -n $have ]] && (( "$(vercmp "$have" "$want")" > 0 )); then
    ui_ok  "   $have is installed and is newer than the patched $want."
    ui_say "   The fix is in the repositories. Delete packages/xwayland-satellite/;"
    ui_say "   the PKGBUILD says so at the top of itself."
    return 0
  fi

  ui_say "   Building $aur_patched_pkgname $want from packages/xwayland-satellite/."
  ui_say "   -s pulls clang and rust as build dependencies."

  # In a subshell so the working directory of the run is not moved underneath
  # every unit that comes after this one.
  if ( cd "$dir" && run makepkg -si --noconfirm ); then
    ui_did "   built and installed"
  else
    ui_bad "   the build failed, see the output above"
    FAILED+=("aur-patched: makepkg did not finish")
  fi
}

unit_register aur-patched
