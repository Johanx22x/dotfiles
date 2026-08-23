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
# What this file is NOT is a QML linter. tests/qml-lint.sh next door is that,
# and it exists now that the tree imports by module name rather than through
# Quickshell's `root:/` scheme -- which is what qmllint could not resolve, and
# what used to bury every file under a hundred messages about types it could not
# find. The two do not overlap: qmllint answers about names and types, and this
# file is for faults that are correct QML by every rule a linter knows. Adding
# rules here is cheap and each one has to earn its place by naming the bug it
# would have caught. A rule with no such story does not belong.
#
# Run it from anywhere:  tests/qml-rules.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QML_DIR="$REPO/quickshell/.config/quickshell"

failed=0
note() { echo "qml-rules: $*"; }
fail() { echo "qml-rules: FAIL $*" >&2; failed=1; }

# --- what gets read, and why it is not one directory -------------------------
#
# THESE RULES ARE THEME RULES AS MUCH AS SHELL RULES, and that is measured
# rather than argued. Of the two WheelHandlers in this repository one is in
# components/ScrollList.qml and the other is in
# themes/genesis/wallpaper/WallpaperCarousel.qml; of the three
# FolderListModels, the ONLY one whose rows are read -- the only one this
# file's second rule has anything to say about -- is in that same theme file.
# Move genesis out from under quickshell/ and this check does not merely lose
# coverage, it fails outright with "has the rule outlived its subject?", which
# is the strongest evidence available that a theme is where these faults live.
#
# UNTIL NOW IT SWEPT ONE DIRECTORY. Everything under
# quickshell/.config/quickshell was read, genesis is under there, so genesis
# was checked -- by an accident of where it sits rather than because it is a
# theme. tests/fixtures/theme-probe is a theme by the same definition this
# repository uses everywhere else, has 27 .qml files, and matched nothing at
# all. A theme was only checked if it happened to live in one directory, and
# the one theme that does is the one that already existed.
#
# WHAT MAKES A DIRECTORY A THEME IS THE MANIFEST IN IT, NOT ITS PARENT, and
# that definition is not invented here. modules/Themes.qml says "A DIRECTORY
# WITH NO MANIFEST IS NOT A THEME AND IS NOT IN HERE"; tests/theme-interface.py
# refuses a directory with the words "has no manifest.json, which is what makes
# a directory a theme"; themes/genesis/README.md says "manifest.json is what
# makes a directory a theme." Being under themes/ is a different and narrower
# property -- it means a theme the runtime picker may OFFER -- and
# tests/fixtures/theme-probe/README.md is explicit that it stays out of there
# on purpose, precisely so nobody can choose it.
#
# THROUGH `git ls-files` AND NOT `find`, for a reason that bites on this
# machine. The dotfiles checkout carries .claude/worktrees/ full of whole
# copies of itself; a `find` for manifest.json from the repository root walks
# into every one of them and discovers the same two themes several dozen
# times. tests/shell-lint.sh already picks its files this way. The cost is that
# a theme nobody has `git add`ed yet is not swept, which is the same answer
# every other check here gives: this suite checks what is in the repository.
themes=()
while IFS= read -r manifest; do
    [[ ${manifest##*/} == manifest.json ]] || continue
    themes+=("$REPO/${manifest%/*}")
done < <(cd "$REPO" && git ls-files -- '*manifest.json' | sort)

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

# AND THE SAME FLOOR AGAIN, UNDER THE THEMES, because the sweep above cannot
# provide it. The shell tree is 97 files without a single theme in it, so it
# clears the 50 on its own -- a theme discovery that silently matched nothing
# would leave that count untouched and this check would go green having read no
# theme at all. That is the exact failure the count above exists to prevent,
# reappearing one level down, so it is asserted separately: at least one theme,
# and every theme found has QML in it.
#
# It does NOT ask whether a theme is COMPLETE. That is tests/theme-interface.py
# next door, which derives the 27-file interface from shell.qml's own paths and
# every Themes.surface() call site; a second, weaker copy of that question here
# would be a number invented in this file to stand in for one that is measured
# in that one.
if (( ${#themes[@]} == 0 )); then
    echo "qml-rules: no theme found -- looked for a manifest.json in git ls-files" >&2
    echo "qml-rules: a sweep with no theme in it cannot say anything about themes" >&2
    exit 1
fi

theme_files=0
for theme in "${themes[@]}"; do
    count=0
    while IFS= read -r -d '' file; do
        # Themes under the shell tree -- genesis -- are already in the list.
        # Counted all the same, because the floor is about what was FOUND.
        count=$(( count + 1 ))
        [[ $file == "$QML_DIR"/* ]] || qml_files+=("$file")
    done < <(find "$theme" -name '*.qml' -type f -print0 | sort -z)

    if (( count == 0 )); then
        echo "qml-rules: ${theme#"$REPO"/} has a manifest and no .qml at all" >&2
        echo "qml-rules: a theme whose files went out from under it is not a theme" >&2
        exit 1
    fi
    theme_files=$(( theme_files + count ))
done

note "${#themes[@]} theme(s), $theme_files file(s), swept wherever they live"

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
    fail "found no WheelHandler in ${#qml_files[@]} file(s) -- has the rule outlived its subject?"
elif (( ${#missing[@]} > 0 )); then
    fail "${#missing[@]} WheelHandler(s) leave acceptedDevices at Qt's default:"
    printf 'qml-rules:   %s\n' "${missing[@]}" >&2
    echo "qml-rules: the default is PointerDevice.Mouse, and this seat reports TouchPad" >&2
else
    note "all $handlers WheelHandler(s) declare acceptedDevices"
fi

# --- a FolderListModel whose rows are read watches `status` ------------------
#
# `count` is the obvious thing to drive a folder listing from and it is blind
# in one direction: a RENAME changes every path in the directory and leaves the
# number of files alone, so `onCountChanged` never fires. Measured on Qt
# 6.11.2 -- a rename emits `dataChanged` and a `Loading` -> `Ready` cycle, and
# no count signal of any kind.
#
# That cost the wallpaper carousel a real bug and a confusing one: renaming a
# picture left its OLD name in the selector with no thumbnail -- the thumbnail
# run sweeps the cache entry of a file that is not there any more, and the
# fallback to the original is a path that is gone too -- while the new name
# never appeared at all. Adding or deleting any other file put it right, which
# is most of what made it look like anything but what it was.
#
# NARROW ON PURPOSE, TWICE OVER.
#
# It asks only about models whose ROWS are read, `<id>.get(` somewhere in the
# file. A FolderListModel used for its `count` alone -- the wallpaper settings
# page counts images and draws none of them -- is correct on a rename, because
# the count really has not changed, and a rule that made that page carry a
# handler it has no use for would be the rule shaping the code.
#
# And it looks for the handler INSIDE the model's own block, by brace
# counting, not in the file. The first version of this rule grepped the whole
# file, and it passed a carousel whose FolderListModel had been put back on
# `onCountChanged` -- because three Images further down have `onStatusChanged`
# of their own and a file-wide grep cannot tell whose handler it found. It was
# checked by breaking the fix and watching the rule not notice.
readers=0
countonly=()
for file in "${qml_files[@]}"; do
    while IFS= read -r finding; do
        case $finding in
            found) readers=$(( readers + 1 )) ;;
            missing:*) readers=$(( readers + 1 ))
                       countonly+=("${file#"$REPO"/}:${finding#missing:}") ;;
        esac
    done < <(awk '
        # Comments off first, the same rule and for the same reason as the
        # WheelHandler sweep above: the paragraphs around a FolderListModel in
        # this tree name every identifier this is looking for.
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
        # Two passes over one file: the first records the block, the second
        # answers whether anything reads its rows. awk has the whole file only
        # if it keeps it, so it keeps it.
        { text[NR] = $0 }
        /(^|[^A-Za-z0-9_])FolderListModel[[:space:]]*\{/ && depth == 0 {
            depth = 0; start = NR; watches = 0; id = ""
        }
        start {
            if ($0 ~ /^[[:space:]]*id:[[:space:]]*[A-Za-z_][A-Za-z0-9_]*/) {
                id = $0
                sub(/^[[:space:]]*id:[[:space:]]*/, "", id)
                sub(/[^A-Za-z0-9_].*$/, "", id)
            }
            if ($0 ~ /onStatusChanged/) watches = 1
            n = gsub(/\{/, "{"); depth += n
            n = gsub(/\}/, "}"); depth -= n
            if (depth <= 0) {
                blocks[++found] = start "\t" watches "\t" id
                start = 0; depth = 0
            }
        }
        END {
            for (i = 1; i <= found; i++) {
                split(blocks[i], part, "\t")
                # An unnamed model cannot be read from anywhere else, so the
                # only rows anybody could get() are the ones this rule is not
                # about. Nothing to say.
                if (part[3] == "") continue

                read = 0
                for (n = 1; n <= NR; n++)
                    if (index(text[n], part[3] ".get(")) { read = 1; break }
                if (!read) continue

                print (part[2] ? "found" : "missing:" part[1])
            }
        }
    ' "$file")
done

if (( readers == 0 )); then
    fail "found no FolderListModel whose rows are read -- has the rule outlived its subject?"
elif (( ${#countonly[@]} > 0 )); then
    fail "${#countonly[@]} FolderListModel(s) have their rows read without watching status:"
    printf 'qml-rules:   %s\n' "${countonly[@]}" >&2
    echo "qml-rules: a rename changes every path and leaves count alone" >&2
else
    note "all $readers FolderListModel(s) whose rows are read watch status"
fi

# --- a singleton is imported by every file that reads it ---------------------
#
# A singleton is reached by importing THE MODULE IT LIVES IN and by nothing
# else. windows/Fluent.qml is `import qs.themes.windows`, NotificationState is
# `import qs.modules.notifications`, Theme is `import qs`. A file under
# components/ has an implicit import of components/ and of nothing else, so the
# line has to be written even when the singleton is one directory up.
#
# WITHOUT IT THE FAILURE IS AT RUNTIME AND SILENT, in one of two shapes.
#
# For a singleton used as a TYPE NAME the name still resolves -- `typeof Fluent`
# is "object" -- but it resolves to the TYPE rather than to the instance, so
# every property reads `undefined` and what reaches the log is one line per
# binding naming the CONSUMER, never the singleton:
#
#     WARN scene: .../components/ScrollBar.qml[109:5]:
#                 Unable to assign [undefined] to double
#
# For one read only inside a property binding or a handler there is no such
# consolation prize: it is a plain ReferenceError, thrown when that binding
# first evaluates, which for a flyout is the moment somebody opens it. The
# do-not-disturb tile drew perfectly and did nothing for a week on
#
#     ReferenceError: NotificationState is not defined
#
# and qmllint says nothing, because the reference is not a type name.
#
# THIS RULE ENFORCED THE WRONG IMPORT FIRST. It required `import ".."`, which
# is what genesis uses to reach its own directories and what qmllint is happy
# with. The relative form works when a file is loaded as a TYPE FROM A MODULE
# and fails when it is loaded BY URL -- and every theme file is loaded by URL,
# because ThemeSurface calls setSource on the surfaces and every facade calls
# setSource on its component. So the one path that works is the one no theme
# file is ever on.
#
# Measured both ways on a whole theme under labwc, selected and fully built:
# relative imports 2240 of those warnings in eighteen seconds, module imports
# zero.
#
# IT SWEEPS THE WHOLE SHELL AND NOT ONLY THE THEMES, which it used to. The
# narrower version checked a theme's own root singletons and would have said
# nothing about the tile above, because NotificationState is the HOST's and
# lives three directories away. Widening it costs one map -- a singleton's
# module is its directory under the shell root -- and covers both halves of a
# seam whose whole purpose is that the two halves are far apart.
#
# THE SAME-DIRECTORY CASE IS SKIPPED and that is a real hole, said plainly: a
# file sitting beside the singleton has an implicit import that works when the
# file is loaded as a type, and every host file is. A theme file beside its own
# singleton would be a false negative here. None exists -- every theme
# singleton is at the theme root and every reader is at least one directory
# down -- and narrowing the hole means requiring an import qmllint calls
# unused across the whole host tree, which is a bigger change than this rule.
#
# COMMENTS OFF FIRST, same as the two sweeps above and for a sharper reason
# here: Fluent.qml's own header quotes `Fluent.controlRadius` while explaining
# this, and a sweep that read its comments would report the file that documents
# the rule as the file that breaks it.
singleton_readers=0
singleton_missing=()
singleton_names=0

# name -> module, over every `pragma Singleton` in the shell.
declare -A singleton_module=()
while IFS= read -r -d '' f; do
    grep -qE '^[[:space:]]*pragma[[:space:]]+Singleton' "$f" || continue
    rel="${f#"$QML_DIR"/}"
    dir="${rel%/*}"
    if [[ "$dir" == "$rel" ]]; then
        module="qs"
    else
        module="qs.${dir//\//.}"
    fi
    singleton_module["$(basename "$f" .qml)"]="$module"
    singleton_names=$(( singleton_names + 1 ))
done < <(find "$QML_DIR" -name '*.qml' -type f -print0 | sort -z)

for file in "${qml_files[@]}"; do
    rel="${file#"$QML_DIR"/}"
    dir="${rel%/*}"
    if [[ "$dir" == "$rel" ]]; then
        own="qs"
    else
        own="qs.${dir//\//.}"
    fi

    # NOT `sed ... | grep -q`. `grep -q` exits on the first match and kills
    # `sed` with SIGPIPE, and under `set -o pipefail` that turns a MATCH into
    # a non-zero pipeline -- sometimes. Whether the write lands before grep
    # leaves is a race, and this sweep flickered between 41 and 42 readers
    # across runs on an unchanged tree until it was chased down. A test whose
    # number moves on its own is a test nobody can read.
    stripped="$(sed -e 's://.*::' "$file")"

    for name in "${!singleton_module[@]}"; do
        module="${singleton_module[$name]}"
        # Its own file, and the implicit-import hole documented above.
        [[ "$(basename "$file" .qml)" == "$name" ]] && continue
        [[ "$module" == "$own" ]] && continue

        grep -qE "(^|[^A-Za-z0-9_.])${name}\.[A-Za-z_]" <<<"$stripped" || continue
        singleton_readers=$(( singleton_readers + 1 ))
        grep -qE "^[[:space:]]*import[[:space:]]+${module//./\\.}[[:space:]]*$" "$file" \
            || singleton_missing+=("${file#"$REPO"/} reads ${name}. and does not import ${module}")
    done
done

if (( ${#singleton_missing[@]} > 0 )); then
    fail "${#singleton_missing[@]} file(s) read a singleton they never imported"
    printf 'qml-rules:   %s\n' "${singleton_missing[@]}" >&2
    echo "qml-rules: add the module's own import line, NOT import \"..\"" >&2
    echo "qml-rules: the relative form resolves the TYPE, not the singleton, when" >&2
    echo "qml-rules: the file is loaded by URL -- which every theme file is" >&2
    echo "qml-rules: and a read inside a binding is a plain ReferenceError, which" >&2
    echo "qml-rules: qmllint does not see because it is not a type name" >&2
elif (( singleton_names == 0 )); then
    fail "no pragma Singleton found anywhere under ${QML_DIR#"$REPO"/}"
    failed=1
else
    note "$singleton_readers read(s) of $singleton_names singleton(s) all import their module"
fi

if [[ $failed -eq 0 ]]; then
    note "the QML tree keeps to its rules"
fi
exit "$failed"
