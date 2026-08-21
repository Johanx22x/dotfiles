#!/usr/bin/env bash
# Every name in packages/ has to exist somewhere.
#
# These lists are what install.sh hands to pacman and to yay, and a package
# that has been renamed, dropped from the repositories or removed from the AUR
# does not fail politely there: it fails halfway through a fresh install, on a
# machine that has nothing on it yet, which is the one situation where being
# told early is worth the most.
#
# WHICH FILES. Every *.txt under packages/, found rather than listed, so that
# splitting them further -- required/, optional/, gpu/, compositor/ and
# whatever comes next -- needs no edit here. Comments and blank lines are
# dropped exactly as install.sh's read_list does.
#
# THE LISTS DO NOT SAY WHERE A NAME COMES FROM, and that is deliberate up
# there: install.sh works it out at install time by asking pacman first and
# treating everything left over as an AUR build. This check answers the same
# question the same way -- what the repositories know, then what the AUR
# knows -- so what it verifies is the split install.sh will actually make, not
# a second copy of it that can disagree.
#
# `pacman -Sl` AND NOT `pacman -Si`, for the reason install.sh gives at length:
# -Si's field labels are translated and -Sl's output is not. It is also one
# call for the whole index instead of one per name, which is the difference
# between a fifth of a second and twenty.
#
# MULTILIB HAS TO BE ENABLED wherever this runs. A disabled repository is
# missing from `pacman -Sl` in exactly the way a non-existent package is, so
# without it every lib32-* line -- and steam -- would be looked for in the AUR
# and reported as missing. The workflow enables it in the container.
#
# Needs a synced pacman database (`pacman -Sy`) and network for the AUR half.
# Run it from anywhere:  tests/package-lists.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUR_RPC="https://aur.archlinux.org/rpc/v5/info"

# --- Read the lists ---------------------------------------------------------
names=()
lists=0
while IFS= read -r -d '' list; do
    lists=$((lists + 1))
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -n $line ]] && names+=("$line")
    done < "$list"
done < <(find "$REPO/packages" -name '*.txt' -print0 | sort -z)

if [[ $lists -eq 0 || ${#names[@]} -eq 0 ]]; then
    echo "package-lists: found no package names under packages/ -- has the layout changed?" >&2
    exit 2
fi

# The same name can appear in two lists on purpose (a package that is required
# and also part of an optional set), and asking about it twice is only noise.
mapfile -t names < <(printf '%s\n' "${names[@]}" | sort -u)
echo "package-lists: $lists list(s), ${#names[@]} distinct name(s)"

# --- What the repositories know ---------------------------------------------
declare -A in_repo=()
while read -r _repo name _rest; do
    in_repo["$name"]=1
done < <(pacman -Sl 2>/dev/null)

# AN EMPTY DATABASE READS AS "NOTHING EXISTS ANYWHERE" and would send all two
# hundred names to the AUR, where most of them are not. install.sh guards the
# same hole for the same reason.
if [[ ${#in_repo[@]} -eq 0 ]]; then
    echo "package-lists: pacman knows of no packages at all -- run 'pacman -Sy' first" >&2
    exit 2
fi

candidates=()
repo_count=0
for name in "${names[@]}"; do
    if [[ -n ${in_repo[$name]:-} ]]; then
        repo_count=$((repo_count + 1))
    else
        candidates+=("$name")
    fi
done

echo "package-lists: $repo_count in the repositories, ${#candidates[@]} to look up in the AUR"

# --- What the AUR knows -----------------------------------------------------
failed=0
if [[ ${#candidates[@]} -gt 0 ]]; then
    query=""
    for name in "${candidates[@]}"; do query+="&arg[]=$name"; done

    if ! response="$(curl -fsS --max-time 30 "$AUR_RPC?${query#&}")"; then
        echo "package-lists: could not reach the AUR RPC" >&2
        exit 2
    fi

    # The RPC answers with an entry per package it knows and simply omits the
    # rest, so what is missing is the difference between what was asked for and
    # what came back. More useful than resultcount, which says how many and
    # never which.
    known="$(python3 -c '
import json, sys
data = json.load(sys.stdin)
if data.get("type") == "error":
    sys.exit(data.get("error", "the AUR RPC returned an error"))
print("\n".join(r["Name"] for r in data["results"]))
' <<<"$response")"

    for name in "${candidates[@]}"; do
        if grep -qxF "$name" <<<"$known"; then
            echo "package-lists: $name comes from the AUR"
        else
            echo "package-lists: FAIL $name is in neither the repositories nor the AUR" >&2
            failed=1
        fi
    done
fi

if [[ $failed -eq 0 ]]; then
    echo "package-lists: every name resolves"
fi
exit "$failed"
