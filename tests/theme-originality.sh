#!/usr/bin/env bash
# A THEME'S FILES MUST NOT BE ANOTHER THEME'S FILES.
#
# WHY THIS EXISTS. The Windows theme was first built with `cp -r genesis
# windows` and then rewritten one group of files at a time. What shipped was a
# theme where three files were still byte-identical to genesis's and on screen
# -- the clipboard picker, the notification history, the do-not-disturb
# indicator -- and where a fourth had had its COMMENT rewritten to describe
# Windows behaviour while its drawing still did genesis's. Johan looked at the
# result and called it a cheap adaptation, which it was, and the whole theme
# was deleted and started again.
#
# Nothing in tests/ noticed. theme-interface.py asks whether the file EXISTS.
# qml-lint.sh asks whether it PARSES. shell-load.sh asks whether it LOADS. All
# three are green over a file that is a copy, because a copy exists, parses and
# loads perfectly.
#
# So this asks the one question none of them asks: is it the same file?
#
# WHAT IT WILL NOT CATCH, said plainly so nobody trusts it further than it
# goes. A copy with one colour changed is not byte-identical and passes here.
# This is a floor, not a proof of originality -- it catches the thing that
# actually happened, which is a file that was never opened at all.
#
# THE LINE FLOOR IS NOT ARBITRARY. Two themes may legitimately share a file:
# the empty implementation of a component a theme genuinely has nothing to
# draw for is five lines plus a comment saying why, and two themes arriving at
# the same five lines is agreement rather than copying. Above the floor, a
# hundred lines of identical drawing is not agreement.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

# Files shorter than this may match another theme's. See the note above.
FLOOR=25

failed=0
note() { echo "theme-originality: $*"; }
fail() { echo "theme-originality: FAIL $*" >&2; failed=1; }

# THROUGH `git ls-files`, for the reason tests/qml-lint.sh records: a theme is a
# directory with a COMMITTED manifest.json, and a worktree left lying around
# under the checkout is a whole second copy of the repository that `find` would
# walk into and report every file of.
themes=()
while IFS= read -r manifest; do
    themes+=("${manifest%/*}")
done < <(git ls-files -- '*manifest.json' | sort)

if (( ${#themes[@]} < 2 )); then
    note "${#themes[@]} theme(s) -- nothing to compare"
    exit 0
fi

# The same floor every other check here has: an assertion over an empty set is
# not an assertion. Two themes with no .qml between them would pass this in
# exactly the way two themes with no duplicates do.
total=0
for theme in "${themes[@]}"; do
    n="$(git ls-files -- "$theme" | grep -c '\.qml$' || true)"
    total=$(( total + n ))
done
if (( total < 40 )); then
    echo "theme-originality: only $total .qml across ${#themes[@]} theme(s)" >&2
    echo "theme-originality: that is far below the tree this is written against" >&2
    exit 1
fi

# Compare every theme against every other, once each way round.
compared=0
duplicates=()
for (( i = 0; i < ${#themes[@]}; i++ )); do
    for (( j = i + 1; j < ${#themes[@]}; j++ )); do
        a="${themes[i]}"
        b="${themes[j]}"

        while IFS= read -r rel; do
            [[ -f "$a/$rel" && -f "$b/$rel" ]] || continue
            compared=$(( compared + 1 ))
            cmp -s "$a/$rel" "$b/$rel" || continue

            lines="$(wc -l < "$a/$rel")"
            (( lines < FLOOR )) && continue

            duplicates+=("$rel -- ${a##*/} and ${b##*/} are the same $lines lines")
        done < <(
            {
                git ls-files -- "$a" | sed "s|^$a/||"
                git ls-files -- "$b" | sed "s|^$b/||"
            } | grep '\.qml$' | sort -u
        )
    done
done

if (( ${#duplicates[@]} > 0 )); then
    fail "${#duplicates[@]} file(s) are shared verbatim between two themes"
    printf 'theme-originality:   %s\n' "${duplicates[@]}" >&2
    echo "theme-originality: a theme that has not opened a file has not drawn it" >&2
    echo "theme-originality: below $FLOOR lines a match is agreement, above it is a copy" >&2
fi

if (( failed == 0 )); then
    note "${#themes[@]} theme(s), $compared file pair(s) compared, none shared verbatim"
fi

exit "$failed"
