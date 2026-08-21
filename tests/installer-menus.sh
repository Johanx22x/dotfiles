#!/usr/bin/env bash
# The two tick-box menus, driven by a keyboard that is not there.
#
# WHY THIS IS SEPARATE FROM tests/installer-run.sh. That one proves install.sh
# does the work; this one proves the thing that ASKS what work to do. They
# cannot be the same test, because they need opposite conditions: everything
# install.sh is driven with from a script arrives with no terminal on stdin,
# and every question in lib/ui.sh takes a documented default in that case --
# which is what makes an end-to-end run possible and also what makes it blind
# to every line of the menus. The interactive half of lib/ui.sh has never been
# executed by anything but a person, and one of its two implementations has
# never been executed at all.
#
# SO EVERYTHING BELOW RUNS UNDER A PSEUDO-TERMINAL. `script` gives the shell a
# real tty on stdin and stdout while the keystrokes come down a pipe, which is
# the only way to reach the branches behind `ui_has_tty` without a person. The
# answer is written to a FILE rather than read back off the pty: a terminal
# turns every newline into a carriage return and a newline, and comparing
# against output that has been through that is comparing against the terminal.
#
# WHAT IS SOURCED IS lib/ui.sh AND NOT install.sh, so each assertion is one
# function with arguments chosen here rather than whatever the menu happened to
# be showing. ASSUME_YES and DRY_RUN are set because ui.sh reads both and
# neither has a default of its own -- install.sh sets them before it sources
# anything, and a test that forgot would be exercising a different code path
# from the one that ships.
#
# THE gum PATH IS THE POINT OF ALL THIS. lib/ui.sh has two implementations of
# ui_multi_select and says so plainly: the plain one is what runs on the
# machine these dotfiles come from, and the gum one carries a comment reading
# "NOT TESTED, AND SAID SO PLAINLY" -- written against `gum choose`'s
# documented flags and never once run, because gum is not installed there. It
# is one package in extra, so here it is installed and run, and the four flags
# that comment names either work or this goes red.
#
# Run it from anywhere:  tests/installer-menus.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FAILURES=0
say()  { printf '\ninstaller-menus: == %s ==\n' "$*"; }
pass() { printf 'installer-menus:   ok    %s\n' "$*"; }
bad()  { printf 'installer-menus:   FAIL  %s\n' "$*" >&2; FAILURES=$(( FAILURES + 1 )); }
skip() { printf 'installer-menus:   skip  %s\n' "$*"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------------------
# HOW LONG TO WAIT BEFORE TYPING, in seconds, and zero for "immediately".
#
# It is zero for everything bash reads, because the terminal's line discipline
# buffers whatever arrives before `read` gets there and hands it over whole.
# gum is a different animal: it puts the terminal into raw mode itself, and a
# keystroke that arrives in the moment between the process starting and that
# switch is simply gone -- the menu then sits there with nothing left to read
# and waits for a person who does not exist. So the gum block below sets this,
# and pays a couple of seconds per assertion for it.
MENU_SETTLE=0

# menu <description> <keystrokes> <expected> <shell to run inside the pty>
#
# The keystrokes go through printf, so \n is Enter for anything bash reads and
# \e is Escape. gum wants \r instead: it reads a raw terminal, where the Enter
# key sends a carriage return and the line discipline is not there to turn it
# into a newline -- a bare \n reaches it as Ctrl+J, which it does not bind, and
# the menu never closes.
#
# The shell fragment is whatever should end up producing the answer on stdout.
# It runs inside a command substitution in the inner script, which is also what
# puts stderr -- where every one of these functions draws its menu -- on the
# pty instead of in the answer.
menu() {
    local what="$1" keys="$2" expected="$3" code="$4"
    local inner="$WORK/inner.sh" out="$WORK/answer.txt" got

    rm -f "$out"
    {
        # NOT `set -e`. Several of these functions answer with their exit
        # status on purpose -- ui_confirm's whole interface is 0 for yes -- and
        # a shell that exited on the first `no` would test only half of them.
        printf 'set -uo pipefail\n'
        printf 'ASSUME_YES=0\nDRY_RUN=0\n'
        printf 'source %q/lib/ui.sh\n'    "$REPO"
        printf 'source %q/lib/state.sh\n' "$REPO"
        printf 'answer="$( %s )"\n' "$code"
        printf 'printf "%%s" "$answer" > %q\n' "$out"
    } > "$inner"

    # UNDER A TIMEOUT, BECAUSE THE FAILURE MODE HERE IS A HANG AND NOT AN
    # ERROR. A menu waiting for a key that will never come would otherwise sit
    # there until the job's own limit ran out, six hours later, with no output
    # saying which assertion it was. Thirty seconds is far more than any of
    # these needs and still turns the worst case into a line of text.
    #
    # TERM matters as well: gum draws nothing useful on a dumb terminal, and
    # the point of the pty is to be a terminal gum will actually talk to.
    if ! { sleep "$MENU_SETTLE"; printf '%b' "$keys"; sleep "$MENU_SETTLE"; } |
         TERM=xterm-256color timeout 30 script -qec "bash $inner" /dev/null \
             >/dev/null 2>&1; then
        bad "$what (the menu never came back)"
        return
    fi

    got="$(cat "$out" 2>/dev/null)"
    if [[ $got == "$expected" ]]; then
        pass "$what"
    else
        bad "$what"
        printf 'installer-menus:         expected: %q\n' "$expected" >&2
        printf 'installer-menus:         got:      %q\n' "$got" >&2
    fi
}

# ---------------------------------------------------------------------------
say "there really is a terminal in here"

# If this one is wrong then every other line in this file is exercising the
# no-tty fallback by accident and passing for the wrong reason, so it is asked
# first and asked directly.
menu "ui_has_tty is true under the pseudo-terminal" '' 'yes' \
     'ui_has_tty && echo yes || echo no'

# ---------------------------------------------------------------------------
say "the plain menu -- the one that ships"

# A bare Enter accepts what is on screen. That is the common answer on a first
# run, where the boxes arrive already ticked, and it is what the whole "typing
# a number toggles, it does not select" decision is built around.
menu "Enter alone keeps the boxes as they were" \
     '\n' 'alpha' \
     'ui_multi_select_plain header alpha alpha beta gamma'

# A number toggles rather than selects: 3 adds gamma and leaves alpha alone.
menu "a number toggles one box and leaves the rest" \
     '3\n\n' $'alpha\ngamma' \
     'ui_multi_select_plain header alpha alpha beta gamma'

# The same number twice comes back to where it started, which is what makes
# "toggle" the right word for it.
menu "the same number twice is a no-op" \
     '2 2\n\n' 'alpha' \
     'ui_multi_select_plain header alpha alpha beta gamma'

menu "a is all of them" \
     'a\n\n' $'alpha\nbeta\ngamma' \
     'ui_multi_select_plain header alpha alpha beta gamma'

menu "n is none of them" \
     'n\n\n' '' \
     'ui_multi_select_plain header alpha alpha beta gamma'

# Ranges exist because a dozen entries is enough that "2 5 7-9" is worth
# having. Starting from nothing ticked, so the range is the only thing acting.
menu "a range toggles everything in it" \
     '1-3\n\n' $'alpha\nbeta\ngamma' \
     'ui_multi_select_plain header "" alpha beta gamma'

# Nonsense is complained about and the menu is still there afterwards, rather
# than being taken as an answer or ending the run.
menu "something that is not a number is refused, not obeyed" \
     'wat\n\n' 'alpha' \
     'ui_multi_select_plain header alpha alpha beta gamma'

menu "a number out of range is refused, not obeyed" \
     '9\n\n' 'alpha' \
     'ui_multi_select_plain header alpha alpha beta gamma'

# EVERY LABEL THE INSTALLER BUILDS HAS SPACES IN IT, because they are all
# `printf '%-14s %s'` of an id and a title. The starting boxes are matched
# whole-line for exactly that reason, and a comparison that split on
# whitespace would tick nothing at all here.
menu "a label with spaces in it is matched whole" \
     '\n' 'packages       Packages' \
     'ui_multi_select_plain header "packages       Packages" "packages       Packages" "symlinks       Symlinks"'

# ---------------------------------------------------------------------------
say "one of many, which is how the compositor gets chosen"

menu "typing a number picks that one" \
     '2\n' 'niri' \
     'ui_choose_one 1 hyprland niri both'

menu "Enter alone takes the default" \
     '\n' 'hyprland' \
     'ui_choose_one 1 hyprland niri both'

# THREE TRIES AND THEN THE DEFAULT. What this replaced was an unbounded `while
# read`, which against a stdin that answers nothing is a script that can never
# finish -- so the bound is the fix, and this is the only thing that shows it
# working.
menu "three wrong answers fall back to the default rather than looping" \
     'x\ny\nz\n' 'hyprland' \
     'ui_choose_one 1 hyprland niri both'

# ---------------------------------------------------------------------------
say "the gum menu -- the one that had never run"

if ! command -v gum >/dev/null; then
    skip "gum is not installed here, so the second implementation stays untested"
else
    # THE FOUR FLAGS THE COMMENT IN lib/ui.sh NAMES: --no-limit for tick boxes
    # rather than a single choice, --selected for the boxes that start ticked,
    # --output-delimiter so the answer comes back one per line instead of
    # joined by a comma, and `--` so a label starting with a dash could not be
    # read as a flag. If any of them has been renamed or dropped, gum exits
    # non-zero and the function falls back to the preselection -- which is why
    # the assertions below use preselections that are not the whole list, so a
    # fallback cannot be mistaken for a working menu.
    MENU_SETTLE=2

    menu "Enter alone returns the boxes that started ticked" \
         '\r' 'alpha' \
         'ui_multi_select_gum header alpha alpha beta gamma'

    menu "two preselected boxes come back one per line" \
         '\r' $'alpha\ngamma' \
         'ui_multi_select_gum header alpha,gamma alpha beta gamma'

    # Escape cancels, gum exits non-zero, and the documented answer to that is
    # "leave the boxes alone" -- the same answer an empty line gets from the
    # plain menu.
    menu "Escape leaves the boxes as they were" \
         '\e' 'alpha' \
         'ui_multi_select_gum header alpha alpha beta gamma'

    MENU_SETTLE=0
fi

# ---------------------------------------------------------------------------
say "yes and no"

# ui_confirm answers with its exit status and prints its prompt, so the prompt
# is sent away and the status is what gets turned into a word.
menu "an empty answer takes the no default" '\n' 'no' \
     'ui_confirm "well?" n >/dev/null 2>&1 && echo yes || echo no'
menu "an empty answer takes the yes default" '\n' 'yes' \
     'ui_confirm "well?" y >/dev/null 2>&1 && echo yes || echo no'
menu "y is yes" 'y\n' 'yes' \
     'ui_confirm "well?" n >/dev/null 2>&1 && echo yes || echo no'
menu "n is no" 'n\n' 'no' \
     'ui_confirm "well?" y >/dev/null 2>&1 && echo yes || echo no'

# --yes answers without reading anything, which is what makes any of this
# scriptable in the first place.
menu "--yes says yes without reading anything" '' 'yes' \
     'ASSUME_YES=1; ui_confirm "well?" n >/dev/null 2>&1 && echo yes || echo no'

# ---------------------------------------------------------------------------
say "--yes does not turn an offer into a loop"

# THE ONE CASE HERE THAT SOURCES install.sh, because what it is about is a loop
# in that file rather than a function in lib/ui.sh. tui_optional ends by
# offering to open a group and pick packages one at a time, and the offer is a
# `while ui_confirm ...` -- which under ASSUME_YES returns 0 without reading
# anything, so the answer can never be no and the loop can never end. Measured
# before it was fixed, on a pty with --yes and only Enter arriving: 1,864
# openings in fifteen seconds, and no way out of it but ^C.
#
# WHAT IS ASSERTED IS THAT IT COMES BACK AT ALL, which is why this is shaped
# differently from everything above: the failure is a hang, so the evidence is a
# file that only gets written after tui_optional returns.
#
# `check` is the mode install.sh is sourced with because it is the one that
# writes nothing -- what is wanted is the function definitions, and the mode has
# to be something. HOME and the XDG variables point into the scratch directory
# so the profile it reads is the one written here.
#
# ui_have_gum is turned off on purpose. gum has its own assertions above; here
# it would sit in raw mode waiting for the keypress this case is specifically
# about not needing.
loop_home="$WORK/home"
mkdir -p "$loop_home/.local/state"
printf 'group.apps\t1\nunit.optional\t1\n' > "$loop_home/.local/state/dotfiles-profile"

loop_inner="$WORK/loop.sh"
loop_done="$WORK/loop-returned"
{
    printf 'set -uo pipefail\n'
    printf 'export HOME=%q\n' "$loop_home"
    printf 'export XDG_CONFIG_HOME=%q\n' "$loop_home/.config"
    printf 'export XDG_STATE_HOME=%q\n'  "$loop_home/.local/state"
    printf 'export XDG_DATA_HOME=%q\n'   "$loop_home/.local/share"
    printf 'export XDG_CACHE_HOME=%q\n'  "$loop_home/.cache"
    printf 'source %q check >/dev/null 2>&1 || true\n' "$REPO/install.sh"
    printf 'ui_have_gum() { return 1; }\n'
    printf 'ASSUME_YES=1\n'
    printf 'state_load\n'
    printf 'tui_optional >/dev/null 2>&1\n'
    printf 'printf returned > %q\n' "$loop_done"
} > "$loop_inner"

rm -f "$loop_done"
# One Enter, which is all the groups menu needs, and then nothing. Twenty
# seconds is a hundred times what this takes when it works.
printf '\n' | TERM=xterm-256color timeout 20 script -qec "bash $loop_inner" /dev/null \
    >/dev/null 2>&1 || true

if [[ -f $loop_done ]]; then
    pass "tui_optional under --yes comes back instead of asking forever"
else
    bad "tui_optional under --yes comes back instead of asking forever"
fi

# ---------------------------------------------------------------------------
if (( FAILURES )); then
    printf '\ninstaller-menus: %d assertion(s) failed\n' "$FAILURES" >&2
    exit 1
fi
echo
echo "installer-menus: both menus answer a keyboard the way they say they do"
