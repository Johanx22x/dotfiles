#!/usr/bin/env bash
# Does a theme that PINS a scheme give the desktop back when it is left?
#
# `desktop-scheme` keeps two keys and not one -- `scheme` is what renders,
# `chosen` is what the person last picked for themselves -- and the entire
# reason for the second one is the round trip this file measures:
#
#     the user picks catppuccin-mocha        scheme=catppuccin  chosen=catppuccin
#     a theme that pins gruvbox is entered   scheme=gruvbox     chosen=catppuccin
#     that theme is left                     scheme=catppuccin  chosen=catppuccin
#
# THE TWO TRANSITIONS ARE THE SHELL'S NOW, AND THAT IS WHAT THIS FILE IS FOR.
# It used to run `desktop-scheme pin` and `unpin` itself, because nothing else
# did, and it carried a tripwire that went red the day the wiring arrived so
# that whoever built it would re-aim this check at the real path. The wiring is
# here: a manifest declares `"palette": {"source": "pinned", "scheme": "..."}`,
# Theme.qml reads it off the theme being DRAWN, and Config.qml's `pinScheme` and
# `unpinScheme` spawn the script. So the theme is entered and left the way a
# person enters and leaves one -- by writing `theme` into the config.json a
# running shell is watching -- and nothing here spells `pin` or `unpin` except
# the fresh-install phase at the bottom, which is about the script alone.
#
# The tripwire is still here and it points the other way: `assert_the_shell_pins`
# fails if Theme.qml stops naming the source or the shell stops calling the
# script, because on that day these transitions would be writing a theme name
# into a file and asserting on a palette nothing re-rendered.
#
# WHAT IT PROVES, AND WHAT IT CANNOT. Read this before trusting the green.
#
#   IT PROVES THE WHOLE PATH, ON THE EFFECT AND NOT ON THE STATE FILE. Every
#   transition deletes the rendered palette first and then requires matugen to
#   have written it again, out of whatever `desktop-scheme path` answered -- so
#   a pin that recorded a name and re-rendered nothing fails here, which is the
#   shape of the "passes because nothing happened" test this whole design was
#   meant to avoid. What is compared is the colour that landed in the shell's
#   own colors.json against the `ui_surface` of the scheme that was supposed to
#   be in force.
#
#   THE FIRST STEP IS NOT THE SHELL'S AND CANNOT BE. A person picks a scheme by
#   clicking a row on the settings window's appearance page, and there is no way
#   to synthesize that click here -- so step 1 runs `desktop-scheme set`
#   directly, which is the same command that click ends in and the same one a
#   terminal or a keybind uses. What the shell has to do by itself is the two
#   TRANSITIONS, and those are what steps 2 and 3 drive through it.
#
#   IT DOES NOT COVER A PINNING THEME THAT STOPS BEING DRAWN WHILE THE SHELL IS
#   NOT RUNNING -- removed, or its manifest broken, so the next start falls back
#   to genesis. There is no transition for the shell to see, so the pin stands
#   until something moves it. That is a decision rather than an oversight and
#   the note on `onPinnedSchemeChanged` in Theme.qml is where it is argued.
#
#   THE LAST PHASE IS ABOUT THE SCRIPT ALONE, deliberately. `chosen()` used to
#   fall back to `current()`, so a `pin` on a machine that had never picked a
#   scheme recorded ITSELF as the person's choice and `unpin` had nothing to go
#   back to -- and a machine that has never picked one is every fresh clone,
#   because the store does not exist until somebody does. The shell is not
#   needed to ask that question and would only make it slower to answer.
#
# SAFE TO RUN ON THE MACHINE IT IS FOR, which is not a courtesy: `desktop-scheme
# set` ends in `wallpaper-switch reapply`, a real matugen render over fourteen
# files plus the applications that get signalled afterwards, and this file now
# starts a real Quickshell as well. Nothing here reaches any of that. The
# repository's bin/ and schemes/ are COPIED into a sandbox and $PATH is pointed
# at the copy -- so the `desktop-scheme` the SHELL spawns by name is the one in
# here and never ~/.local/bin's -- `wallpaper-switch` is replaced there by a
# stub that renders one template into the sandbox, XDG_STATE_HOME points at the
# sandbox so the real ~/.local/state/desktop-scheme is never opened, the matugen
# config is written here with no post_hook in it at all, and the compositor is a
# headless labwc of this run's own with WAYLAND_DISPLAY and DISPLAY unset so it
# cannot nest inside the session. The repository is opened for reading and for
# nothing else.
#
# Run it from anywhere:  tests/scheme-pinning.sh

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

