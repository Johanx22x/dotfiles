#!/usr/bin/env bash
# Load the whole Quickshell tree in a headless compositor and ask whether it
# came up.
#
# WHY THIS EXISTS. Until it did, 40,592 lines of QML across 125 files -- half
# the repository and three quarters of its commits -- were read by nothing.
# Every other check here asks a real tool a real question about a real file;
# quickshell/ had no such check at all, and the whole tree could be emptied
# without turning a single one of them red. A missing import, a renamed
# singleton, a file deleted from under an `import "modules/bar"`: none of it is
# visible in a diff, and all of it lands at the next login on a desktop whose
# bar, launcher, notifications and power menu are the shell that just failed to
# start.
#
# WHAT IT CATCHES, which is exactly one class of fault and worth being precise
# about: everything that stops the tree LOADING, or that loads it into a state
# where names do not resolve.
#
# THERE ARE TWO ASSERTIONS AND THE SECOND IS NOT REDUNDANT, which was found by
# breaking four things on purpose and watching only two of them go red.
#
#   qs stays up and says "Configuration Loaded". A syntax error anywhere in the
#   singleton chain, or a type nothing declares, exits 255 before it ever gets
#   there -- appending `this is not qml {{{` to Config.qml prints eight lines of
#   "caused by" ending at "@Config.qml[1720:1]: Syntax error", and putting a
#   `NoSuchTypeAtAll {}` in shell.qml prints "NoSuchTypeAtAll is not a type".
#
#   The log carries no ReferenceError, TypeError, "Unable to assign" or
#   "is not a type". This is the half that catches the other two, because a
#   name that does not resolve in a QML binding is not a load failure at all --
#   the binding is evaluated lazily and the shell comes up looking fine.
#   Deleting Theme.qml outright, with every module in the tree reading it, still
#   printed "Configuration Loaded" and exited 0: the only trace was 200-odd
#   "ReferenceError: Theme is not defined". Dropping `pragma Singleton` from the
#   top of it did the same, leaving "TypeError: Property 'glass' of object Theme
#   is not a function" and a long tail of "Unable to assign [undefined] to
#   QColor". A check that only asked the first question would have passed both.
#
# A clean tree produces none of those four strings -- measured over repeated
# runs -- so the pattern is a floor and not a budget.
#
# WHAT IT DOES NOT CATCH, said here so nobody reads a green tick as more than
# it is. Both of the changes that reached the desktop broken in the day before
# this was written -- a rail that scrolled behind its own scrollbar, a
# dashboard that opened on the wrong screen -- were layout and visibility
# faults in a tree that loaded perfectly, with no exception and no log line.
# This check would have passed on both. It is a floor, not a ceiling:
# tests/scroll-rail.sh next door is what asks whether a component BEHAVES, and
# it has to be written per component.
#
# WHY A COMPOSITOR AND NOT `QT_QPA_PLATFORM=offscreen`. Offscreen runs QML and
# exits 0, so it looks like the cheap answer, but `PanelWindow` -- which is
# what the bar, the notifications, the launcher, the power menu, the carousel
# and the cheatsheet all are -- needs a Wayland backend and gets
# "No PanelWindow backend loaded" instead. Offscreen would parse the files and
# then skip the half of the tree that matters.
#
# WHY labwc AND NOT Hyprland, which is what this desktop actually runs.
# Hyprland cannot start without a seat: aquamarine 0.14 tries the Wayland
# backend, then DRM, then falls back to headless, and the fallback dies with
# "Cannot open backend: no allocator available" because every allocator it
# knows about wants a DRM node. In a container there is no DRM node and no
# seat, and on this desktop the seat is already taken by the running session:
# "Could not take control of session: Device or resource busy", then
# CBackend::create() failed, then SIGABRT. labwc is wlroots, and wlroots has a
# headless backend and a pixman renderer that want neither -- WLR_BACKENDS and
# WLR_RENDERER below are what select them. What is being tested is the QML, not
# the compositor, and layer-shell is layer-shell: Quickshell talks the same
# protocol to both.
#
# labwc logs two errors about Xwayland on the way up and carries on without it
# ("failed to create xwayland server, continuing without"). That is expected
# here and is not a failure: on this desktop /tmp/.X11-unix already belongs to
# the running session, and in a container there is nothing to serve.
#
# EVERYTHING RUNS IN A SANDBOX AND NOTHING TOUCHES THE REAL SESSION. HOME, the
# runtime directory and the whole XDG set point into mktemp, WAYLAND_DISPLAY
# and DISPLAY are unset so labwc does not nest itself inside a running
# compositor, and DBUS_SESSION_BUS_ADDRESS is unset so the notification server
# does not go looking for the bus name the real shell is holding. The shell
# writes its state and its logs; all of it lands in the sandbox and is deleted
# on the way out.
#
# The warnings it prints in here are about the sandbox, not about the code:
# there is no DBus, no PipeWire, no UPower, no ~/.face and no niri config, so
# the services that want them say so. They are not assertions. The assertions
# are that `qs` stayed alive and that it printed "Configuration Loaded".
#
# Run it from anywhere:  tests/shell-load.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO/quickshell/.config/quickshell"

# Long enough to be nothing to do with speed. The whole tree loads in about a
# second on this desktop and in a few on a cold runner; anything that has not
# said "Configuration Loaded" within this has not failed slowly, it has hung.
COMPOSITOR_TIMEOUT=20
LOAD_TIMEOUT=90
# What the paragraph on the second assertion below is waiting for.
SETTLE=3

