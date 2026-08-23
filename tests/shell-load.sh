#!/usr/bin/env bash
# Load the whole Quickshell tree in a headless compositor, once per theme, and
# ask whether it came up -- and then whether it survives being told to draw a
# different one.
#
# ONCE PER THEME, WHICH IS NEW AND IS MOST OF THIS FILE'S REASON FOR GROWING.
# It used to start the shell once, on whatever theme the default in Config.qml
# names, and that answered a question about genesis rather than about the tree:
# every other theme's files were as unread as the whole of quickshell/ was
# before this check existed. Each theme is now a cold start of its own, with
# `theme` written into config.json before the process exists, because a cold
# start is where a theme's surfaces are built from `Config.theme` at t=0 -- a
# different path from the swap below and the one a login takes.
#
# AND THE SECOND THEME IS A FIXTURE, tests/fixtures/theme-probe/. There is one
# real theme and there is likely to be one real theme for a while, so without
# it "load every theme" is a loop that runs once and every claim about the seam
# stays a claim about genesis. The probe is deliberately ugly -- flat
# rectangles in colours nobody would choose -- and deliberately NOT under
# themes/, so that a picker never offers it. It is copied in here, at the one
# moment a second theme is wanted, and the copy is thrown away with the
# sandbox. tests/fixtures/theme-probe/README.md is what it covers and what it
# does not.
#
# THE PROBE IS THE ONLY THING IN THE TREE THAT PRINTS. Each of its seven
# surfaces logs "theme-probe drew <file>" when it is built, and those lines are
# what make two otherwise unobservable things assertable: that the theme the
# config named is the theme that drew (genesis prints nothing, so a run that
# meant to be the probe and silently fell back to genesis is a run with no
# marks), and that a swap happened at all.
#
# THE SWAP, AND WHY IT IS IN THIS FILE. themes/genesis/README.md claims the
# name can change while the shell is up -- the surfaces are rebuilt, the old
# ones destroyed, and there is no config reload. It was measured once, by hand,
# before any of the surfaces below existed. It is now the last phase here: the
# shell starts on genesis, config.json is rewritten to the probe underneath it,
# and the check waits for the seven marks and then asserts that
# "Configuration Loaded" was printed exactly ONCE in the whole run. That second
# half is the "no config reload" half, and there is no other way to see it from
# outside the process.
#
# IT NAMES A BUG THAT WAS ALREADY PAID FOR. modules/ThemeSurface.qml's header
# records that a `BoundComponent` fixes its source at creation --
# "BoundComponent.url cannot be set after creation" is what the log said -- so
# the theme changed and THE OLD ONE STAYED ON SCREEN. That was found by hand,
# on a desktop, and nothing in tests/ could have found it: the shell comes up,
# every name resolves, and the six strings below stay silent. This phase is
# what would have gone red.
#
# It reuses the compositor and the sandbox this file already builds rather than
# living next door, which would have meant either sixty duplicated lines of
# sandbox or a shared library tests/ does not have.
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

# The second implementation of the theme interface, and the name it is copied
# in under. tests/theme-interface.py is what keeps it complete; the directory
# is named for what it is so that the name it takes inside themes/ is the same
# string, and modules/Themes.qml's warning about a manifest calling itself
# something else stays quiet.
PROBE="$REPO/tests/fixtures/theme-probe"
PROBE_NAME="theme-probe"

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

