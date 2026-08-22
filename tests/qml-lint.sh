#!/usr/bin/env bash
# Run Qt 6's qmllint over the whole Quickshell tree, and hold the count.
#
# WHY THIS COULD NOT EXIST UNTIL NOW, which is most of what is worth knowing
# about it. Every file in quickshell/ used to reach its neighbours through
# Quickshell's own `root:/` URL scheme, and `root:/` is resolved inside the
# running shell by a QNetworkAccessManager nothing else has. qmllint could not
# follow a single one of those imports, so it could not find a single type
# behind them: sweeping the tree produced 4,074 warnings, 3,039 of them
# `[unqualified]`, and every one of those 3,039 was qmllint failing to resolve
# an import rather than the code being wrong. A check drowning in noise it
# generated itself is worse than no check, and that is why the long note in
# .github/workflows/checks.yml said there was no linter here.
#
# The tree now imports by module name -- `import qs.components` -- which is the
# same directories under the name Quickshell registers them as. qmllint can
# follow that, given a qmldir per directory. The same sweep is now 307.
#
# WHERE THE qmldir FILES COME FROM, AND WHY THEY ARE NOT IN THE REPOSITORY.
# Quickshell synthesizes one per directory at startup -- it scans each file for
# `pragma Singleton` and writes the module line and the type list itself -- and
# it explicitly DISABLES that synthesis for any directory where it finds a real
# qmldir on disk ("Found qmldir file, qmldir synthesization will be disabled for
# directory"). So a committed qmldir would not be a description of the tree, it
# would be a second place every new component has to be registered, and the
# first one anybody forgot would be a type that resolves in the editor and is
# gone at runtime. There is nothing to keep in sync here because there is
# nothing on disk to go stale: this script builds the qmldirs into a temporary
# copy of the tree, lints that, and deletes it.
#
# THE RULE BELOW IS QUICKSHELL'S OWN RULE, and it was checked rather than
# assumed. Quickshell was pointed at this tree with a `.qmlls.ini` in it, which
# makes it write its synthesized qmldirs out to a real directory for qmlls to
# read; the 16 files generated here were compared against the 16 it wrote, and
# they agree line for line. The first attempt did NOT: it looked for `pragma
# Singleton` at the start of the file and found it in none of them, because
# every file in this tree opens with a licence header. That version would have
# declared all 31 singletons as ordinary types and been quietly wrong about the
# whole tree, so the comparison is the only reason this is right.
#
# THE QMLLINT THAT ANSWERS. /usr/lib/qt6/bin/qmllint, and never /usr/bin/qmllint
# -- the latter is Qt 5, from qt5-declarative, and it exits 255 printing NOTHING
# on any file using a `: var` return type, which is most of this tree: measured
# over the whole of it, 49 files passed and 76 exited non-zero with no output at
# all. A green run from it would mean nothing whatsoever and a red one would say
# nothing at all.
#
# ---------------------------------------------------------------------------
# WHAT THIS DOES NOT CATCH. Read this before reading a green tick as coverage.
#
# NEITHER OF THE TWO REGRESSIONS THAT REACHED THE DESKTOP THIS WEEK WOULD HAVE
# TURNED IT RED, and that is measured here rather than supposed. Reverting
# 279c1d3 -- the launcher fix, where a scrollbar's grab margin ate eleven pixels
# off every third-column row, so a click launched nothing -- and sweeping the
# tree again gives 307 warnings. The fixed tree gives 307. The same number, from
# the same files, with the bug in and with the bug out.
#
# That is not a gap to be closed by adding rules. A linter reads types and
# names; both of that week's faults were correct QML doing the wrong thing on
# screen, and no count of unresolved identifiers can see a margin that is seven
# where it should be three. tests/shell-load.sh says the same about itself and
# tests/wheel-and-click.py is the shape of the answer: a bench per component,
# driving the real thing and measuring what came out.
#
# WHAT IT DOES CATCH is a different class and a much larger one, over a body of
# code where nothing has ever looked: names that resolve to nothing, members
# that do not exist on the type they are read from, imports nothing uses, and
# duplicated bindings. On its first run it found a second `Behavior on color` on
# the same ClippingRectangle in themes/genesis/island/Island.qml, and fifteen
# imports no file used. Both are fixed, which is why those two lines read 0
# below.
# ---------------------------------------------------------------------------
#
# THE BASELINE, AND WHY IT IS NOT ZERO. The tree measured 326 the first time a
# linter could read it; 19 of those were cheap and are gone, so it is 307.
# Gating at zero would mean gating at a number nobody can reach today, so this
# gates at what is there and refuses to let it grow. The table below is the
# whole of it, and the shape matters more than the total:
#
#   246  unqualified                243 of them are one thing -- a delegate
#                                   naming an id from the component outside it,
#                                   which qmllint answers with "set pragma
#                                   ComponentBehavior: Bound". That pragma is a
#                                   REAL CHANGE IN BEHAVIOUR, not an annotation:
#                                   it rebinds how delegates capture their
#                                   context, and on a tree this size the only
#                                   thing that would verify it is a shell that
#                                   loads, which is exactly the evidence that
#                                   cannot tell a bound delegate from a broken
#                                   one. It is left alone deliberately. The
#                                   other 3 are ordinary unqualified reads, in
#                                   files where fixing them was a one-word
#                                   change; Compositor.qml's three are gone.
#    19  missing-property           reads through a `var`, and PathView
#                                   attached properties declared by
#                                   PathAttribute, which qmllint cannot see.
#                                   Checked one by one; none is a bug.
#    17  signal-handler-parameters  every one is QProcess::ExitStatus on an
#                                   onExited handler. Quickshell exposes a Qt
#                                   private enum there; nothing in this
#                                   repository can fix it.
#    14  unresolved-type            Quickshell C++ types not exposed
#                                   declaratively: Toplevel, UntypedObjectModel,
#                                   FileViewAdapter, DBusMenuHandle. Not ours.
#     9  uncreatable-type           "PanelWindow is not creatable", which is
#                                   false -- the whole shell is PanelWindows. An
#                                   artefact of how Quickshell registers it.
#     1  incompatible-type          Loader.item assigned to a typed property.
#     1  redundant-optional-chaining `?.` on a QVariantMap, in the Hyprland
#                                   backend. LEFT ALONE ON PURPOSE, and it is
#                                   the clearest example of where cheap stops:
#                                   the edit is one character, but the only
#                                   check that could confirm it runs under
#                                   labwc, where there is no Hyprland and that
#                                   branch is never reached. A one-character fix
#                                   nothing can verify is not cheap.
#     0  unused-imports             were 15, all removed.
#     0  duplicate-property-binding was the Island finding above.
#
# So 60 of the 307 -- signal-handler-parameters, unresolved-type,
# uncreatable-type -- are Quickshell's type information rather than this
# repository's code, and no change here can move them. They are counted anyway,
# because a baseline that quietly excludes things is a baseline nobody can
# reproduce with a single command.
#
# WHEN THIS GOES RED WITHOUT ANYBODY BREAKING ANYTHING: a qt6-declarative
# update. CI runs archlinux:base-devel, which is rolling, so the version that
# produced these numbers is printed on every run -- if the count moves and the
# diff touched no QML, look there first.
#
# Run it from anywhere:  tests/qml-lint.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO/quickshell/.config/quickshell"