failed=0
note() { echo "shell-load: $*"; }
fail() { echo "shell-load: FAIL $*" >&2; failed=1; }

for tool in labwc qs; do
    command -v "$tool" >/dev/null || {
        echo "shell-load: $tool is not installed" >&2
        exit 1
    }
done

[[ -f $SHELL_DIR/shell.qml ]] || {
    echo "shell-load: $SHELL_DIR/shell.qml is missing -- has the layout changed?" >&2
    exit 1
}

# A floor on the tree, for the same reason every other check here has one: an
# assertion over an empty set is not an assertion. If quickshell/ ever loses
# its files this should say so rather than load a shell.qml with nothing behind
# it and call that a pass.
qml_count="$(find "$SHELL_DIR" -name '*.qml' -type f | wc -l)"
if (( qml_count < 50 )); then
    echo "shell-load: found only $qml_count .qml under ${SHELL_DIR#"$REPO"/}" >&2
    echo "shell-load: that is far below the tree this is meant to load" >&2
    exit 1
fi

sandbox="$(mktemp -d)"
compositor_pid=""
shell_pid=""

cleanup() {
    # By recorded PID and never by name: there is a real shell running on this
    # desktop under the same binary, and `pkill qs` would take it down.
    [[ -n $shell_pid ]] && kill "$shell_pid" 2>/dev/null
    [[ -n $compositor_pid ]] && kill "$compositor_pid" 2>/dev/null
    wait 2>/dev/null
    rm -rf "$sandbox"
}
trap cleanup EXIT

export HOME="$sandbox/home"
export XDG_RUNTIME_DIR="$sandbox/run"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" \
         "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
# wlroots refuses a runtime directory anyone else can read.
chmod 700 "$XDG_RUNTIME_DIR"

unset WAYLAND_DISPLAY DISPLAY DBUS_SESSION_BUS_ADDRESS
export WLR_BACKENDS=headless
export WLR_RENDERER=pixman
export WLR_LIBINPUT_NO_DEVICES=1

# --- the compositor ---------------------------------------------------------
note "starting labwc headless"
labwc >"$sandbox/labwc.log" 2>&1 &
compositor_pid=$!

# wlroots picks the socket name itself with wl_display_add_socket_auto, so it
# is found rather than chosen. Setting WAYLAND_DISPLAY before starting it would
# mean something else entirely: wlroots would read it as the parent compositor
# to nest inside, and on a desktop with a session running that is the session.
socket=""
for _ in $(seq $((COMPOSITOR_TIMEOUT * 4))); do
    socket="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-[0-9]*' \
                   -type s -printf '%f\n' 2>/dev/null | sort | head -1)"
    [[ -n $socket ]] && break
    kill -0 "$compositor_pid" 2>/dev/null || break
    sleep 0.25
done

if [[ -z $socket ]]; then
    fail "labwc never opened a wayland socket"
    tail -n 20 "$sandbox/labwc.log" >&2
    exit 1
fi
export WAYLAND_DISPLAY="$socket"

# --- the shell --------------------------------------------------------------
note "loading ${SHELL_DIR#"$REPO"/}"
qs --no-color -p "$SHELL_DIR" >"$sandbox/qs.log" 2>&1 &
shell_pid=$!

loaded=0
for _ in $(seq $((LOAD_TIMEOUT * 4))); do
    if grep -q 'Configuration Loaded' "$sandbox/qs.log" 2>/dev/null; then
        loaded=1
        break
    fi
    kill -0 "$shell_pid" 2>/dev/null || break
    sleep 0.25
done

if ! kill -0 "$shell_pid" 2>/dev/null; then
    # This is the loud failure and the one worth reading closely: qs exits 255
    # when the tree will not load, and the reason is the last few lines.
    status=0
    wait "$shell_pid" || status=$?
    shell_pid=""
    fail "qs exited with status $status before the configuration loaded"
    tail -n 30 "$sandbox/qs.log" >&2
elif (( loaded == 0 )); then
    fail "qs is still running but never printed \"Configuration Loaded\""
    tail -n 30 "$sandbox/qs.log" >&2
else
    note "the shell loaded: $qml_count .qml file(s) parsed and instantiated"

    # THEN LET IT RUN FOR A MOMENT. "Configuration Loaded" is printed while
    # bindings are still being evaluated, and a name that does not resolve
    # surfaces on the first evaluation of the binding that wanted it -- which
    # for most of this tree is a frame or two after the line above. Scanning
    # the log at the instant it appears would read half of it.
    sleep "$SETTLE"

    # The four strings, and nothing looser. Everything else in this log is
    # about the sandbox rather than about the code -- no DBus, no PipeWire, no
    # UPower, no ~/.face, no niri config -- and those all announce themselves
    # as a service declining rather than as a name failing to resolve. Matching
    # WARN or ERROR wholesale would make this check a list of exceptions to
    # maintain instead of an assertion.
    if broken="$(grep -nE 'ReferenceError|TypeError|Unable to assign|is not a type' \
                      "$sandbox/qs.log")"; then
        count="$(wc -l <<<"$broken")"
        fail "the shell loaded, but $count log line(s) name something that does not resolve"
        head -n 20 <<<"$broken" >&2
        (( count > 20 )) && echo "shell-load: ... and $(( count - 20 )) more" >&2
    fi
fi

if [[ $failed -eq 0 ]]; then
    note "the whole shell comes up in a headless compositor"
fi
exit "$failed"