# Said here rather than left to `cp` a hundred lines down, because the answer
# to "this fixture is gone" is not a copy failing: it is that this check goes
# back to loading one theme and proving one theme.
[[ -f $PROBE/manifest.json ]] || {
    echo "shell-load: ${PROBE#"$REPO"/} has no manifest.json -- the second theme is missing" >&2
    echo "shell-load: without it this loads genesis and nothing else" >&2
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

# --- the tree every run loads out of ----------------------------------------
#
# A COPY OF THE TREE, AND THE COPY IS WHAT MAKES A SECOND THEME POSSIBLE AT
# ALL. modules/Themes.qml turns a name into `themes/<name>/<file>` under
# Quickshell.shellPath, so the only place a theme can be loaded from is inside
# the shell directory -- and the probe deliberately lives under tests/ so that
# nothing on a real desktop can choose it. Copying 2.4 MB and dropping the
# fixture in is what reconciles the two, and it is gone with the sandbox.
#
# The copy is also what keeps this check off the repository: config.json is
# written by the shell into a state directory, and the theme name is written by
# this script into the same place. Nothing under $REPO is opened for writing.
tree="$sandbox/shell"
cp -a "$SHELL_DIR" "$tree"
cp -a "$PROBE" "$tree/themes/$PROBE_NAME"

mapfile -t themes < <(find "$tree/themes" -mindepth 1 -maxdepth 1 -type d \
                           -printf '%f\n' | sort)

# THE FLOOR ON THE LOOP, and it is the one this whole file was extended to get
# past. A check that loads every theme and finds one theme has proved something
# about that theme; a check that finds none passes in the same words it uses
# when it means it.
if (( ${#themes[@]} < 2 )); then
    echo "shell-load: found ${#themes[@]} theme(s) to load, and this needs at least 2" >&2
    echo "shell-load: one theme cannot show the host is neutral about which one draws" >&2
    exit 1
fi
if [[ ! -d $tree/themes/$PROBE_NAME ]]; then
    echo "shell-load: $PROBE is missing -- the fixture is the second theme" >&2
    exit 1
fi

# WHERE Config.theme HAS TO BE WRITTEN, WHICH IS NOT A PATH THIS REPOSITORY
# CHOOSES. Config.qml reads `Quickshell.statePath("config.json")`, and
# Quickshell 0.3.1 spells that
# $XDG_STATE_HOME/quickshell/by-shell/<id>/config.json where <id> is the md5 of
# the absolute path of shell.qml. That was measured here rather than read out
# of a document, so it is exactly the kind of thing that changes under a check
# without saying so -- which is why every run below also asserts that the file
# it wrote is the file the shell read. If Quickshell ever picks a different id,
# the seed lands somewhere nothing reads, the shell writes a second config.json
# of its own in the right place, and the count goes to two.
shell_id="$(printf '%s' "$tree/shell.qml" | md5sum | cut -d' ' -f1)"

# The six strings, and nothing looser. Everything else in these logs is about
# the sandbox rather than about the code -- no DBus, no PipeWire, no UPower, no
# ~/.face, no niri config -- and those all announce themselves as a service
# declining rather than as a name failing to resolve. Matching WARN or ERROR
# wholesale would make this check a list of exceptions to maintain instead of
# an assertion.
#
# "Binding loop detected" is the sixth and it was added last, after a component
# split put a facade's width behind the loaded item's implicitWidth -- the
# exact shape that closes a cycle. Qt breaks the loop and carries on, so the
# shell still comes up and every other string here stays silent; the only trace
# is that one WARN. Demonstrated before it was added: `implicitHeight:
# bar.height + 1` in Bar.qml logs `Binding loop detected for property
# "implicitHeight"` and the five strings above match none of it.
BROKEN='ReferenceError|TypeError|Unable to assign|is not a type|Syntax error|Binding loop detected'

scan_log() {
    local what=$1 log=$2 broken count
    if broken="$(grep -nE "$BROKEN" "$log")"; then
        count="$(wc -l <<<"$broken")"
        fail "[$what] the shell loaded, but $count log line(s) name something that does not resolve"
        head -n 20 <<<"$broken" >&2
        (( count > 20 )) && echo "shell-load: ... and $(( count - 20 )) more" >&2
    fi
}

# How many of the probe's seven surfaces have said they drew. genesis prints
# nothing at all, so this is also how a run says WHICH theme it drew.
marks() { grep -c 'theme-probe drew ' "$1" 2>/dev/null || true; }

stop_shell() {
    [[ -n $shell_pid ]] || return 0
    kill "$shell_pid" 2>/dev/null || true
    wait "$shell_pid" 2>/dev/null || true
    shell_pid=""
}

# Start the shell with `theme` already chosen, and wait for it to say so.
# Leaves it running, with its pid in shell_pid, for the caller to look at.
start_shell() {
    local theme=$1 state=$2 log=$3
    local dir="$state/quickshell/by-shell/$shell_id"

    mkdir -p "$dir"
    printf '{\n    "theme": "%s"\n}\n' "$theme" >"$dir/config.json"

    XDG_STATE_HOME="$state" qs --no-color -p "$tree" >"$log" 2>&1 &
    shell_pid=$!

    for _ in $(seq $((LOAD_TIMEOUT * 4))); do
        grep -q 'Configuration Loaded' "$log" 2>/dev/null && return 0
        kill -0 "$shell_pid" 2>/dev/null || return 1
        sleep 0.25
    done
    return 1
}

# --- every theme, one cold start each ---------------------------------------
probe_marks=0

for theme in "${themes[@]}"; do
    note "starting the shell with theme \"$theme\""
    state="$sandbox/state/$theme"
    log="$sandbox/$theme.log"

    if ! start_shell "$theme" "$state" "$log"; then
        if ! kill -0 "$shell_pid" 2>/dev/null; then
            # The loud failure and the one worth reading closely: qs exits 255
            # when the tree will not load, and the reason is the last few lines.
            status=0
            wait "$shell_pid" || status=$?
            shell_pid=""
            fail "[$theme] qs exited with status $status before the configuration loaded"
        else
            fail "[$theme] qs is still running but never printed \"Configuration Loaded\""
            stop_shell
        fi
        tail -n 30 "$log" >&2
        continue
    fi

    # THEN LET IT RUN FOR A MOMENT. "Configuration Loaded" is printed while
    # bindings are still being evaluated, and a name that does not resolve
    # surfaces on the first evaluation of the binding that wanted it -- which
    # for most of this tree is a frame or two after that line. Scanning the log
    # at the instant it appears would read half of it.
    sleep "$SETTLE"
    scan_log "$theme" "$log"

    # DID THE THEME THIS RUN IS ABOUT ACTUALLY DRAW? Two ways of asking, and
    # neither is redundant. The shell writes its config back, so the file it
    # read is the file that is there afterwards -- and a seed that landed
    # somewhere Quickshell does not look leaves a SECOND one beside it. The
    # marks are the other end of the same question: the probe says what it
    # drew, so a run that meant to be the probe and quietly fell back to
    # genesis is a run with nothing in it.
    written="$(find "$state" -name config.json -type f | wc -l)"
    if (( written != 1 )); then
        fail "[$theme] $written config.json under this run's state directory, expected 1 --" \
             "the seeded one was not the one the shell read"
    elif ! grep -q "\"theme\": \"$theme\"" "$(find "$state" -name config.json -type f)"; then
        fail "[$theme] the shell's own config.json does not name this theme afterwards"
    fi

    if [[ $theme == "$PROBE_NAME" ]]; then
        probe_marks="$(marks "$log")"
        if (( probe_marks == 0 )); then
            fail "[$theme] the shell came up and not one of the probe's surfaces drew --" \
                 "the configured theme is not the theme on screen"
        else
            note "[$theme] $probe_marks probe surface(s) drew"
        fi
    elif (( $(marks "$log") > 0 )); then
        fail "[$theme] the probe's surfaces drew under a theme that is not the probe"
    fi

    stop_shell
    note "[$theme] the shell came up over a tree of $qml_count .qml file(s) plus this theme"
done

# --- and now change the theme under a running shell -------------------------
#
# THE CLAIM IS "NO CONFIG RELOAD", and the only way to see that from outside is
# to count. "Configuration Loaded" is printed once per configuration load, so a
# swap that rebuilt the world would print it twice. What has to happen instead
# is that the surfaces are rebuilt inside the engine that is already running --
# which nothing outside can see either, until the theme being swapped TO says
# so. That is what the probe's seven lines are for.
#
# It starts on the fallback theme rather than on whatever sorted first, because
# what is being tested is a change, and Config.qml's own default is where a
# desktop starts.
if (( probe_marks > 0 )); then
    note "swapping the theme under a running shell"
    state="$sandbox/state/swap"
    log="$sandbox/swap.log"

    if ! start_shell genesis "$state" "$log"; then
        fail "[swap] the shell would not come up on genesis to swap away from"
        tail -n 30 "$log" >&2
        stop_shell
    else
        sleep "$SETTLE"

        if (( $(marks "$log") > 0 )); then
            fail "[swap] the probe drew before anything asked it to"
        fi

        # In place, on the file the shell is watching. Config.qml's FileView
        # has watchChanges and reloads on fileChanged; nothing else is touched.
        printf '{\n    "theme": "%s"\n}\n' "$PROBE_NAME" \
            >"$state/quickshell/by-shell/$shell_id/config.json"

        swapped=0
        for _ in $(seq $((LOAD_TIMEOUT * 4))); do
            (( $(marks "$log") >= probe_marks )) && { swapped=1; break; }
            kill -0 "$shell_pid" 2>/dev/null || break
            sleep 0.25
        done

        if ! kill -0 "$shell_pid" 2>/dev/null; then
            status=0
            wait "$shell_pid" || status=$?
            shell_pid=""
            fail "[swap] qs exited with status $status when the theme changed"
            tail -n 30 "$log" >&2
        elif (( swapped == 0 )); then
            fail "[swap] the theme changed and only $(marks "$log") of $probe_marks" \
                 "probe surface(s) were rebuilt -- the old theme is still on screen"
            tail -n 30 "$log" >&2
        else
            sleep "$SETTLE"
            scan_log swap "$log"

            # THE OTHER HALF, AND THE HALF THE CLAIM IS ABOUT. Everything
            # above would be just as true of a shell that had thrown its
            # configuration away and read it again.
            reloads="$(grep -c 'Configuration Loaded' "$log")"
            if (( reloads != 1 )); then
                fail "[swap] \"Configuration Loaded\" appears $reloads time(s) --" \
                     "the theme change reloaded the configuration instead of rebuilding the surfaces"
            else
                note "[swap] $(marks "$log") surface(s) rebuilt, and the configuration was loaded once"
            fi
        fi
        stop_shell
    fi
fi

if [[ $failed -eq 0 ]]; then
    note "the whole shell comes up in a headless compositor, on each of" \
         "${#themes[@]} theme(s), and survives the theme changing under it"
fi
exit "$failed"