# NOT `qmllint` off the PATH. See the note above: that is Qt 5 here, and it
# fails in silence rather than failing loudly.
QMLLINT=/usr/lib/qt6/bin/qmllint

# What the tree measured at when a linter could first read it, by category.
# Lower a number when a change earns it; the run says so when one drops.
# Zero entries are kept rather than deleted: the category is spelled out so a
# new one is reported against a number this file states, instead of appearing
# from nowhere and being compared against an implicit zero nobody wrote down.
declare -A BASELINE=(
    [unqualified]=246
    [missing-property]=19
    [signal-handler-parameters]=17
    [unresolved-type]=14
    [uncreatable-type]=9
    [incompatible-type]=1
    [redundant-optional-chaining]=1
    [unused-imports]=0
    [duplicate-property-binding]=0
)

failed=0
note() { echo "qml-lint: $*"; }
fail() { echo "qml-lint: FAIL $*" >&2; failed=1; }

[[ -x $QMLLINT ]] || {
    echo "qml-lint: $QMLLINT is missing -- pacman -S qt6-declarative" >&2
    exit 1
}

[[ -f $SHELL_DIR/shell.qml ]] || {
    echo "qml-lint: $SHELL_DIR/shell.qml is missing -- has the layout changed?" >&2
    exit 1
}

# The same floor every other check here has: an assertion over an empty set is
# not an assertion, and a sweep that found nothing because the tree moved would
# otherwise read exactly like a sweep that found nothing because it is clean.
qml_count="$(find "$SHELL_DIR" -name '*.qml' -type f | wc -l)"
if (( qml_count < 50 )); then
    echo "qml-lint: found only $qml_count .qml under ${SHELL_DIR#"$REPO"/}" >&2
    echo "qml-lint: that is far below the tree this is meant to sweep" >&2
    exit 1
fi

note "$("$QMLLINT" --version)"

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

# The copy is what gets the qmldirs, so the repository never does. `qs` is the
# directory name and not a decoration: it is the module Quickshell registers
# the config root as, so `import qs.components` has to resolve to <root>/qs/
# components/qmldir for qmllint the same way it does for the shell.
root="$sandbox/qs"
cp -r "$SHELL_DIR" "$root"

