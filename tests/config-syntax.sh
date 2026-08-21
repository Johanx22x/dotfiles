#!/usr/bin/env bash
# Ask each compositor whether its own configuration is valid.
#
# This is the cheap check that pays for the whole workflow. A syntax error in
# hypr/.config/hypr/gaming.lua does not announce itself in a diff: it announces
# itself at the next login, on a machine with no shell and no keybinds, which is
# the worst possible moment to find out.
#
# THREE PASSES, AND THE FIRST TWO ARE NOT REDUNDANT.
#
#   luac -p                  every .lua under hypr/, including the ones nothing
#                            requires yet. Pure syntax, no Hyprland needed.
#   Hyprland --verify-config the entry point, run for real: it evaluates the
#                            Lua and then validates what came out, so it also
#                            catches `general.gaps_inn` -- a name luac is
#                            perfectly happy with and Hyprland is not.
#   niri validate            the KDL config, the same parser niri loads with.
#
# TWO THINGS THE HYPRLAND PASS REFUSES TO START WITHOUT, both of them about the
# environment rather than about the config, and both found by running it in one
# that had neither:
#
#   XDG_RUNTIME_DIR. Without it Hyprland throws before it ever looks at the
#   config -- "Critical error thrown: XDG_RUNTIME_DIR is not set!",
#   std::terminate, exit 134 -- and a container has no session to set one. It
#   never uses the directory in this mode; it only insists that it exists.
#
#   --i-am-really-stupid, because a job in a container runs as root and
#   Hyprland refuses to start as root without it: "Hyprland was launched with
#   superuser privileges, but the privileges check is not omitted." The flag is
#   named for the case it was written for, which is a real compositor session
#   owned by root. This is not that: --verify-config reads a file, evaluates it
#   and prints a verdict, and the alternative is creating a user in the
#   container to run one parse as.
#
# With those two, --verify-config runs to a verdict with no seat, no DRM device
# and no Wayland display.
#
# Both compositors also read optional per-machine files out of $HOME
# (tweaks.lua, monitors.lua, local.kdl...). HOME points at an empty directory
# here so the answer is about the repo and not about the machine.
#
# Run it from anywhere:  tests/config-syntax.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYPR_CONFIG="$REPO/hypr/.config/hypr/hyprland.lua"
NIRI_CONFIG="$REPO/niri/.config/niri/config.kdl"

failed=0
note() { echo "config-syntax: $*"; }
fail() { echo "config-syntax: FAIL $*" >&2; failed=1; }

sandbox="$(mktemp -d)"
export HOME="$sandbox/home" XDG_RUNTIME_DIR="$sandbox/run"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
trap 'rm -rf "$sandbox"' EXIT

# --- Lua syntax -------------------------------------------------------------
lua_files=()
while IFS= read -r -d '' file; do lua_files+=("$file"); done \
    < <(find "$REPO/hypr" -name '*.lua' -print0 | sort -z)

if [[ ${#lua_files[@]} -eq 0 ]]; then
    fail "found no .lua under hypr/ -- has the layout changed?"
else
    note "luac -p on ${#lua_files[@]} file(s) under hypr/"
    for file in "${lua_files[@]}"; do
        luac -p "$file" || fail "${file#"$REPO"/}"
    done
fi

# --- Hyprland ---------------------------------------------------------------
if [[ -f $HYPR_CONFIG ]]; then
    note "Hyprland --verify-config"
    # Its own output is a wall of DEBUG lines with the verdict at the bottom;
    # only the tail is worth showing, and only when it is bad news.
    if ! output="$(Hyprland --verify-config --i-am-really-stupid \
                            --config "$HYPR_CONFIG" 2>&1)"; then
        fail "Hyprland rejected ${HYPR_CONFIG#"$REPO"/}"
        tail -n 5 <<<"$output" >&2
    fi
else
    fail "$HYPR_CONFIG is missing"
fi

# --- niri -------------------------------------------------------------------
if [[ -f $NIRI_CONFIG ]]; then
    note "niri validate"
    # niri writes its "config is valid" on stderr along with a WARN for each
    # optional include that is absent, which in a sandboxed HOME is all of
    # them. The exit status is the verdict; the text only matters when it fails.
    if ! output="$(niri validate --config "$NIRI_CONFIG" 2>&1)"; then
        fail "niri rejected ${NIRI_CONFIG#"$REPO"/}"
        echo "$output" >&2
    fi
else
    fail "$NIRI_CONFIG is missing"
fi

if [[ $failed -eq 0 ]]; then
    note "both compositors accept their configuration"
fi
exit "$failed"
