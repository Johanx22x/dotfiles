#!/usr/bin/env bash
# What happens to the links stow made when the file behind one is deleted?
#
# THE FAILURE THIS EXISTS FOR, measured on the machine this repository comes
# from on 2026-08-21. Three files were deleted from quickshell/ that morning;
# after the pull, ~/.config/quickshell held three symlinks pointing at nothing,
# `./install.sh check` said `ok`, and `apply symlinks` had nothing to say about
# them either -- stow only ever looks at the files a package HAS. A dangling
# .qml in that tree is read by a shell that scans directories, so the shape of
# the bug is "an update breaks the desktop and the repair command says
# everything is fine".
#
# WHY IT GETS A CHECK OF ITS OWN, rather than a line in tests/installer-run.sh.
# What is being tested here is code whose whole job is deleting things in a home
# directory, and the interesting half of it is everything it must REFUSE to
# delete: a broken link that belongs to somebody else, a real file, a directory
# with somebody's file in it. Those cases have to be built deliberately, and
# they have to be built somewhere that is not anybody's $HOME.
#
# A SANDBOX REPOSITORY AND A SANDBOX HOME, both under one mktemp -d, thrown
# away at the end. install.sh is sourced -- as tests/installer-menus.sh does --
# for `run`, the ui and the unit itself, and then DOT, HOME and STOW_PACKAGES
# are pointed at the sandbox. Nothing here touches the real home, and the
# sourced `check` is read-only by contract.
#
# Run it from anywhere:  tests/stale-links.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v stow >/dev/null || {
    echo "stale-links: stow is not installed, so there is nothing to test" >&2
    exit 2
}

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# The mode is `check` because it is the read-only one; its output is of no
# interest here and its exit status is whatever this machine happens to be in.
# shellcheck source=/dev/null
HOME_REAL="$HOME"
source "$REPO/install.sh" check >/dev/null 2>&1 || true
HOME="$HOME_REAL"

FAILS=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1" >&2; FAILS=$(( FAILS + 1 )); }

# `-e` is false for a link that points at nothing, so both tests are needed to
# ask the only question these assertions care about: is anything there at all.
there()     { [[ -e $1 || -L $1 ]]; }
assert_there()     { there "$1" && pass "$2" || fail "$2 -- $1 is gone"; }
assert_gone()      { there "$1" && fail "$2 -- $1 is still there" || pass "$2"; }
assert_equal()     { [[ $1 == "$2" ]] && pass "$3" || fail "$3 -- got '$1', wanted '$2'"; }

# ---------------------------------------------------------------------------
# The sandbox: one package with a file at its root, a directory of files and a
# subdirectory, stowed into an empty home exactly as install.sh does it.
DOT="$SANDBOX/repo"
HOME="$SANDBOX/home"
# Both are read by the unit that was sourced above and by nothing in this file,
# which is what shellcheck is objecting to.
# shellcheck disable=SC2034
STOW_PACKAGES=(pkg)
# shellcheck disable=SC2034
DRY_RUN=0

build() {
    rm -rf "${SANDBOX:?}/repo" "${SANDBOX:?}/home"
    mkdir -p "$DOT/pkg/.config/app/sub" "$HOME"
    echo z > "$DOT/pkg/.zshrc"
    echo a > "$DOT/pkg/.config/app/a.conf"
    echo b > "$DOT/pkg/.config/app/b.conf"
    echo c > "$DOT/pkg/.config/app/sub/c.conf"
    stow --no-folding -t "$HOME" -d "$DOT" pkg
}

# Everything that must survive, in the shapes it takes on a real machine.
plant_bystanders() {
    # A broken link that is broken BY DESIGN and points nowhere near this
    # repository: Discord writes exactly this, and so do Firefox and Zen with
    # their `lock`. This one sits INSIDE a directory the sweep does look at,
    # which is the only interesting place to put it.
    ln -s 'hostname-4242' "$HOME/.config/app/SingletonLock"
    # The real thing as well, where Discord actually keeps it.
    mkdir -p "$HOME/.config/discord"
    ln -s 'hostname-4242' "$HOME/.config/discord/SingletonLock"
    echo real > "$HOME/.config/discord/settings.json"
    # A regular file of somebody's own, in with the links.
    echo mine > "$HOME/.config/app/mine.conf"
    # A directory somebody else owns, holding a file of theirs and a broken
    # link into this repository. The link is left alone because the directory
    # is not one stow writes into.
    mkdir -p "$HOME/.config/app/theirs"
    echo theirs > "$HOME/.config/app/theirs/notes.txt"
    ln -s "$DOT/pkg/.config/app/vanished.conf" "$HOME/.config/app/theirs/vanished.conf"
    # An empty directory nobody has any business removing.
    mkdir -p "$HOME/.config/app/empty-of-mine"
}

# ---------------------------------------------------------------------------
echo "stale-links: a file deleted from the repository leaves a link behind"
build
plant_bystanders
rm "$DOT/pkg/.config/app/b.conf"
rm -r "$DOT/pkg/.config/app/sub"
rm "$DOT/pkg/.zshrc"

