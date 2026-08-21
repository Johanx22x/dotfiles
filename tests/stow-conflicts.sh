#!/usr/bin/env bash
# Would `stow` link the whole repo into an empty home without complaining?
#
# THE FAILURE THIS EXISTS FOR is two stow packages claiming the same path --
# say gtk/ and gaming/ both shipping .config/something/settings.ini. install.sh
# cannot see that one coming: it reports whatever stow says on the machine it is
# running on, where the usual answer is a pre-existing file the user already had,
# and a genuine collision between two packages of this repo looks exactly the
# same in that output. Here there is nothing else in the way, so anything stow
# says is about the repo.
#
# INTO A FRESH EMPTY DIRECTORY, NOT $HOME. Even a container's /root arrives with
# .bashrc and friends in it, and this check is not about those -- it is about
# whether the packages agree with each other. An empty target is also what makes
# it runnable on a real machine without touching anything: -n keeps it a
# simulation, and the target is thrown away afterwards.
#
# WHICH PACKAGES. Every top-level directory that holds an entry beginning with a
# dot, which is exactly the shape of a stow package here: bin/.local,
# hypr/.config, zsh/.zshrc. It is not the list in install.sh, on purpose --
# install.sh links one compositor or the other, and the question here is whether
# ALL of them can coexist, including the two that are never installed together.
# assets/, packages/, seeds/, system/ and tests/ hold no dotfiles and drop out
# of the list on their own.
#
# --no-folding matches install.sh: real directories with a link per file, so an
# application writing a new file into ~/.config does not drop it inside the repo.
#
# Run it from anywhere:  tests/stow-conflicts.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

packages=()
for dir in "$REPO"/*/; do
    dir="${dir%/}"
    # A dotfile or dot-directory at the root of it makes it a stow package.
    compgen -G "$dir/.[!.]*" >/dev/null || continue
    packages+=("$(basename "$dir")")
done

if [[ ${#packages[@]} -eq 0 ]]; then
    echo "stow-conflicts: found no stow packages -- has the layout changed?" >&2
    exit 2
fi

target="$(mktemp -d)"
trap 'rm -rf "$target"' EXIT

echo "stow-conflicts: ${#packages[@]} package(s): ${packages[*]}"

# stow exits non-zero when it has something to complain about, so the exit
# status is captured rather than allowed to end the script -- the text is what
# says whether the complaint matters.
output="$(stow --no-folding -v -n -t "$target" -d "$REPO" "${packages[@]}" 2>&1)" || true

# What is left after the routine chatter is removed. LINK and MKDIR are -v
# narrating the plan, and the simulation-mode warning is printed on every -n
# run whether or not anything is wrong.
complaints="$(grep -vE '^(LINK|MKDIR|UNLINK|RMDIR): ' <<<"$output" \
            | grep -vE '^WARNING: in simulation mode' || true)"

if [[ -n ${complaints//[[:space:]]/} ]]; then
    echo
    echo "stow-conflicts: stow will not link this tree as it stands:" >&2
    sed 's/^/  /' <<<"$complaints" >&2
    exit 1
fi

echo "stow-conflicts: every package links cleanly into an empty home"
