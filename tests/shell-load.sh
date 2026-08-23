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
#   The log carries no ReferenceError, TypeError, "Unable to assign",
#   "is not a type" or "Syntax error". This is the half that catches the other
#   two, because a name that does not resolve in a QML binding is not a load
#   failure at all -- the binding is evaluated lazily and the shell comes up
#   looking fine. Deleting Theme.qml outright, with every module in the tree
#   reading it, still printed "Configuration Loaded" and exited 0: the only
#   trace was 200-odd "ReferenceError: Theme is not defined". Dropping
#   `pragma Singleton` from the top of it did the same, leaving "TypeError:
#   Property 'glass' of object Theme is not a function" and a long tail of
#   "Unable to assign [undefined] to QColor". A check that only asked the first
#   question would have passed both.
#
# A clean tree produces none of those five strings -- measured over repeated
# runs -- so the pattern is a floor and not a budget.
#
# "Syntax error" IS THE FIFTH AND IT ARRIVED LATE, which is worth recording
# because the shape of what it does and does not fix is the shape of this whole
# check. The first four were chosen against faults in the host chain, where a
# file that does not parse takes the configuration down with it and the
# assertion above catches it before this one is reached. A file loaded by URL
# at runtime -- which is every surface under themes/, and anything behind a
# Loader with a `source` -- fails differently: the engine logs
# "@<file>[line:1]: Syntax error" and a "Type <Name> unavailable" beside it,
# drops the one widget, and carries on. "Configuration Loaded" is printed, the
# exit status is 0, and until this string was added nothing here looked.
# Measured by appending a line of garbage to themes/genesis/bar/Clock.qml: the
# clock vanished from the bar, the log said exactly that, and this check was
# green.
#
# It is only "Syntax error" and not also "Type <Name> unavailable". The second
# line is the same event seen from the file that wanted the type, so it adds no
# coverage here, and it has a failure mode of its own -- a type can be
# unavailable because a service is absent, which in this sandbox is a normal
# thing to be. One string, one meaning: nothing in this repository prints
# "Syntax error" itself, the engine is the only source of it, and there is no
# state of the sandbox that produces one.
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
# AND IT CANNOT SEE A FILE THAT NOTHING RUNS, which is the limit that matters
# most as this tree grows and is the reason tests/qml-lint.sh now carries the
# parse check rather than this file carrying it alone. QML compiles a type when
# something INSTANTIATES it, so a file nothing reaches is a file nothing reads,
# and a shell that never reached it starts perfectly and logs nothing. Measured
# by breaking all 126 .qml files in the tree one at a time and running this
# check against each: it caught 80, and of the 46 it did not, 43 at least left
# a "Syntax error" in the log for the fifth string above to find. The other
# three -- components/ClickCatcher.qml, ConfirmButton.qml and HyprlandGrab.qml,
# each named only from inside a delegate of a document that is itself loaded by
# URL -- produced a green run over an empty log with an unparseable file on
# disk. No string added here can fix that, because there is no line to match:
# a linter that reads every file whether or not anything runs it is the only
# instrument that answers, and that is tests/qml-lint.sh.
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

# Named the way the other checks name what they need, so the answer to "this
# does not run on my machine" is on the line that says so. Neither is skipped
# when absent, unlike actionlint in tests/workflows.py: a check that quietly
# does nothing is the thing this whole file exists to stop.
declare -A provided_by=([labwc]=labwc [qs]=quickshell)
for tool in labwc qs; do
    command -v "$tool" >/dev/null || {
        echo "shell-load: $tool is not installed -- pacman -S ${provided_by[$tool]}" >&2
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
    #
    # Every line ends in `|| true`, and not as a reflex. This runs as an EXIT
    # trap under `set -e`, so the first command that returns non-zero ends the
    # trap where it stands and the sandbox is never deleted -- and on the
    # failure path there is a lot to return non-zero with: shell_pid is empty
    # when qs died on its own, `kill` fails on a process that has already gone,
    # and `wait` reports the 143 it got for the one that had not.
    if [[ -n $shell_pid ]]; then kill "$shell_pid" 2>/dev/null || true; fi
    if [[ -n $compositor_pid ]]; then kill "$compositor_pid" 2>/dev/null || true; fi
    wait 2>/dev/null || true
    rm -rf "$sandbox" || true
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
    # NOT "parsed and instantiated", which is what this line used to claim and
    # is not true of most of them: 46 of the 126 are never reached by a shell
    # that starts, so the number is the size of the tree it came up over and
    # not a count of what it read. See the section on that in the header.
    note "the shell came up over a tree of $qml_count .qml file(s)"

    # THEN LET IT RUN FOR A MOMENT. "Configuration Loaded" is printed while
    # bindings are still being evaluated, and a name that does not resolve
    # surfaces on the first evaluation of the binding that wanted it -- which
    # for most of this tree is a frame or two after the line above. Scanning
    # the log at the instant it appears would read half of it.
    sleep "$SETTLE"

    # The six strings, and nothing looser. Everything else in this log is
    # about the sandbox rather than about the code -- no DBus, no PipeWire, no
    # UPower, no ~/.face, no niri config -- and those all announce themselves
    # as a service declining rather than as a name failing to resolve. Matching
    # WARN or ERROR wholesale would make this check a list of exceptions to
    # maintain instead of an assertion.
    #
    # "Binding loop detected" is the sixth and it was added last, after a
    # component split put a facade's width behind the loaded item's
    # implicitWidth -- the exact shape that closes a cycle. Qt breaks the loop
    # and carries on, so the shell still comes up and every other string here
    # stays silent; the only trace is that one WARN. Demonstrated before it was
    # added: `implicitHeight: bar.height + 1` in Bar.qml logs
    # `Binding loop detected for property "implicitHeight"` and the five
    # strings above match none of it.
    if broken="$(grep -nE 'ReferenceError|TypeError|Unable to assign|is not a type|Syntax error|Binding loop detected' \
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