FIXTURE="$REPO/tests/fixtures/theme-probe/manifest.json"
SHELL_DIR="$REPO/quickshell/.config/quickshell"
THEME_QML="$SHELL_DIR/Theme.qml"
TEMPLATE="$REPO/matugen/.config/matugen/templates/quickshell-colors.json"
SCRIPT="$REPO/bin/.local/bin/desktop-scheme"

# The theme the probe is entered FROM and left back to. The shipped one, which
# is the theme a desktop starts on and the one Config.qml defaults to.
BASE_THEME="genesis"
PROBE_NAME="theme-probe"

# The scheme the PERSON picks in this story. Deliberately not `tokyo-night`:
# that is desktop-scheme's DEFAULT_SCHEME, so `set tokyo-night` on a fresh
# state file moves nothing and `commit` declines to re-render -- a first step
# that rendered no file at all would leave the two later assertions comparing
# against a palette nobody wrote.
USER_SCHEME="catppuccin-mocha"

# How long a transition is given to reach the rendered file. It is not a speed
# measurement: one matugen render of one template is a fraction of a second, and
# the shell's half is a file watch, a manifest read and a process spawn. Twenty
# seconds is "this did not happen", not "this was slow".
RENDER_TIMEOUT=20
COMPOSITOR_TIMEOUT=20
LOAD_TIMEOUT=90

problems=0

fail() {
    printf 'scheme-pinning: FAIL %s\n' "$*" >&2
    problems=$(( problems + 1 ))
}

die() {
    printf 'scheme-pinning: %s\n' "$*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# The floor: does the fixture still pin anything?
# ---------------------------------------------------------------------------
# FIRST, AND FATAL RATHER THAN COUNTED. Everything below is a round trip
# through a scheme this file reads out of the fixture, so a fixture that has
# stopped pinning does not make these assertions weaker -- it makes them
# meaningless, and a check with nothing left to measure has to say so instead
# of printing that it passed.

command -v jq >/dev/null || die "jq is not installed; the manifests and the schemes are JSON"
command -v matugen >/dev/null || die "matugen is not installed; there is no way to render an effect to assert on"
# The same two the shell needs, and named the same way tests/shell-load.sh names
# them: this check drives the transitions through a running Quickshell now, so a
# missing one is a check that cannot run rather than one that passes cheaply.
command -v qs >/dev/null || die "quickshell is not installed; the transitions are driven through a running shell"
command -v labwc >/dev/null || die "labwc is not installed; qs needs a compositor for its PanelWindows"

[[ -r "$FIXTURE" ]] || die "$FIXTURE is missing -- the pinning theme is the only caller this path has"

jq -e . "$FIXTURE" >/dev/null 2>&1 || die "$FIXTURE is not JSON"

declared="$(jq -r '.palette.source // "unset"' "$FIXTURE")"
[[ "$declared" == "pinned" ]] || die \
    "tests/fixtures/theme-probe declares palette.source '$declared' and not 'pinned'.
        That fixture is the only theme in the repository that pins a scheme, and
        the pin is the whole subject of this check. Restore it, or delete this
        file along with it -- do not leave a check here with nothing to measure."

PINNED_SCHEME="$(jq -r '.palette.scheme // ""' "$FIXTURE")"
[[ -n "$PINNED_SCHEME" ]] || die \
    "tests/fixtures/theme-probe says palette.source is 'pinned' and names no scheme in palette.scheme"

[[ -r "$REPO/schemes/$PINNED_SCHEME.json" ]] || die \
    "tests/fixtures/theme-probe pins '$PINNED_SCHEME' and schemes/$PINNED_SCHEME.json does not exist"

[[ "$PINNED_SCHEME" != "$USER_SCHEME" ]] || die \
    "the fixture pins '$PINNED_SCHEME', which is the scheme this check has the user pick.
        The round trip would then be three steps that all look identical and it
        would pass with the restore broken. Pin something else, or change
        USER_SCHEME at the top of this file."

# AND THE THEME IT IS ENTERED FROM MUST NOT PIN, which is the other half of the
# same floor: leaving the probe is only a transition if what it is left FOR has
# no opinion of its own.
base_manifest="$SHELL_DIR/themes/$BASE_THEME/manifest.json"
[[ -r "$base_manifest" ]] || die "$base_manifest is missing -- there is no theme to enter the probe from"
base_source="$(jq -r '.palette.source // "scheme"' "$base_manifest")"
[[ "$base_source" != "pinned" ]] || die \
    "themes/$BASE_THEME pins a scheme of its own, so leaving the probe for it is not an unpin"

# The script's own default, read out of the script rather than repeated here.
# The fresh-install phase at the bottom asserts that an unpin with nothing
# recorded comes back to exactly this, and two copies of that name would be one
# copy too many.
DEFAULT_SCHEME="$(sed -n 's/^DEFAULT_SCHEME="\(.*\)"$/\1/p' "$SCRIPT")"
[[ -n "$DEFAULT_SCHEME" ]] || die "could not read DEFAULT_SCHEME out of $SCRIPT -- has it moved?"
[[ -r "$REPO/schemes/$DEFAULT_SCHEME.json" ]] || die "DEFAULT_SCHEME is '$DEFAULT_SCHEME' and there is no scheme file for it"
[[ "$DEFAULT_SCHEME" != "$PINNED_SCHEME" ]] || die \
    "the fixture pins '$PINNED_SCHEME', which is also DEFAULT_SCHEME.
        The fresh-install phase below could then not tell a restored default
        from a pin nobody undid."

# ---------------------------------------------------------------------------
# The tripwire, re-aimed: the shell has to be the thing that pins
# ---------------------------------------------------------------------------
# THIS USED TO ASSERT THE OPPOSITE, and the change of direction is the point.
# While nothing read a manifest's pinned scheme, this file drove `pin` and
# `unpin` by hand and watched for the wiring to arrive so that it could be told
# to stop. Now the wiring is what the round trip goes through, and the failure
# to guard against is the reverse: if Theme.qml stops knowing the source name,
# or nothing under quickshell/ spawns the script any more, then writing a theme
# name into config.json changes no colour at all -- and every step below would
# be waiting on a render that was never going to come. It would go red, but with
# a timeout and no idea why, which is the least useful shape a failure has.
#
# Same idea as tests/xwayland-satellite-watch.sh, pointed at the seam this
# check now depends on rather than at the gap it used to stand in for.
assert_the_shell_pins() {
    [[ -r "$THEME_QML" ]] || die "$THEME_QML is missing"

    # COMMENT LINES ARE DROPPED FIRST, because that file argues the design in
    # prose as well as implementing it, and prose is not a caller.
    grep -E '"pinned"' "$THEME_QML" | grep -qvE '^[[:space:]]*(//|\*|/\*)' || die \
        "Theme.qml no longer names the palette source \"pinned\" outside a comment.
        Nothing then reads a manifest's pin, so the two transitions below would
        write a theme name and re-render nothing. If the design has changed,
        this check has to change with it rather than time out."

    grep -rqE 'desktop-scheme["'\'',[:space:]]+(pin|unpin)' "$SHELL_DIR" 2>/dev/null || die \
        "nothing under quickshell/ calls \`desktop-scheme pin\` or \`unpin\` any more.
        That is the seam this check drives the round trip through; without it
        entering a pinning theme changes nothing on the desktop."
}

