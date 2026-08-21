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
# WHY THE GATE IS AT -S error AND NOT -S warning. At the time this was written
# the tree had thirty findings at warning level across seven files and, read
# one by one, nearly all of them are shellcheck being unable to see through
# `readonly -A ARRAY=([key]=value)`: it reads the keys as variable references
# and reports SC2154 "referenced but not assigned" for each one. Gating on that
# would mean a red check on day one over code that is correct, and a check that
# is red on arrival is a check everybody learns to scroll past -- at which point
# it is worse than not having one, because the next failure is red too and
# nobody looks.
#
# So: errors gate, warnings are printed but do not. The warning sweep is still
# run and still shown, because the point of printing it is that somebody
# reading a pull request can see a new one appear.
#
# Run it from anywhere:  tests/shell-lint.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

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

# --- Advisory: everything at warning level ---------------------------------
# `|| true` because shellcheck exits non-zero whenever it has something to say,
# and here it is allowed to have something to say.
warnings="$(shellcheck --severity=warning --format=gcc "${scripts[@]}" || true)"
if [[ -n $warnings ]]; then
    echo
    echo "shell-lint: warnings (not gating, see the header of this script):"
    sed 's/^/  /' <<<"$warnings"
fi

# --- The gate: errors only --------------------------------------------------
echo
if shellcheck --severity=error --format=gcc "${scripts[@]}"; then
    echo "shell-lint: no errors"
else
    echo
    echo "shell-lint: the findings above are errors, not style. Fix them." >&2
    exit 1
fi
