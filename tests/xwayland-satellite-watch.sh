#!/usr/bin/env bash
# Has the repository build of xwayland-satellite caught up with the patched one?
#
# packages/xwayland-satellite/ is a local PKGBUILD carrying upstream PR #480,
# without which DaVinci Resolve cannot be opened at all under niri. Its header
# ends with "DELETE THIS WHOLE DIRECTORY once the fix is in the repos", and
# that is a thing nobody remembers to go and check -- the whole point of the
# patched package is that once it is installed, everything works and there is
# no reminder left.
#
# THE COMPARISON IS THE ONE THE PKGBUILD ALREADY DESCRIBES. It is versioned
# 0.8.2-1.1 on purpose: 1.1 beats the 0.8.2-1 in extra so pacman installs it,
# and loses to any future 0.8.2-2 or 0.8.3 so a released fix replaces it on its
# own. `vercmp` is pacman's own implementation of exactly that ordering, so
# asking it whether the repository version now wins is asking whether the
# directory has done its job and can go.
#
# It does NOT try to work out whether the fix is really in there. A rebuild
# could bump the version for something else entirely. What it says is "the
# thing this package was pinned against has moved, go and look", which is the
# honest signal and the one that was missing.
#
# Prints a human verdict, and writes overtaken/repo_version/patched_version
# into $GITHUB_OUTPUT when there is one, so the workflow can decide whether to
# open an issue.
#
# Run it from anywhere:  tests/xwayland-satellite-watch.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGBUILD="$REPO/packages/xwayland-satellite/PKGBUILD"

# The directory being gone is the success case, not an error: it means the fix
# landed and somebody already cleaned up. Nothing to watch, and no issue.
if [[ ! -f $PKGBUILD ]]; then
    echo "xwayland-satellite-watch: no local PKGBUILD -- nothing to watch"
    exit 0
fi

pkgver="$(sed -n 's/^pkgver=//p' "$PKGBUILD")"
pkgrel="$(sed -n 's/^pkgrel=//p' "$PKGBUILD")"
if [[ -z $pkgver || -z $pkgrel ]]; then
    echo "xwayland-satellite-watch: could not read pkgver/pkgrel from $PKGBUILD" >&2
    exit 2
fi
patched="$pkgver-$pkgrel"

repo_version="$(pacman -Si xwayland-satellite 2>/dev/null | awk '/^Version/ { print $3; exit }')"
if [[ -z $repo_version ]]; then
    # Dropped from the repositories entirely, or the database is not synced.
    # Either way this cannot answer the question and must not pretend to.
    echo "xwayland-satellite-watch: xwayland-satellite is not in the repositories" >&2
    exit 2
fi

echo "xwayland-satellite-watch: repositories have $repo_version, this repo builds $patched"

overtaken=false
[[ "$(vercmp "$repo_version" "$patched")" -gt 0 ]] && overtaken=true

if [[ $overtaken == true ]]; then
    echo "xwayland-satellite-watch: the repository build now wins -- pacman will replace" \
         "the local one by itself, so packages/xwayland-satellite/ can be deleted"
else
    echo "xwayland-satellite-watch: still pinned, nothing to do"
fi

if [[ -n ${GITHUB_OUTPUT:-} ]]; then
    {
        echo "overtaken=$overtaken"
        echo "repo_version=$repo_version"
        echo "patched_version=$patched"
    } >> "$GITHUB_OUTPUT"
fi