# ---------------------------------------------------------------------------
# The sandbox
# ---------------------------------------------------------------------------

sandbox="$(mktemp -d -t scheme-pinning.XXXXXXXX)"
compositor_pid=""
shell_pid=""

# Every line ends in `|| true` for the reason tests/shell-load.sh gives at its
# own trap: this runs under `set -e`, and the first non-zero return would end
# the trap where it stands and leave the sandbox behind.
cleanup() {
    if [[ -n $shell_pid ]]; then kill "$shell_pid" 2>/dev/null || true; fi
    if [[ -n $compositor_pid ]]; then kill "$compositor_pid" 2>/dev/null || true; fi
    wait 2>/dev/null || true
    rm -rf "$sandbox" || true
}
trap cleanup EXIT

# NOTHING IN THIS PROCESS MAY REACH A SESSION BUS. desktop-lib.sh's `warn` and
# `die` call notify-send whenever stderr is not a terminal, and under CI -- or
# under any harness that pipes output -- it is not. `rerender` warns on a
# wallpaper-switch that failed, which is a case this file deliberately creates.
# A popup on somebody's desktop because a test ran is not acceptable, so the
# bus address is pointed at a path that does not exist AND notify-send is
# shadowed on PATH by a recorder. Both, because either alone is one typo from
# being the only thing standing there. The shell started below can notify as
# well -- its own services complain about a sandbox with no audio server in it
# -- and the recorder is what makes the difference between the two readable
# afterwards; see the check at the bottom.
#
# THE ADDRESS IS SET AND NOT UNSET, which is the stronger of the two: an unset
# address sends libdbus looking for $XDG_RUNTIME_DIR/bus, and the shell started
# below would otherwise try to claim the notification bus name the real one is
# holding.
export DBUS_SESSION_BUS_ADDRESS="unix:path=$sandbox/there-is-no-bus-here"
unset DBUS_SESSION_BUS_PID DBUS_STARTER_ADDRESS DBUS_STARTER_BUS_TYPE

