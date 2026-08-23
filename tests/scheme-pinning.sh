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
# The header of bin/.local/bin/desktop-scheme states that shape and ends with
# "Nothing pins anything today and the keys cost two lines." That sentence was
# the objection: a code path with no caller. tests/fixtures/theme-probe is the
# caller -- its manifest declares `"palette": {"source": "pinned", "scheme":
# "gruvbox-dark"}` -- and this check is what turns the promise into a
# measurement.
#
# WHAT IT PROVES, AND WHAT IT CANNOT. Read this before trusting the green.
#
#   IT PROVES the script half, on the EFFECT and not on the state file. Every
#   transition below deletes the rendered palette first and then requires
#   matugen to have written it again, out of whatever `desktop-scheme path`
#   answered -- so a `pin` that recorded a name and re-rendered nothing fails
#   here, which is the shape of the "passes because nothing happened" test this
#   whole design was meant to avoid. What is compared is the colour that landed
#   in the shell's own colors.json against the `ui_surface` of the scheme that
#   was supposed to be in force.
#
#   IT DOES NOT COVER A PIN ON A MACHINE THAT HAS NEVER PICKED A SCHEME, and
#   that is a gap rather than a decision -- the round trip starts with a `set`
#   because a `pin` before any `set` does not round-trip today. `chosen()` in
#   desktop-scheme falls back to `current()` when the key is unset, so on a
#   store with no `chosen` row the pin records ITSELF as the person's own
#   choice and `unpin` has nothing left to go back to. Measured on a fresh
#   store: `pin gruvbox-dark` leaves `show` printing `chosen gruvbox-dark`, and
#   `unpin` answers "already in effect". Nothing here asserts on that, because
#   the fix is in bin/ and this file only reads it; it is written down so the
#   green above is not read as covering it.
#
#   IT CANNOT PROVE THAT ENTERING THE THEME IS WHAT CALLS `pin`, because
#   nothing calls it. The wiring from a manifest to this script does not exist:
#   Theme.qml's adoptPalette refuses every source but "scheme" and its
#   palettePath switch has no "pinned" case, Config.qml's only scheme seam is
#   setScheme -> `desktop-scheme set`, and no file in the tree reads a
#   manifest's pinned scheme or spells the words `pin` or `unpin`. So the two
#   transitions here are performed by this script standing in for the shell,
#   and `assert_shell_still_cannot_pin` below is a tripwire that fails the day
#   that stops being true -- so that whoever builds the wiring is told, by
#   name, that this test is now measuring less than it should.
#
# SAFE TO RUN ON THE MACHINE IT IS FOR, which is not a courtesy: `desktop-scheme
# set` ends in `wallpaper-switch reapply`, a real matugen render over fourteen
# files plus the applications that get signalled afterwards. Nothing here
# reaches any of that. The repository's bin/ and schemes/ are COPIED into a
# sandbox, `wallpaper-switch` is replaced there by a stub that renders one
# template into the sandbox, XDG_STATE_HOME points at the sandbox so the real
# ~/.local/state/desktop-scheme is never opened, and the matugen config is
# written here with no post_hook in it at all. The repository is opened for
# reading and for nothing else.
#
# Run it from anywhere:  tests/scheme-pinning.sh

set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

FIXTURE="$REPO/tests/fixtures/theme-probe/manifest.json"
THEME_QML="$REPO/quickshell/.config/quickshell/Theme.qml"
TEMPLATE="$REPO/matugen/.config/matugen/templates/quickshell-colors.json"

# The scheme the PERSON picks in this story. Deliberately not `tokyo-night`:
# that is desktop-scheme's DEFAULT_SCHEME, so `set tokyo-night` on a fresh
# state file moves nothing and `commit` declines to re-render -- a first step
# that rendered no file at all would leave the two later assertions comparing
# against a palette nobody wrote.
USER_SCHEME="catppuccin-mocha"

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