assert_equal "$(symlinks_check)" "drift:3 left by deleted files" \
    "check sees all three and calls them drift"

assert_equal "$(symlinks_stale | LC_ALL=C sort | sed "s#^$HOME/##" | tr '\n' ' ')" \
    ".config/app/b.conf .config/app/sub/c.conf .zshrc " \
    "and names exactly those three"

echo
echo "stale-links: --dry-run removes nothing"
DRY_RUN=1 symlinks_sweep_stale >/dev/null 2>&1
assert_there "$HOME/.config/app/b.conf" "the link is still there after a dry run"

echo
echo "stale-links: apply removes them, and only them"
symlinks_sweep_stale >/dev/null
assert_gone  "$HOME/.config/app/b.conf"           "the link of a deleted file goes"
assert_gone  "$HOME/.config/app/sub/c.conf"       "so does one in a deleted directory"
assert_gone  "$HOME/.zshrc"                       "and one at the root of the home"
assert_gone  "$HOME/.config/app/sub"              "the directory it emptied goes too"
assert_there "$HOME/.config/app/a.conf"           "the link of a file that is still there stays"
assert_equal "$(cat "$HOME/.config/app/a.conf")" "a" "and still reads the repository's file"
assert_there "$HOME/.config/app/SingletonLock"    "a broken link that points outside the repo stays"
assert_there "$HOME/.config/discord/SingletonLock" "Discord's own broken link stays"
assert_there "$HOME/.config/app/theirs/vanished.conf" \
    "a broken link in a directory holding somebody's file stays"
assert_there "$HOME/.config/app/empty-of-mine"    "an empty directory nobody made goes untouched"
assert_equal "$(cat "$HOME/.config/app/mine.conf")" "mine" "a real file is not touched"
assert_equal "$(symlinks_check)" "ok"             "and check goes quiet afterwards"

echo
echo "stale-links: a real file where a link used to be is never deleted"
build
rm "$DOT/pkg/.config/app/b.conf"
rm "$HOME/.config/app/b.conf"
echo "written by hand" > "$HOME/.config/app/b.conf"
assert_equal "$(symlinks_stale | wc -l)" "0" "a regular file is not a stale link"
symlinks_sweep_stale >/dev/null
assert_equal "$(cat "$HOME/.config/app/b.conf")" "written by hand" "and it still says what it said"

echo
echo "stale-links: a link broken by a bad path is reported, not deleted"
build
# The file is right there in the package; the link aims at the wrong place
# inside the repository. That is not a deletion and removing it would hide it.
ln -sfn "../../../repo/pkg/a.conf" "$HOME/.config/app/a.conf"
assert_equal "$(symlinks_stale | wc -l)" "0" "it is not counted as left by a deleted file"
assert_equal "$(symlinks_check)" "drift:1 in the way" "check reports it as in the way"
symlinks_sweep_stale >/dev/null
assert_there "$HOME/.config/app/a.conf" "and the sweep leaves it for stow to deal with"

echo
echo "stale-links: a link into a DIFFERENT clone of this repository is not ours"
build
other="$SANDBOX/other-clone"
mkdir -p "$other/pkg/.config/app"
ln -sfn "$other/pkg/.config/app/gone.conf" "$HOME/.config/app/gone.conf"
assert_equal "$(symlinks_stale | wc -l)" "0" "a broken link into another checkout is left alone"
symlinks_sweep_stale >/dev/null
assert_there "$HOME/.config/app/gone.conf" "and it is still there afterwards"

echo
echo "stale-links: the repository living inside the home is never walked"
# Which is the layout on the machine this is for: ~/dotfiles, with ~/.config
# full of links into it. A directory of nothing but links inside a package
# would look exactly like leftovers from the outside, so the walk is told to
# stop at the repository rather than left to work it out.
rm -rf "${SANDBOX:?}/home" "${SANDBOX:?}/repo"
HOME="$SANDBOX/home"
DOT="$HOME/dotfiles"
mkdir -p "$DOT/pkg/.config/app" "$DOT/pkg/links"
echo a > "$DOT/pkg/.config/app/a.conf"
echo b > "$DOT/pkg/.config/app/b.conf"
ln -s "../.config/app/a.conf" "$DOT/pkg/links/a.conf"
ln -s "../.config/app/deleted.conf" "$DOT/pkg/links/deleted.conf"
stow --no-folding -t "$HOME" -d "$DOT" pkg
rm "$DOT/pkg/.config/app/b.conf"
assert_equal "$(symlinks_stale | sed "s#^$HOME/##" | tr '\n' ' ')" ".config/app/b.conf " \
    "the leftover in the home is found and nothing in the repository is"
symlinks_sweep_stale >/dev/null
assert_there "$DOT/pkg/links/deleted.conf" "the dangling link inside the repository is left alone"
assert_there "$DOT/pkg/links/a.conf"       "and so is the one beside it"
DOT="$SANDBOX/repo"

echo
if (( FAILS )); then
    echo "stale-links: $FAILS assertion(s) failed" >&2
    exit 1
fi
echo "stale-links: the sweep removes what it should and nothing else"