mkdir -p "$sandbox/stub"
breaches="$sandbox/notify-send-was-called"
cat > "$sandbox/stub/notify-send" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$breaches"
exit 0
EOF
chmod +x "$sandbox/stub/notify-send"
export PATH="$sandbox/stub:$PATH"

[[ "$(command -v notify-send)" == "$sandbox/stub/notify-send" ]] \
    || die "the notify-send stub is not the one on PATH; refusing to run something that can pop up on a desktop"

# HOME and the whole XDG set inside the sandbox. XDG_STATE_HOME is what
# desktop-scheme actually reads, and it is also where Quickshell keeps the
# config.json this check writes the theme into; HOME is the belt to its braces,
# because that is where both of them fall back to when the variable is unset.
export HOME="$sandbox/home"
export XDG_RUNTIME_DIR="$sandbox/run"
export XDG_STATE_HOME="$sandbox/state"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$XDG_STATE_HOME" "$XDG_CONFIG_HOME" \
         "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
# wlroots refuses a runtime directory anyone else can read.
chmod 700 "$XDG_RUNTIME_DIR"
STATE_FILE="$XDG_STATE_HOME/desktop-scheme"

unset WAYLAND_DISPLAY DISPLAY
export WLR_BACKENDS=headless
export WLR_RENDERER=pixman
export WLR_LIBINPUT_NO_DEVICES=1

# The repository's own bin/ and schemes/, copied. desktop-scheme finds the
# schemes by walking up from its own resolved path -- bin/.local/bin -> the
# repository root -- so the copy has to keep that shape for the sandbox to be
# the repository it reads.
mkdir -p "$sandbox/repo"
cp -a "$REPO/bin" "$sandbox/repo/bin"
cp -a "$REPO/schemes" "$sandbox/repo/schemes"
SANDBOX_BIN="$sandbox/repo/bin/.local/bin"
[[ -x "$SANDBOX_BIN/desktop-scheme" ]] || die "the copy has no executable desktop-scheme in it"

# AND THE COPY IS WHAT THE SHELL FINDS, which is the line that makes the rest of
# this file safe. Config.qml spawns `desktop-scheme` by NAME, so whatever $PATH
# answers is what a pin runs -- on the desktop this check is for, that is
# ~/.local/bin's stow symlink into the real checkout, and through it the real
# `wallpaper-switch`. Putting the sandbox first is what keeps a test run out of
# somebody's session, and it is checked rather than assumed.
export PATH="$SANDBOX_BIN:$PATH"
[[ "$(command -v desktop-scheme)" == "$SANDBOX_BIN/desktop-scheme" ]] \
    || die "the sandboxed desktop-scheme is not the one on PATH; refusing to let the shell re-render a real desktop"

# Where the render lands, and the config that puts it there. ONE TEMPLATE, the
# shell's, because the shell's colors.json is the one file in the fourteen
# whose contents this check has anything to say about -- and because the other
# thirteen would drag GTK, kitty, Zen and zathura paths into a sandbox for no
# assertion. NO post_hook ANYWHERE IN IT: the real config signals kitty twice,
# and this file is not allowed to signal anything on the machine it runs on.
mkdir -p "$sandbox/rendered"
RENDERED="$sandbox/rendered/colors.json"
MATUGEN_CONF="$sandbox/matugen.toml"
[[ -r "$TEMPLATE" ]] || die "$TEMPLATE is missing -- there is nothing to render"
{
    printf '# Written by tests/scheme-pinning.sh. No post_hook, by design.\n'
    printf '[config]\n\n'
    printf '[templates.quickshell]\n'
    printf "input_path = '%s'\n" "$TEMPLATE"
    printf "output_path = '%s'\n" "$RENDERED"
} > "$MATUGEN_CONF"

# THE STAND-IN FOR wallpaper-switch, and it stands in for exactly one step of
# it. `desktop-scheme` never renders anything itself: it writes its state and
# calls `wallpaper-switch reapply`, which asks it back for `path` and hands
# that file to matugen. This is that, with the image replaced by a fixed seed
# colour -- `matugen color hex` rather than `matugen image` -- because the
# accent is the wallpaper's half of the palette and every role this check reads
# is on the scheme's half. A fixed seed also makes the accent identical in all
# three renders, so a difference between them can only have come from the
# scheme.
cat > "$SANDBOX_BIN/wallpaper-switch" <<EOF
#!/usr/bin/env bash
# Stand-in written by tests/scheme-pinning.sh. Not the real one.
set -euo pipefail
here="\$(dirname "\$(readlink -f "\$0")")"
scheme_file="\$("\$here/desktop-scheme" path)"
exec matugen color hex '#7aa2f7' --mode dark --quiet \\
    -c '$MATUGEN_CONF' --import-json "\$scheme_file"