# --- the qmldirs -------------------------------------------------------------
#
# Quickshell's rule, checked against Quickshell's own output: every .qml in the
# directory is a type of the same name at version 1.0, prefixed `singleton` when
# the file carries `pragma Singleton` ANYWHERE -- not at the top, which is where
# it is not, every file here opening with a licence header instead.
#
# shell.qml is left out of the root module, which is what Quickshell does too:
# it is the entry point rather than a type anything imports.
while IFS= read -r dir; do
    files=("$dir"/*.qml)
    [[ -e ${files[0]} ]] || continue

    rel="${dir#"$root"}"
    rel="${rel#/}"
    if [[ -z $rel ]]; then module="qs"; else module="qs.${rel//\//.}"; fi

    {
        echo "module $module"
        for file in "${files[@]}"; do
            name="$(basename "$file" .qml)"
            [[ $dir == "$root" && $name == shell ]] && continue
            grep -q '^pragma Singleton' "$file" && printf 'singleton '
            printf '%s 1.0 %s.qml\n' "$name" "$name"
        done
    } > "$dir/qmldir"
done < <(find "$root" -type d | sort)

modules="$(find "$root" -name qmldir | wc -l)"
note "$qml_count file(s) in $modules module(s)"

# --- the sweep ---------------------------------------------------------------
#
# -I twice: the sandbox, so `qs.*` resolves to the copy, and Qt's own module
# directory, so QtQuick and Quickshell do. Paths come out relative to the copy;
# the sed puts the repository's own back, because a warning naming a file under
# /tmp that no longer exists is a warning nobody can act on.
report="$sandbox/qmllint.txt"
(
    cd "$root"
    find . -name '*.qml' -type f | sort \
        | xargs "$QMLLINT" -I "$sandbox" -I /usr/lib/qt6/qml
) > "$report" 2>&1 || true
# `#` as the delimiter and not `|`, which is the alternation here: with `|`
# delimiting the expression, `\|` reads as an escaped delimiter and the branch
# never matches -- the paths came out unrewritten and the sed reported success.
sed -Ei "s#^(Warning|Info|Error|Critical): \./#\1: ${SHELL_DIR#"$REPO"/}/#" "$report"

# Anchored at the end of the line, which is not fussiness. qmllint echoes the
# offending source under each message, and a delegate reading `root.list[index]`
# puts `[index]` at the end of an echoed line that is not a finding at all --
# counted loosely, that one line invented a whole category.
mapfile -t found < <(grep -oP '^(?:Warning|Info|Error|Critical):.*\[\K[a-z-]+(?=\]$)' \
                          "$report" | sort | uniq -c | awk '{print $2" "$1}')

declare -A counts=()
for entry in "${found[@]}"; do counts["${entry%% *}"]="${entry##* }"; done

total=0
for category in "${!counts[@]}"; do total=$(( total + counts[$category] )); done

# Errors are not warnings. qmllint reports a file it cannot parse at all this
# way, and no baseline should be able to absorb one.
if grep -q '^Error:' "$report"; then
    fail "qmllint reported errors, not just warnings:"
    errors="$(grep '^Error:' "$report" || true)"
    printf '%s\n' "$errors" | head -n 10 >&2 || true
fi

# Every category in either table, so one that appears from nowhere is named
# rather than silently added to a total.
for category in $(printf '%s\n' "${!counts[@]}" "${!BASELINE[@]}" | sort -u); do
    now="${counts[$category]:-0}"
    was="${BASELINE[$category]:-0}"
    if (( now > was )); then
        fail "[$category] $was -> $now"
        # THE FIRST FEW IN THE CATEGORY, which is not the same as the new ones:
        # nothing here knows which of 249 unqualified reads arrived with this
        # branch. They are printed to say what the category looks like; the diff
        # is what says which ones are yours.
        # Into a variable and not through `| head`: head closes the pipe on the
        # tenth line, grep takes SIGPIPE, and under `set -o pipefail` that 141
        # becomes the exit status of the whole check -- which is a failure, but
        # not the one being reported, and not one `exit "$failed"` chose.
        examples="$(grep -P "\[$category\]$" "$report" || true)"
        printf '%s\n' "$examples" | head -n 10 >&2 || true
    elif (( now < was )); then
        # Not a failure, and deliberately so: a branch that improves the tree
        # should not have to argue with a test. It does have to record it,
        # because a baseline nobody lowers stops being a baseline.
        note "[$category] $was -> $now -- lower the baseline in this file"
    fi
done

if [[ $failed -eq 0 ]]; then
    note "$total warning(s), none of them new"
fi
exit "$failed"
