# shellcheck shell=bash
# The cursor pack: 28 Bibata themes coloured from Material 3 roles, one per
# accent family. `cursor-match` picks the one closest to the wallpaper after
# every change; without them the pointer stays whatever the system ships.
#
# NOT VERSIONED IN THIS REPOSITORY, and not built here either. The pack is
# nearly a gigabyte of compiled bitmaps -- an XCursor file carries the pointer
# at all 19 sizes -- which is the same reason packages/xwayland-satellite/
# ignores its own build output. Building instead of downloading would mean
# librsvg, xcursorgen, fish and about half an hour for 28 themes.
#
# PINNED TO A TAG on purpose: `latest` would change the pointers on a machine
# that only re-ran the installer. Bump it here when there is a reason to.
CURSOR_PACK_VERSION="v1.3.0"
CURSOR_PACK_URL="https://github.com/SakibShahariar/material-bibata-cursor/releases/download/$CURSOR_PACK_VERSION/bibata-material-dark-$CURSOR_PACK_VERSION.tar.gz"

# AND CHECKSUMMED, which it was not. This is 83 MB fetched over the network and
# handed straight to `tar x` into $HOME -- the one thing this installer does
# that trusts a third party with write access to a home directory, and it was
# doing it on the strength of the URL alone. A tag can be moved, a release
# asset can be replaced, and neither shows up as an error.
#
# The digest below is the sha256 of the asset as GitHub itself reports it
# through the releases API, confirmed by downloading the file and running
# sha256sum over it. Bump it in the same commit as the version above; a pack
# that does not match is deleted rather than unpacked.
CURSOR_PACK_SHA256="f0cfda388cbe6fcd7d9507a6c8a21a01f60a8c28260c83b85b32f20771bbe76b"

cursors_meta() {
  echo "Cursor themes"
  echo "28 Bibata themes so the pointer can follow the wallpaper"
}

# Nothing needs to be installed for a download and a tar, so this one is
# deliberately free of requirements -- it is the step that can be run on its own
# on a machine that already has everything else.
cursors_requires() { :; }
cursors_available() { :; }

cursors_check() {
  # The dark half only. matugen runs with --mode dark on this desktop, so the
  # -Light counterparts would never come out of the matcher -- they would only
  # double both the disk and the length of the picker in the settings window.
  if compgen -G "$HOME/.icons/Bibata-Material-*" >/dev/null; then
    echo ok
  else
    echo "missing:the cursor pack"
  fi
}

cursors_apply() {
  local fetch tmp sum

  if compgen -G "$HOME/.icons/Bibata-Material-*" >/dev/null; then
    ui_say "   already installed in ~/.icons, leaving it alone"
    return 0
  fi

  ui_say "   83 MB to download, 845 MB once unpacked into ~/.icons."

  # curl OR wget, whichever the machine has. Neither is guaranteed: curl comes
  # in as a dependency of half of Arch but is in no list here, and wget is in
  # packages/optional/hardware.txt, which is a group that can be skipped whole.
  fetch=""
  command -v curl >/dev/null && fetch="curl -fL --progress-bar -o"
  [[ -z $fetch ]] && command -v wget >/dev/null && fetch="wget -q --show-progress -O"

  if [[ -z $fetch ]]; then
    ui_bad "   neither curl nor wget is installed, skipping"
    FAILED+=("cursors: nothing to download with")
    return 0
  fi

  if (( ${DRY_RUN:-0} )); then
    ui_dim "   would download $CURSOR_PACK_URL and unpack it into ~/.icons"
    return 0
  fi

  # Same shape as the Neovim clone: fallible, wrapped, and never allowed to
  # take `set -e` and the rest of the run with it.
  tmp="$(mktemp -d)"
  if ! $fetch "$tmp/pack.tar.gz" "$CURSOR_PACK_URL"; then
    ui_bad "   the download failed, the cursor themes are not installed"
    FAILED+=("cursors: the download failed")
    rm -rf "$tmp"
    return 0
  fi

  # BEFORE UNPACKING AND NOT AFTER. A tar that has already been extracted into
  # ~/.icons cannot be un-extracted, so the only moment this check is worth
  # anything is this one.
  sum="$(sha256sum "$tmp/pack.tar.gz" | cut -d' ' -f1)"
  if [[ $sum != "$CURSOR_PACK_SHA256" ]]; then
    ui_bad "   the download does not match the checksum pinned in this file:"
    ui_say "     expected $CURSOR_PACK_SHA256"
    ui_say "     got      $sum"
    ui_say "   Nothing was unpacked. Either the release was replaced -- in which"
    ui_say "   case bump the version and the sum together -- or something is"
    ui_say "   between you and GitHub."
    FAILED+=("cursors: the download did not match its checksum")
    rm -rf "$tmp"
    return 0
  fi

  mkdir -p "$HOME/.icons"
  # --strip-components=1 drops the versioned top directory, so the themes land
  # as ~/.icons/Bibata-Material-<name> and the name in the settings window does
  # not carry a release number that means nothing to it.
  if tar xzf "$tmp/pack.tar.gz" -C "$HOME/.icons" \
       --strip-components=1 --exclude='INSTALL.txt'; then
    ui_ok "   installed"
  else
    ui_bad "   the archive could not be unpacked, ~/.icons may be half-written"
    FAILED+=("cursors: the archive could not be unpacked")
  fi
  rm -rf "$tmp"
}

unit_register cursors