EOF
chmod +x "$SANDBOX_BIN/wallpaper-switch"

# ---------------------------------------------------------------------------
# The shell, and the tree it draws out of
# ---------------------------------------------------------------------------
# A COPY OF THE TREE, for the reason tests/shell-load.sh copies it: a theme can
# only be loaded from inside the shell directory, and the probe lives under
# tests/ on purpose so that nothing on a real desktop can choose it. The copy is
# also what keeps this check off the repository -- the shell writes its
# config.json into the state directory, and that is in the sandbox too.
tree="$sandbox/shell"
cp -a "$SHELL_DIR" "$tree"
cp -a "$REPO/tests/fixtures/theme-probe" "$tree/themes/$PROBE_NAME"

# WHERE Config.theme HAS TO BE WRITTEN. Quickshell 0.3.1 spells statePath()
# $XDG_STATE_HOME/quickshell/by-shell/<id>/config.json, where <id> is the md5 of
# the absolute path of shell.qml -- measured rather than documented, which is
# tests/shell-load.sh's finding and its wording.
shell_id="$(printf '%s' "$tree/shell.qml" | md5sum | cut -d' ' -f1)"
CONFIG_JSON="$XDG_STATE_HOME/quickshell/by-shell/$shell_id/config.json"
mkdir -p "$(dirname "$CONFIG_JSON")"

write_theme() {
    printf '{\n    "theme": "%s"\n}\n' "$1" > "$CONFIG_JSON"
}

start_compositor() {
    labwc >"$sandbox/labwc.log" 2>&1 &
    compositor_pid=$!

    # wlroots picks the socket name itself with wl_display_add_socket_auto, so
    # it is found rather than chosen. Setting WAYLAND_DISPLAY before starting it
    # would mean something else entirely: wlroots reads it as the compositor to
    # nest inside, and on this desktop that is the session.
    local socket=""
    local _
    for _ in $(seq $((COMPOSITOR_TIMEOUT * 4))); do
        socket="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-[0-9]*' \
                       -type s -printf '%f\n' 2>/dev/null | sort | head -1)"
        [[ -n $socket ]] && break
        kill -0 "$compositor_pid" 2>/dev/null || break
        sleep 0.25
    done

    [[ -n $socket ]] || {
        tail -n 20 "$sandbox/labwc.log" >&2
        die "labwc never opened a wayland socket"
    }
    export WAYLAND_DISPLAY="$socket"
}

start_shell() {
    local log="$sandbox/shell.log"

    write_theme "$BASE_THEME"
    qs --no-color -p "$tree" >"$log" 2>&1 &
    shell_pid=$!

    local _
    for _ in $(seq $((LOAD_TIMEOUT * 4))); do
        grep -q 'Configuration Loaded' "$log" 2>/dev/null && return 0
        kill -0 "$shell_pid" 2>/dev/null || break
        sleep 0.25
    done

    tail -n 30 "$log" >&2
    die "the shell never printed \"Configuration Loaded\"; there is nothing here to drive"
}

# ---------------------------------------------------------------------------
# Reading the two sides of an assertion
# ---------------------------------------------------------------------------

# What the SCHEME says its window colour is. ui_surface and not one of the
# accent roles: the accent comes from the seed above and is the same in every
# render here, so it is the one field that could not tell two schemes apart.
scheme_surface() {
    jq -r '.colors.ui_surface.default.color' "$sandbox/repo/schemes/$1.json"
}

# What actually LANDED in the file the shell reads. Theme.qml binds its
# `surface` to this key through a watching FileView, so this is the colour the
# desktop would be wearing.
rendered_surface() {
    jq -r '.surface' "$RENDERED"
}

state() {
    # The store is TAB-separated, one key per line -- desktop-lib.sh's format.
    [[ -r "$STATE_FILE" ]] || { printf '\n'; return; }
    awk -F'\t' -v k="$1" '$1 == k { print $2 }' "$STATE_FILE"
}

