#!/usr/bin/env bash
# The rules about the QML tree that loading it cannot answer.
#
# tests/shell-load.sh next door starts a compositor and asks whether the whole
# shell comes up. That catches everything that stops the tree loading and
# everything that leaves a name unresolved -- but a component can load
# perfectly, resolve every name, and still do nothing at all. This file is for
# the handful of cases where "does nothing at all" is spelled the same way as
# "is configured correctly", and the only way to tell is to read the source.
#
# ONE RULE SO FAR, and it is here because it cost hours.
#
# A `WheelHandler` MUST DECLARE `acceptedDevices`. Qt's default is
# `PointerDevice.Mouse`, and a handler that declines an event is a handler that
# does nothing -- silently, with no warning, no error and no log line. The
# Wayland seat on this desktop delivers wheel events typed as `TouchPad`, so a
# WheelHandler left at its default is dead code on the machine these dotfiles
# are for, while reading exactly like working code in the diff.
#
# That is not hypothetical. Pull request #144 shipped a WheelHandler with no
# `acceptedDevices` and was believed to have fixed scrolling for hours before
# anybody noticed it had changed nothing; the fix was one line, and the reason
# it took so long to find is that there was nothing anywhere -- not a test, not
# a warning, not a message -- that could tell a live handler from a dead one.
# This grep can. It is one line of shell against two call sites and it would
# have answered in the time it takes to run shellcheck.
#
# It says nothing about WHICH devices are right, only that the file made a
# decision. `Mouse` alone is a legitimate answer for a handler that genuinely
# only wants a mouse; the default is not an answer, it is the absence of one.
#
# What this file is NOT is a QML linter. There is a long note in
# .github/workflows/checks.yml about why qmllint is not here: the Qt 5 one
# exits 255 in silence on most of these files, and the Qt 6 one cannot resolve
# Quickshell's `root:/` imports and buries every file under a hundred messages
# about types it cannot find. Adding rules here is cheap and each one has to
# earn its place by naming the bug it would have caught. A rule with no such
# story does not belong.
#
# Run it from anywhere:  tests/qml-rules.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QML_DIR="$REPO/quickshell/.config/quickshell"

failed=0
note() { echo "qml-rules: $*"; }
fail() { echo "qml-rules: FAIL $*" >&2; failed=1; }

qml_files=()
while IFS= read -r -d '' file; do qml_files+=("$file"); done \
    < <(find "$QML_DIR" -name '*.qml' -type f -print0 | sort -z)

# The same floor every other check here has: an assertion over an empty set is
# not an assertion, and a rule that matches nothing because the tree moved
# would otherwise pass in exactly the way a rule that matches nothing because
# the code is correct does.
if (( ${#qml_files[@]} < 50 )); then
    echo "qml-rules: found only ${#qml_files[@]} .qml under ${QML_DIR#"$REPO"/}" >&2
    echo "qml-rules: that is far below the tree these rules are written against" >&2
    exit 1
fi

# --- every WheelHandler declares acceptedDevices -----------------------------
#
# Brace counting rather than a fixed window, because a WheelHandler's body runs
# to whatever length its onWheel needs and the property may be anywhere in it.
# Counting starts on the `WheelHandler {` line and the block ends when the
# depth returns to zero.
handlers=0
missing=()
for file in "${qml_files[@]}"; do
    while IFS= read -r finding; do
        case $finding in
            found) handlers=$(( handlers + 1 )) ;;
            missing:*) handlers=$(( handlers + 1 ))
                       missing+=("${file#"$REPO"/}:${finding#missing:}") ;;
        esac
    done < <(awk '
        # COMMENTS COME OFF FIRST, and this is not a nicety. The first version
        # of this rule matched the raw file and passed on a ScrollList.qml
        # whose acceptedDevices had been deleted, because the paragraph above
        # the property explains what `acceptedDevices: Mouse` means and the
        # grep could not tell the explanation from the code. A rule that reads
        # its own documentation as evidence cannot fail, which is the whole
        # class of bug this suite has just been through.
        {
            line = $0
            if (inblock) {
                if (match(line, /\*\//)) {
                    line = substr(line, RSTART + RLENGTH); inblock = 0
                } else next
            }
            while (match(line, /\/\*/)) {
                head = substr(line, 1, RSTART - 1)
                rest = substr(line, RSTART + 2)
                if (match(rest, /\*\//)) {
                    line = head substr(rest, RSTART + RLENGTH)
                } else { line = head; inblock = 1; break }
            }
            sub(/\/\/.*$/, "", line)
            $0 = line
        }
        /(^|[^A-Za-z0-9_])WheelHandler[[:space:]]*\{/ && depth == 0 {
            depth = 0; start = NR; declared = 0
        }
        start {
            if ($0 ~ /acceptedDevices[[:space:]]*:/) declared = 1
            n = gsub(/\{/, "{"); depth += n
            n = gsub(/\}/, "}"); depth -= n
            if (depth <= 0) {
                print (declared ? "found" : "missing:" start)
                start = 0; depth = 0
            }
        }
    ' "$file")
done

if (( handlers == 0 )); then
    fail "found no WheelHandler in ${QML_DIR#"$REPO"/} -- has the rule outlived its subject?"
elif (( ${#missing[@]} > 0 )); then
    fail "${#missing[@]} WheelHandler(s) leave acceptedDevices at Qt's default:"
    printf 'qml-rules:   %s\n' "${missing[@]}" >&2
    echo "qml-rules: the default is PointerDevice.Mouse, and this seat reports TouchPad" >&2
else
    note "all $handlers WheelHandler(s) declare acceptedDevices"
fi

if [[ $failed -eq 0 ]]; then
    note "the QML tree keeps to its rules"
fi
exit "$failed"