# ---------------------------------------------------------------------------
# The tripwire: the shell still cannot do this by itself
# ---------------------------------------------------------------------------
# THIS FAILING IS GOOD NEWS AND IT IS STILL A FAILURE. What it watches for is
# the wiring arriving -- because on the day it does, the two transitions below
# stop being an honest stand-in for the shell and become a re-implementation of
# it, which is the exact shape of a test that agrees with itself.
#
# Same idea as tests/xwayland-satellite-watch.sh: a check whose job is to go
# red when the thing it was written against moves.
assert_shell_still_cannot_pin() {
    [[ -r "$THEME_QML" ]] || { fail "$THEME_QML is missing"; return; }

    # adoptPalette accepts exactly one source name, and palettePath's switch
    # has exactly one case. Either of those growing a "pinned" arm means the
    # shell has an opinion about pinning now.
    #
    # COMMENT LINES ARE DROPPED FIRST rather than tested for, because that file
    # already says the word three times in prose -- it is where the unbuilt
    # half is argued -- and a check that fired on those would have been red on
    # the day it was written.
    if grep -E '"pinned"' "$THEME_QML" | grep -qvE '^[[:space:]]*(//|\*|/\*)'; then
        fail "Theme.qml now mentions \"pinned\" outside a comment.
        If the shell has learned to pin, this check is measuring less than it
        should: it drives desktop-scheme by hand because nothing else does.
        Extend it to drive the SHELL instead, and delete this tripwire."
    fi

    if grep -rqE 'desktop-scheme["'\'',[:space:]]+(pin|unpin)' "$REPO/quickshell" 2>/dev/null; then
        fail "something under quickshell/ now calls \`desktop-scheme pin\` or \`unpin\`.
        That is the wiring this check stands in for. Drive it through that seam
        and delete this tripwire."
    fi
}

# ---------------------------------------------------------------------------
# The sandbox
# ---------------------------------------------------------------------------

sandbox="$(mktemp -d -t scheme-pinning.XXXXXXXX)"
cleanup() { rm -rf "$sandbox"; }
trap cleanup EXIT

# NOTHING IN THIS PROCESS MAY REACH A SESSION BUS. desktop-lib.sh's `warn` and
# `die` call notify-send whenever stderr is not a terminal, and under CI -- or
# under any harness that pipes output -- it is not. `rerender` warns on a
# wallpaper-switch that failed, which is a case this file deliberately creates.
# A popup on somebody's desktop because a test ran is not acceptable, so the
# bus address is pointed at a path that does not exist AND notify-send is
# shadowed on PATH by a recorder. Both, because either alone is one typo from
# being the only thing standing there.
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

# HOME and the state directory both inside the sandbox. XDG_STATE_HOME is what
# desktop-scheme actually reads; HOME is the belt to its braces, because that
# is where the script falls back to when the variable is unset.
export HOME="$sandbox/home"
export XDG_STATE_HOME="$sandbox/state"
mkdir -p "$HOME" "$XDG_STATE_HOME"
STATE_FILE="$XDG_STATE_HOME/desktop-scheme"