# ---------------------------------------------------------------------------
# One step of the round trip
# ---------------------------------------------------------------------------
# THE RENDERED FILE IS DELETED BEFORE EVERY STEP and required to exist after
# it. That is the whole defence against the failure this design was built to
# avoid: a transition that writes a state key, renders nothing, and leaves the
# previous run's file on disk saying whatever the assertion wanted to hear.
#
# WAITING IS NOT THE SAME AS SLEEPING, and the third argument is which of the
# two this is. What a theme swap starts is asynchronous -- a file watch, a
# manifest read, a process, a render -- so the only honest signal is the
# rendered file appearing and the only honest failure is it not appearing within
# a length of time nothing legitimate takes. A step that ran `desktop-scheme`
# itself is the opposite: the script does not return until the render it decided
# on has finished, so a file that is not there the instant it exits is never
# going to be there, and waiting twenty seconds to say so would only make a
# broken script slow to catch.
await_render() {
    local what=$1 expect_scheme=$2 wait_for=${3:-0}
    local _

    for _ in $(seq $(( wait_for * 4 ))); do
        [[ -f "$RENDERED" ]] && break
        if [[ -n $shell_pid ]] && ! kill -0 "$shell_pid" 2>/dev/null; then
            fail "[$what] the shell exited while this transition was in flight"
            tail -n 30 "$sandbox/shell.log" >&2
            shell_pid=""
            return 1
        fi
        sleep 0.25
    done

    if [[ ! -f "$RENDERED" ]]; then
        if (( wait_for > 0 )); then
            fail "[$what] nothing was rendered within ${wait_for}s.
        The state file may well say the right thing; no application on the
        machine would have changed colour. The shell only pins when it sees the
        theme it draws change, and desktop-scheme's \`commit\` only re-renders
        when what renders actually moved -- see the comment there."
        else
            fail "[$what] the script returned without anything being rendered.
        The state file may well say the right thing; no application on the
        machine would have changed colour. desktop-scheme's \`commit\` only
        re-renders when what renders actually moved -- see the comment there."
        fi
        return 1
    fi

    local want got
    want="$(scheme_surface "$expect_scheme")"
    got="$(rendered_surface)"
    if [[ "$want" != "$got" ]]; then
        fail "[$what] the desktop is wearing $got and $expect_scheme's window is $want.
        This is the rendered colors.json, not the state file: whatever was
        recorded, the colour that reached the shell is the wrong scheme's."
        return 1
    fi

    printf 'scheme-pinning:   %-34s rendered %s (%s)\n' "$what" "$got" "$expect_scheme"
    return 0
}

# The person's own step, and the only one that is not the shell's. See the
# header: there is no way to synthesize the click, and this is the command it
# ends in.
picks_a_scheme() {
    local what=$1 name=$2

    rm -f "$RENDERED"
    if ! "$SANDBOX_BIN/desktop-scheme" set "$name" \
            > "$sandbox/last-step.out" 2> "$sandbox/last-step.err"; then
        fail "[$what] \`desktop-scheme set $name\` exited non-zero"
        sed 's/^/        /' "$sandbox/last-step.err" >&2
        return 1
    fi

    await_render "$what" "$name"
}

# A THEME IS ENTERED AND LEFT BY WRITING ITS NAME, which is exactly what the
# picker on the appearance page does: `Config.theme` is a plain adapter value
# and one click assigns it. Writing the file the running shell is watching is
# the same event arriving from the other side, and it is what
# tests/shell-load.sh's swap phase already uses to change a theme underneath a
# live shell.
wears_theme() {
    local what=$1 theme=$2 expect_scheme=$3

    rm -f "$RENDERED"
    write_theme "$theme"
    await_render "$what" "$expect_scheme" "$RENDER_TIMEOUT"
}

# ---------------------------------------------------------------------------
# The round trip
# ---------------------------------------------------------------------------
# Returns non-zero if any part of it did not hold, so that the mutants below
# can be run through the same three steps and required to break it.
#
# IT STOPS AT THE FIRST STEP THAT FAILED, unlike the version of this file that
# drove the script directly. The steps are a sequence -- step 2 asserts on a
# `chosen` that step 1 was supposed to write -- so what follows a broken step is
# not a second finding, it is the same one restated. It also keeps a mutant to
# one timeout instead of three.
round_trip() {
    local before=$problems

    rm -f "$STATE_FILE"

    # 1. The person picks a scheme. Both keys move: this is their own choice.
    picks_a_scheme "the user picks a scheme" "$USER_SCHEME" || return 1
    [[ "$(state scheme)" == "$USER_SCHEME" ]] \
        || fail "after \`set $USER_SCHEME\`, what renders is '$(state scheme)'"
    [[ "$(state chosen)" == "$USER_SCHEME" ]] \
        || fail "after \`set $USER_SCHEME\`, the person's own choice is recorded as '$(state chosen)'"

    # 2. The pinning theme is entered -- by the shell, off the manifest.
    wears_theme "the pinning theme is entered" "$PROBE_NAME" "$PINNED_SCHEME" || return 1
    [[ "$(state scheme)" == "$PINNED_SCHEME" ]] \
        || fail "while pinned, what renders is '$(state scheme)' and not '$PINNED_SCHEME'"
    # THE ASSERTION THE SECOND KEY EXISTS FOR. A pin that overwrote `chosen`
    # would look perfect right up to the moment the theme is left, and then
    # there would be nothing left to go back to.
    [[ "$(state chosen)" == "$USER_SCHEME" ]] \
        || fail "the pin overwrote the person's own choice: chosen is now '$(state chosen)'.
        Nothing remembers $USER_SCHEME any more, so leaving this theme cannot
        give it back -- which is the entire reason desktop-scheme keeps two
        keys instead of one."

    # 3. The theme is left.
    wears_theme "the theme is left" "$BASE_THEME" "$USER_SCHEME" || return 1
    [[ "$(state scheme)" == "$USER_SCHEME" ]] \
        || fail "after leaving the theme, what renders is '$(state scheme)' and not the person's '$USER_SCHEME'"

    [[ $problems -eq $before ]]
}

