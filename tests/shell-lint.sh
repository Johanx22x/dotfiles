#!/usr/bin/env bash
# Run shellcheck over every shell script in the repo.
#
# (The first comment line does not start with the tool's name on purpose:
# `# shellcheck ...` at the top of a file is read as a directive, and an
# English sentence there is a parse error -- SC1072 -- which would fail this
# check on itself.)
#
# WHICH FILES. Whatever `git ls-files` reports, filtered by reading the first
# line: a shebang naming sh, bash, dash or ksh, or a .sh suffix. NOT a hand
# written list, which would go stale the first time a script is added, and NOT
# a name-based exclusion either -- bin/.local/bin/airpods-battery is python3
# with no extension to give it away, and shellcheck's answer to being pointed
# at it is SC1071, an error, which would fail this check for no reason. The
# shebang is the only thing that actually knows what a file is.
#
# AND THE .sh SUFFIX IS NOT A CONVENIENCE, so do not tidy it away on the
# grounds that the shebang rule below already covers everything. It does not.
# install.sh has a shebang and would survive; the twenty files under lib/ that
# are now the bulk of the installer do NOT have one, because they are sourced
# fragments and a fragment with a shebang invites somebody to execute it. Their
# first line is `# shellcheck shell=bash`, which tells shellcheck what dialect
# to read them in and tells this loop nothing whatsoever. Counted rather than
# guessed: of the 51 files in the net, 31 have a shebang and 20 are here on
# their suffix alone -- all of lib/, plus bin/.local/lib/desktop-lib.sh, which
# is sourced by nine scripts in bin/.local/bin/ for the same reason. Drop the
# suffix branch and the installer leaves the sweep without a word, the count
# reads 31, and the check still prints that it found nothing -- which is the
# failure mode this whole file exists to prevent.
#
# THE GATE IS AT -S warning, AND IT USED TO BE AT -S error. When this was
# written the tree had thirty findings at warning level across seven files and,
# read one by one, nearly all of them were shellcheck being unable to see
# through `readonly -A ARRAY=([key]=value)`: it reads the unquoted keys as
# variable references and reports SC2154 "referenced but not assigned" for each
# one. Gating on that would have meant a red check on day one over code that is
# correct, and a check that is red on arrival is a check everybody learns to
# scroll past -- at which point it is worse than not having one, because the
# next failure is red too and nobody looks.
#
# THAT SHAPE IS NOT IN THE TREE ANY MORE. Every associative array here is now
# `declare -A NAME=()`, and the one with literal keys quotes them, which the
# tool reads correctly: the probe is two lines, `readonly -A A=([one]=1)` still
# reports SC2154 today and `["one"]=1` does not. So the thirty are gone.
# Counted over the same file set this script lints, with the same arguments,
# under version 0.11.0:
#
#     -S error      0
#     -S warning    0
#     -S info      26
#     -S style     29
#
# Which is the only condition under which this raise was worth making: a gate
# moves up when the tree is already clean at the new level, never by silencing
# what is underneath it. Nothing was disabled to get here.
#
# INFO AND STYLE STAY OUT, and the two numbers above are the whole reason.
# Fifty-five findings printed on every run is the wall of text the paragraph
# before last is about, and neither level is where a bug lives. They are one
# flag away for anybody who wants an afternoon with them -- and the `$` is not
# decoration, a comment line whose first word is the tool's name is read as a
# directive and fails this check on itself, which is the same trap the note at
# the top of this file is about:
#
#     $ shellcheck -x -P SCRIPTDIR --severity=info $(git ls-files '*.sh')
#
# WHAT THE RAISE COSTS, said out loud because it is not nothing. A new release
# adding a warning-level check can turn this red on a pull request
# that touched none of the code being complained about, and the container in
# checks.yml installs whatever Arch has that morning. That is the price of
# warnings being visible at all rather than scrolled past, and the way out of
# one is fixing it or writing `# shellcheck disable=SCxxxx` with the reason
# next to it -- not moving the gate back down.
#
# Run it from anywhere:  tests/shell-lint.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

# --- How shellcheck is asked ------------------------------------------------
# -x FOLLOWS `source`, WHICH THIS TREE DOES A LOT OF. install.sh sources five
# files out of lib/, every unit under lib/units/ is sourced in turn, and nine
# scripts in bin/.local/bin/ source ../lib/desktop-lib.sh. Without -x each of
# those files is read as if the other end did not exist, so anything it defines
# elsewhere reads as undefined here -- and that is what the warning sweep below
# is printing for somebody to look at.
#
# -P SCRIPTDIR is the half that makes -x work at all. shellcheck resolves a
# sourced path relative to the working directory by default, and `source
# ../lib/desktop-lib.sh` inside bin/.local/bin/gs means relative to gs, not to
# the repository root. SCRIPTDIR says so.
#
# MEASURED, because "it follows sources now" is not by itself a reason:
#
#                      errors  warnings  SC1091 "not following"
#   plain                   0         0                      11
#   -x                      0         0                      11
#   -x -P SCRIPTDIR         0         0                       0
#
# So it changes nothing about whether this check passes today, and that is the
# point -- it is not smuggling in a new gate. What it buys is that the eleven
# notes are gone and the warning sweep is now saying something true about the
# other side of a `source`, which is the only reason the sweep is printed.
#
# NOT NAMED SHELLCHECK_OPTS. That is an environment variable shellcheck reads
# on its own, and a shell array by that name one export away from becoming a
# string is a trap for whoever edits this next.
SHELLCHECK_ARGS=(-x -P SCRIPTDIR --format=gcc)

# --- Collect the shell scripts ---------------------------------------------
scripts=()
while IFS= read -r file; do
    [[ -f $file ]] || continue
    case "$file" in
        *.sh|*.bash) scripts+=("$file"); continue ;;
    esac
    # `read` on a binary file would be noise, so only the first line is looked
    # at and only if it starts with the two bytes that make a shebang.
    IFS= read -r shebang < "$file" || continue
    [[ $shebang == '#!'* ]] || continue
    [[ $shebang =~ (^|/|[[:space:]])(sh|bash|dash|ksh)([[:space:]]|$) ]] && scripts+=("$file")
done < <(git ls-files)

if [[ ${#scripts[@]} -eq 0 ]]; then
    echo "shell-lint: found no shell scripts -- that cannot be right" >&2
    exit 2
fi

echo "shell-lint: ${#scripts[@]} shell script(s)"

# --- The gate: errors and warnings ------------------------------------------
# ONE SWEEP AND NOT TWO. There used to be an advisory pass at warning level
# above a gate at error level, printed so that somebody reading a pull request
# could see a new warning appear. With the gate at warning that pass is the
# same command as the gate, and a warning can no longer appear without being
# seen -- it fails the run.
echo
if shellcheck "${SHELLCHECK_ARGS[@]}" --severity=warning "${scripts[@]}"; then
    echo "shell-lint: no errors and no warnings"
else
    echo
    echo "shell-lint: the findings above are errors or warnings, not style." >&2
    echo "shell-lint: fix them, or disable the one that is wrong where it is wrong, with the reason next to it." >&2
    exit 1
fi