# The repository's own bin/ and schemes/, copied. desktop-scheme finds the
# schemes by walking up from its own resolved path -- bin/.local/bin -> the
# repository root -- so the copy has to keep that shape for the sandbox to be
# the repository it reads.
mkdir -p "$sandbox/repo"
cp -a "$REPO/bin" "$sandbox/repo/bin"
cp -a "$REPO/schemes" "$sandbox/repo/schemes"
SANDBOX_BIN="$sandbox/repo/bin/.local/bin"
[[ -x "$SANDBOX_BIN/desktop-scheme" ]] || die "the copy has no executable desktop-scheme in it"

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
step() {
    local what=$1 expect_scheme=$2
    shift 2

    rm -f "$RENDERED"

    if ! "$SANDBOX_BIN/desktop-scheme" "$@" > "$sandbox/last-step.out" 2> "$sandbox/last-step.err"; then
        fail "[$what] \`desktop-scheme $*\` exited non-zero"
        sed 's/^/        /' "$sandbox/last-step.err" >&2
        return 1
    fi

    if [[ ! -f "$RENDERED" ]]; then
        fail "[$what] \`desktop-scheme $*\` returned without anything being rendered.
        The state file may well say the right thing; no application on the
        machine would have changed colour. desktop-scheme's \`commit\` only
        re-renders when what renders actually moved -- see the comment there."
        sed 's/^/        /' "$sandbox/last-step.err" >&2
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

# ---------------------------------------------------------------------------
# The round trip
# ---------------------------------------------------------------------------
# Returns non-zero if any part of it did not hold, so that the mutants below
# can be run through the same three steps and required to break it.
round_trip() {
    local before=$problems

    rm -f "$STATE_FILE"

    # 1. The person picks a scheme. Both keys move: this is their own choice.
    step "the user picks a scheme" "$USER_SCHEME" set "$USER_SCHEME" || true
    [[ "$(state scheme)" == "$USER_SCHEME" ]] \
        || fail "after \`set $USER_SCHEME\`, what renders is '$(state scheme)'"
    [[ "$(state chosen)" == "$USER_SCHEME" ]] \
        || fail "after \`set $USER_SCHEME\`, the person's own choice is recorded as '$(state chosen)'"

    # 2. The pinning theme is entered. This is the line the shell would run if
    #    the wiring existed; see the header.
    step "the pinning theme is entered" "$PINNED_SCHEME" pin "$PINNED_SCHEME" || true
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
    step "the theme is left" "$USER_SCHEME" unpin || true
    [[ "$(state scheme)" == "$USER_SCHEME" ]] \
        || fail "after \`unpin\`, what renders is '$(state scheme)' and not the person's '$USER_SCHEME'"

    [[ $problems -eq $before ]]
}

# ---------------------------------------------------------------------------
# And the same three steps against a script that gets it wrong
# ---------------------------------------------------------------------------
# A check nobody has watched fail is a check nobody knows the shape of. These
# two are the failures the design names by name -- one per direction of the
# trip -- and each one is a one-line edit to the copy in the sandbox, run
# through the identical `round_trip` above. If a mutant comes back green, the
# green above meant nothing and this file says so.
mutant() {
    local what=$1 script=$2 caught

    cp -a "$REPO/bin/.local/bin/desktop-scheme" "$SANDBOX_BIN/desktop-scheme"
    sed -i "$script" "$SANDBOX_BIN/desktop-scheme"
    cmp -s "$REPO/bin/.local/bin/desktop-scheme" "$SANDBOX_BIN/desktop-scheme" && {
        fail "[mutant: $what] the edit changed nothing, so this proves nothing.
        desktop-scheme has moved under it: sed script '$script' matched no line."
        return
    }

    # The mutant's own failures are noise, not findings: they are the point.
    local saved=$problems
    exec 3>&2 2>/dev/null
    if round_trip >/dev/null 2>&1; then caught=no; else caught=yes; fi
    exec 2>&3 3>&-
    problems=$saved

    if [[ "$caught" == yes ]]; then
        printf 'scheme-pinning:   %-34s caught\n' "mutant: $what"
    else
        fail "[mutant: $what] the round trip passed against a desktop-scheme that is broken.
        Whatever the three steps above are measuring, it is not this -- which is
        the case this whole check exists to rule out."
    fi

    cp -a "$REPO/bin/.local/bin/desktop-scheme" "$SANDBOX_BIN/desktop-scheme"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

printf 'scheme-pinning: theme-probe pins %s; the user picks %s\n' "$PINNED_SCHEME" "$USER_SCHEME"

assert_shell_still_cannot_pin
round_trip || true

# `unpin` goes back to what renders instead of to what the person chose. The
# state file and the render then BOTH stay on the pinned scheme, so only a
# check that reads one of them at the end catches it.
mutant "unpin forgets the user's choice" \
    's|set_scheme "\$(chosen)" chosen|set_scheme "$(current)" chosen|'

# `pin` records the name and never re-renders. Every state key reads correctly
# at every step and the desktop never changes colour at all -- the exact test
# that passes because nothing happened.
mutant "pinning renders nothing" \
    's|^    if "\$ws" reapply >/dev/null; then|    if true; then|'

if [[ -s "$breaches" ]]; then
    fail "notify-send was called $(wc -l < "$breaches") time(s) during this run.
        The stub caught them, so nothing reached a desktop -- but a check that
        can notify is one PATH change away from popping up on somebody's
        screen. What it tried to say:
$(sed 's/^/          /' "$breaches")"
fi

if [[ $problems -ne 0 ]]; then
    printf 'scheme-pinning: %d problem(s)\n' "$problems" >&2
    exit 1
fi

printf 'scheme-pinning: a pinned scheme renders, and leaving the theme gives the user theirs back\n'