# ---------------------------------------------------------------------------
# A machine that has never picked a scheme
# ---------------------------------------------------------------------------
# THE CASE THE ROUND TRIP CANNOT REACH, because it starts with a `set`. A fresh
# clone has no state file at all -- the store is not created until somebody
# picks something -- so the first thing that ever writes it may well be a pin,
# and what `unpin` then has to hand back is a scheme nobody recorded.
#
# `chosen()` used to answer `current()` there, which is the pinned scheme
# itself: the pin recorded ITSELF as the person's choice and the desktop never
# came back. What it answers now is DEFAULT_SCHEME, which is not a guess -- it
# is what `current()` says on a store with no `scheme` row either, so it is
# literally the colour the desktop was wearing before the theme was entered.
#
# ON THE SCRIPT AND NOT THROUGH THE SHELL, deliberately: this is a question
# about what the store answers when it is empty, the shell has no part in it,
# and driving it through a theme swap would only put twenty seconds and a file
# watch between the question and the answer.
fresh_install() {
    local before=$problems

    rm -f "$STATE_FILE"

    rm -f "$RENDERED"
    if ! "$SANDBOX_BIN/desktop-scheme" pin "$PINNED_SCHEME" \
            > "$sandbox/fresh.out" 2> "$sandbox/fresh.err"; then
        fail "[fresh install] \`desktop-scheme pin $PINNED_SCHEME\` exited non-zero"
        sed 's/^/        /' "$sandbox/fresh.err" >&2
        return 1
    fi
    await_render "a pin on a store with nothing in it" "$PINNED_SCHEME" || return 1

    # THE BUG, STATED AS AN ASSERTION. Nobody has picked anything, so nothing
    # may be recorded as their pick -- least of all the scheme the theme brought
    # with it.
    [[ -z "$(state chosen)" ]] \
        || fail "[fresh install] the pin recorded '$(state chosen)' as the person's own choice.
        Nobody has chosen anything on this machine: the store did not exist
        until this pin created it. Whatever \`unpin\` hands back after this, it
        is not what the desktop was wearing before the theme was entered."

    rm -f "$RENDERED"
    if ! "$SANDBOX_BIN/desktop-scheme" unpin \
            > "$sandbox/fresh.out" 2> "$sandbox/fresh.err"; then
        fail "[fresh install] \`desktop-scheme unpin\` exited non-zero"
        sed 's/^/        /' "$sandbox/fresh.err" >&2
        return 1
    fi
    await_render "and the desktop it comes back to" "$DEFAULT_SCHEME" || return 1

    [[ "$(state scheme)" == "$DEFAULT_SCHEME" ]] \
        || fail "[fresh install] after the unpin, what renders is '$(state scheme)' and not the default '$DEFAULT_SCHEME'"

    [[ $problems -eq $before ]]
}

# ---------------------------------------------------------------------------
# And the same steps against a script that gets it wrong
# ---------------------------------------------------------------------------
# A check nobody has watched fail is a check nobody knows the shape of. These
# are the failures the design names by name -- one per direction of the trip,
# and one for the fresh install -- and each is a one-line edit to the copy in
# the sandbox, run through the identical phases above. If a mutant comes back
# green, the green above meant nothing and this file says so.
#
# THE SHELL DOES NOT HAVE TO BE RESTARTED FOR ONE. It spawns `desktop-scheme` by
# name at every transition, so the copy on $PATH is read afresh each time and
# editing it between trips is enough.
mutant() {
    local what=$1 script=$2 phase=$3 caught

    cp -a "$SCRIPT" "$SANDBOX_BIN/desktop-scheme"
    sed -i "$script" "$SANDBOX_BIN/desktop-scheme"
    cmp -s "$SCRIPT" "$SANDBOX_BIN/desktop-scheme" && {
        fail "[mutant: $what] the edit changed nothing, so this proves nothing.
        desktop-scheme has moved under it: sed script '$script' matched no line."
        cp -a "$SCRIPT" "$SANDBOX_BIN/desktop-scheme"
        return
    }

    # The mutant's own failures are noise, not findings: they are the point.
    local saved=$problems
    exec 3>&2 2>/dev/null
    if "$phase" >/dev/null 2>&1; then caught=no; else caught=yes; fi
    exec 2>&3 3>&-
    problems=$saved

    if [[ "$caught" == yes ]]; then
        printf 'scheme-pinning:   %-34s caught\n' "mutant: $what"
    else
        fail "[mutant: $what] the phase passed against a desktop-scheme that is broken.
        Whatever it is measuring, it is not this -- which is the case this whole
        check exists to rule out."
    fi

    cp -a "$SCRIPT" "$SANDBOX_BIN/desktop-scheme"
    # The theme is left wherever the mutant's trip stopped, and the next one
    # starts by entering the probe. Putting it back is not tidiness: a trip that
    # began with the probe already on would never see the theme CHANGE, and the
    # shell only pins on a change.
    write_theme "$BASE_THEME"
    sleep 1
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

printf 'scheme-pinning: theme-probe pins %s; the user picks %s\n' "$PINNED_SCHEME" "$USER_SCHEME"

assert_the_shell_pins

start_compositor
start_shell
printf 'scheme-pinning: a shell is up on %s over %s\n' "$BASE_THEME" "${tree#"$sandbox"/}"

round_trip || true
fresh_install || true

# `unpin` goes back to what renders instead of to what the person chose. The
# state file and the render then BOTH stay on the pinned scheme, so only a
# check that reads one of them at the end catches it.
mutant "unpin forgets the user's choice" \
    's|set_scheme "\$(chosen)" chosen|set_scheme "$(current)" chosen|' \
    round_trip

# `pin` records the name and never re-renders. Every state key reads correctly
# at every step and the desktop never changes colour at all -- the exact test
# that passes because nothing happened.
mutant "pinning renders nothing" \
    's|^    if "\$ws" reapply >/dev/null; then|    if true; then|' \
    round_trip

# And the one this file was extended for: `chosen` falls back to what is in
# effect, so a pin on a store with nothing in it records itself and the fresh
# install never gets its desktop back.
#
# ADDRESSED TO `chosen()` AND NOT TO THE FILE, which is the one fiddly thing
# here: `current()` ends in the identical line, and an unaddressed edit would
# leave it answering `${value:-$(current)}` -- a function that calls itself
# forever. What is wanted is one function reading the other's answer, not a
# script that hangs.
mutant "a first pin becomes the user's choice" \
    '/^chosen() {/,/^}/s|"${value:-$DEFAULT_SCHEME}"|"${value:-$(current)}"|' \
    fresh_install

# WHOSE NOTIFICATION IT WAS, which this had no need to ask while the only thing
# in the sandbox was a script. There is a whole Quickshell in here now, and a
# headless shell with no audio server and no PipeWire says so out loud -- "gsr
# error: -a default_output was specified but no default audio output" is the
# sandbox declining, the same class of noise tests/shell-load.sh documents its
# logs being full of. The stub catches those too and nothing reaches a desktop
# either way; what would be a finding is one of THIS repository's scripts
# warning or dying, which is what `--app-name=` marks: lib_notify passes the
# script's own name and the shell passes `-a Quickshell`.
script_breaches="$sandbox/notify-send-from-a-script"
grep -F -- '--app-name=' "$breaches" > "$script_breaches" 2>/dev/null || true

if [[ -s "$script_breaches" ]]; then
    fail "a script in the sandbox tried to notify $(wc -l < "$script_breaches") time(s).
        The stub caught them, so nothing reached a desktop -- but lib_notify is
        only reached from \`warn\` and \`die\`, so each of these is a failure
        this run walked past. What it tried to say:
$(sed 's/^/          /' "$script_breaches")"
elif [[ -s "$breaches" ]]; then
    printf 'scheme-pinning:   %-34s %s\n' "the shell notified about the sandbox" \
        "$(wc -l < "$breaches") call(s), all caught by the stub"
fi

if [[ $problems -ne 0 ]]; then
    printf 'scheme-pinning: %d problem(s)\n' "$problems" >&2
    exit 1
fi

printf 'scheme-pinning: the shell pins what its theme names, and leaving it gives the user theirs back\n'
