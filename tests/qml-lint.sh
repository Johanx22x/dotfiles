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
# AND IT IS THE ONLY CHECK HERE THAT PARSES A FILE NOTHING RUNS, which is the
# reason the `[syntax]` block down the file is not just another category. QML
# compiles a type when something INSTANTIATES it, so a file that is loaded by
# URL at runtime, or sits behind a Loader that is not active, is never read at
# all by a shell that starts and comes up. tests/shell-load.sh starts the tree
# in a headless compositor and asks whether it loaded; it cannot ask this,
# because for these files there is nothing to load.
#
# HOW BIG THAT HOLE IS, measured rather than reasoned about: every one of the
# 126 .qml files in this tree was broken in turn -- the same line of garbage
# appended, one file at a time -- and tests/shell-load.sh was run against each.
#   80 of 126  it caught: a type in the statically imported host chain fails to
#              resolve, the configuration does not load, `qs` exits 255.
#   43 of 126  it did not: the shell came up, printed "Configuration Loaded"
#              and exited 0, and the only trace was a "Syntax error" line in a
#              log it was not reading. That string has since been added to the
#              four it does read, so these are caught there now too.
#    3 of 126  nothing anywhere said anything: components/ClickCatcher.qml,
#              ConfirmButton.qml and HyprlandGrab.qml. A green shell, an empty
#              log, and a file that does not parse.
#
#              TWO OF THE THREE FOR THE REASON GIVEN HERE, and the third for
#              one this got wrong, which is worth leaving in rather than
#              quietly correcting. ClickCatcher and HyprlandGrab are named only
#              from inside a delegate of a document that is itself loaded by
#              URL -- components/FocusGrab.qml setSources both -- so the type
#              is never resolved and the engine has no occasion to complain.
#              ConfirmButton was named from NOWHERE: its one call site, a
#              Restore defaults on the about page, had been deleted the day
#              before this was measured, and its silence was the silence of a
#              file nothing in the tree reached. Reading that as the same fault
#              is how it survived the audit that found it. It has since been
#              deleted, so the three are two.
# The 46 that came up green are all 32 files under themes/ and 14 under
# components/. That set grows with every surface moved behind a Loader and with
# every theme added, and the log assertion next door cannot follow it, because
# what it reads is the log of a shell that ran -- and none of this ran.
#
# ---------------------------------------------------------------------------
#
# A THEME IS SWEPT WHEREVER IT LIVES, AND UNTIL NOW IT WAS NOT. This script
# read one directory -- quickshell/.config/quickshell -- and themes/genesis is
# under it, so genesis was linted by an accident of where it sits rather than
# because it is a theme. tests/fixtures/theme-probe is a theme by this
# repository's own definition, holds 27 .qml files, and matched nothing at all.
#
# THAT IS WORSE THAN AN ORDINARY MISSED DIRECTORY, because the discipline the
# whole theme layer rests on IS a measurement taken with this script.
# themes/genesis/components/README.md rule 1 requires `required property
# <Facade> row` over `property var row`, and its entire justification is a
# table of two runs of this file: seven deliberate misspellings pass green
# through a `var`, and the typed form names five of them by line. Every theme
# is written to that rule, and the rule was enforced on exactly one theme.
# Measured on this branch before the change: three misspelled reads were put
# into the fixture's components/ToggleRow.qml with its `required property
# ToggleRow row` left alone, and the sweep came back "306 warnings, none of
# them new" and exited 0. Genesis was protected by its address.
#
# Discovery is now every directory with a manifest.json in it, which is what
# modules/Themes.qml and tests/theme-interface.py already mean by a theme, and
# an out-of-tree theme is copied into the sandbox at themes/<name>/ so that it
# gets the SAME qmldirs, the SAME import paths and the SAME sweep genesis does.
# See the blocks on both further down.
#
# ---------------------------------------------------------------------------
#
# THE BASELINE, AND WHY IT IS NOT ZERO. The tree measured 326 the first time a
# linter could read it; 19 of those were cheap and are gone, which made it 307,
# and one more went with the notification card's split -- see unresolved-type
# below -- so the shell tree and genesis together are 306. The fixture adds the
# 6 it was always going to add once anything looked at it, which made the sweep
# 312; the windows theme adds genesis's 160 a second time because it IS genesis
# a second time, and the sweep is 471. That last number is the one that should
# fall: a theme redrawn is a theme that need not inherit the shapes these
# warnings are counting.
# Gating at zero would mean gating at a number nobody can reach today, so this
# gates at what is there and refuses to let it grow.
#
# ONE BUDGET PER SCOPE, AND A THEME IS ITS OWN SCOPE -- `shell` for
# quickshell/ with the themes taken out, and its own name for each theme. The
# single total that used to be here would have taken the fixture's 6 in
# silence, and then the next theme's, and a number that every theme may add to
# is not a budget: it is an account nobody can read. Split, an unbudgeted
# theme is compared against zero, so dropping a theme into this repository
# turns the run red naming THAT THEME and its categories, and the shell's
# numbers stay a statement about the shell.
#
# The split is measured, not apportioned by eye:
#
#          shell  genesis  windows  probe
#   145      145        -        -      -   the shell tree
#   160        -      160        -      -   genesis
#   160        -        -      160      -   windows
#     6        -        -        -      6   theme-probe
#
# WINDOWS IS GENESIS'S NUMBERS TWICE AND THAT IS WHAT IT SHOULD BE AT THIS
# COMMIT: the theme was created with `cp -r genesis windows`, so it is the same
# files and therefore the same findings, category for category. The pair will
# come apart as the theme is redrawn, and the direction it comes apart in is
# the interesting part -- 128 of genesis's 130 unqualified reads are one shape,
# a delegate naming an id from outside itself, and a component written fresh
# does not have to be written that way. If the windows column tracks genesis's
# all the way to the end, nothing was learned from writing a second theme.
#
# THE FILE COUNTS ARE NOT WRITTEN DOWN HERE ANY MORE. They said 96, 50 and 27,
# and the sweep line above prints the real ones on every run. Two of the three
# were already stale.
#
# and by category, which is the shape that matters more than the total:
#
#   245  unqualified                115 shell + 130 genesis. 242 of them are
#                                   one thing -- 114 and 128 -- a delegate
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
#                                   other 3 are ordinary unqualified reads --
#                                   1 shell, 2 genesis -- in files where fixing
#                                   them was a one-word change; Compositor.qml's
#                                   three are gone.
#    19  missing-property           2 shell + 17 genesis. Reads through a `var`,
#                                   and PathView attached properties declared by
#                                   PathAttribute, which qmllint cannot see.
#                                   Checked one by one; none is a bug. THE
#                                   FIXTURE HAS NONE, and that zero is the one
#                                   number in this table that does work: it is
#                                   what a misspelled read against a typed
#                                   facade lands in, so rule 1 is enforced on
#                                   theme-probe by [theme-probe:missing-property]
#                                   having nowhere to hide.
#    17  signal-handler-parameters  16 shell + 1 genesis. Every one is
#                                   QProcess::ExitStatus on an onExited handler.
#                                   Quickshell exposes a Qt private enum there;
#                                   nothing in this repository can fix it.
#    13  unresolved-type            7 shell + 6 genesis. Quickshell C++ types
#                                   not exposed
#                                   declaratively: Toplevel, UntypedObjectModel,
#                                   FileViewAdapter, DBusMenuHandle. Not ours.
#                                   Was 14: the notification card read
#                                   `notification.actions` twice and each read
#                                   cost one, so hoisting the list into a
#                                   single property when the card was split
#                                   took one off. Which is the only way a
#                                   number in this column ever moves for a
#                                   reason of ours -- the TYPE is still not
#                                   exposed; there is one fewer place asking.
#    15  uncreatable-type           3 shell + 6 genesis + 6 theme-probe.
#                                   "PanelWindow is not creatable", which is
#                                   false -- the whole shell is PanelWindows. An
#                                   artefact of how Quickshell registers it.
#                                   The fixture's 6 are its whole account: one
#                                   per surface, and nothing else at all.
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
# So 45 of the 311 -- signal-handler-parameters 17, unresolved-type 13,
# uncreatable-type 15 -- are Quickshell's type information rather than this
# repository's code, and no change here can move them. They are counted anyway,
# because a baseline that quietly excludes things is a baseline nobody can
# reproduce with a single command.
#
# THAT SENTENCE USED TO READ "60 of the 307" AND THE ARITHMETIC WAS WRONG. The
# three categories it names came to 39, not 60; 60 was every category except
# unqualified, which is not what the sentence says. Recomputed here from the
# split above rather than carried forward.
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
#
# ONE BUDGET PER SCOPE, AND A THEME IS ITS OWN SCOPE. Keys are `scope:category`
# -- `shell` for quickshell/ with the themes taken out, and the theme's own
# name for each theme. See the section above on why the single total that used
# to be here was a budget a theme could inflate. A scope:category that is not
# written down here is compared against zero, which is what makes an unbudgeted
# theme go red naming its own numbers instead of quietly joining somebody
# else's.
#
# `syntax` IS NOT IN HERE AND MUST NOT BE ADDED. It is the one finding this
# table cannot express: every entry below is a number somebody is willing to
# carry, and there is no number of files that do not parse that this repository
# is willing to carry. It is asserted on its own further down, outside the
# comparison, so that the way it stops failing a run is that the file is fixed
# and not that a number was written here.
declare -A BASELINE=(
    # --- the shell tree, themes excluded: 145 warnings -----------------------
    [shell:unqualified]=115
    [shell:signal-handler-parameters]=16
    [shell:unresolved-type]=7
    [shell:uncreatable-type]=3
    [shell:missing-property]=2
    [shell:incompatible-type]=1
    [shell:redundant-optional-chaining]=1
    [shell:unused-imports]=0
    [shell:duplicate-property-binding]=0

    # --- genesis: 160 warnings ----------------------------------------------
    [genesis:unqualified]=130
    [genesis:missing-property]=17
    [genesis:unresolved-type]=6
    [genesis:uncreatable-type]=6
    [genesis:signal-handler-parameters]=1

    # --- windows: 68 warnings, and none of them inherited -------------------
    #
    # THIS TABLE USED TO SAY "genesis's account, twice", AND IT WAS RIGHT.
    # The first Windows theme was made with `cp -r genesis windows`, so it
    # started with genesis's 160 warnings in genesis's 160 places and the
    # numbers moved only where somebody had rewritten a file. Johan looked at
    # what that produced and called it a cheap adaptation; the theme was
    # deleted and drawn again from an empty 36-file skeleton, and these are the
    # numbers of a tree that was written rather than copied.
    #
    #                    genesis   windows
    #   unqualified          130        55
    #   missing-property      17         4
    #   unresolved-type        6         3
    #   uncreatable-type       6         6
    #                      -----     -----
    #                        160        68
    #
    # Lower these as they fall. A budget left above the real number is a budget
    # that hides the next regression underneath it.

    # SIX PanelWindows, one per surface, and the same six genesis and the
    # fixture each carry. Quickshell registers PanelWindow uncreatable and
    # instantiates it itself; nothing in this repository can change that.
    [windows:uncreatable-type]=6

    # FIFTY-FOUR DELEGATE READS AND ONE PanelWindow SCOPE.
    #
    # The delegate shape is genesis's too, and it is worth stating exactly
    # because 55 against 130 is the only number here that could be mistaken for
    # a virtue. Inside a `delegate` or a `Repeater`, `root.anything` is out of
    # scope as far as qmllint is concerned even though it resolves perfectly at
    # runtime -- every photograph of this theme is of those bindings working.
    # Windows has fewer because it has fewer delegates, not because a fix was
    # found.
    #
    # There IS a way to cut them: hang the reads off the view instead of the
    # outer id. It was tried on the launcher's ListView and it moved five out
    # of [unqualified] and into [missing-property], which is a trade this
    # repository refuses. [missing-property] is the category that catches a
    # MISSPELLED read through a typed facade -- the whole return on rule 1 of
    # themes/genesis/components/README.md -- and five permanent false positives
    # in it are five places a real typo can hide.
    #
    # The odd one out is `margins` on a PanelWindow in launcher/Launcher.qml, a
    # grouped scope qmllint cannot resolve at all; the shell budget carries the
    # same finding from components/Popout.qml. Writing it dotted rather than as
    # a block does not help. That was MEASURED after the comment at the site
    # claimed it did: both forms produce the same two warnings at the same
    # line, because what cannot be resolved is `margins` itself.
    [windows:unqualified]=55

    # FOUR READS THROUGH THE PICKER LOADER, all of them launcher/Launcher.qml
    # calling `move()` and `activate()` on a `Loader.item` typed QObject. The
    # launcher hosts pickers of different types behind one loader -- the
    # clipboard history today, whatever comes next tomorrow -- so the item
    # genuinely has no single type to declare, and the facade for it is the
    # pair of functions every picker promises. Typing it would mean naming one
    # picker in the surface that is supposed to host any of them.
    [windows:missing-property]=4

    # ONE Quickshell C++ TYPE AND ONE PanelWindow SCOPE. The type is
    # `QList<NotificationAction*>` read off a live notification in
    # components/NotificationCard.qml, which Quickshell does not expose
    # declaratively -- it was two reads until the action filter hoisted one
    # into a plain `var`; the other is the `margins` from the paragraph above,
    # counted once in each category.
    [windows:unresolved-type]=2

    # --- theme-probe: 6 warnings --------------------------------------------
    #
    # ALL SIX ARE "PanelWindow is not creatable", one per surface, which is the
    # Quickshell artefact the table above carries nine of. The fixture has no
    # unqualified read and no missing property at all -- and that is the number
    # the demonstration in tests/fixtures/theme-probe/README.md moves: turn one
    # component's `required property <Facade> row` into `property var row` and
    # misspell a read and this line stays 6, because a read through `var` is a
    # read qmllint cannot check. Restore the type and the misspelling arrives
    # here as [theme-probe:missing-property], which is rule 1 of
    # themes/genesis/components/README.md being enforced on a theme that is not
    # genesis and does not live under quickshell/.
    [theme-probe:uncreatable-type]=6
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

# --- where the themes are ----------------------------------------------------
#
# WHAT MAKES A DIRECTORY A THEME IS THE MANIFEST IN IT, NOT ITS PARENT. That is
# this repository's own definition and not one invented here: modules/
# Themes.qml says "A DIRECTORY WITH NO MANIFEST IS NOT A THEME AND IS NOT IN
# HERE", tests/theme-interface.py refuses a directory with the words "has no
# manifest.json, which is what makes a directory a theme", and themes/genesis/
# README.md says the same. Living under themes/ is a DIFFERENT and narrower
# property -- it means a theme the runtime picker may offer -- and
# tests/fixtures/theme-probe/README.md is explicit that the fixture stays out
# of there on purpose, so that nobody can choose it.
#
# THROUGH `git ls-files` AND NOT `find`, for a reason that bites on this
# machine: the dotfiles checkout carries .claude/worktrees/ full of whole
# copies of itself, and a `find` for manifest.json from the repository root
# walks into every one of them and discovers the same two themes several dozen
# times over. tests/shell-lint.sh already chooses its files this way. The cost
# is that a theme nobody has `git add`ed is not swept, which is the answer
# every other check here gives: this suite checks what is in the repository.
theme_dirs=()
theme_names=()
while IFS= read -r manifest; do
    [[ ${manifest##*/} == manifest.json ]] || continue
    dir="${manifest%/*}"
    theme_dirs+=("$REPO/$dir")
    theme_names+=("${dir##*/}")
done < <(cd "$REPO" && git ls-files -- '*manifest.json' | sort)

# THE FLOOR THE COUNT ABOVE CANNOT PROVIDE. The shell tree is 96 files with
# every theme taken out, so it clears the 50 on its own: a theme discovery that
# silently matched nothing would leave `qml_count` untouched and this script
# would go green having linted the shell and no theme whatsoever. That is the
# same failure the count above exists to prevent, one level down, so it is
# asserted separately.
#
# It does NOT ask whether a theme is COMPLETE -- that is tests/theme-interface.py
# next door, which derives the 27-file interface from shell.qml's own paths and
# every Themes.surface() call site. A second, weaker copy of that question here
# would be a number invented in this file standing in for one that is measured
# in that one.
if (( ${#theme_dirs[@]} == 0 )); then
    echo "qml-lint: no theme found -- looked for a manifest.json in git ls-files" >&2
    echo "qml-lint: a sweep with no theme in it cannot say anything about themes" >&2
    exit 1
fi

for i in "${!theme_dirs[@]}"; do
    if ! find "${theme_dirs[i]}" -name '*.qml' -type f -print -quit | grep -q .; then
        echo "qml-lint: ${theme_dirs[i]#"$REPO"/} has a manifest and no .qml at all" >&2
        echo "qml-lint: a theme whose files went out from under it is not a theme" >&2
        exit 1
    fi
done

note "$("$QMLLINT" --version)"

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

# The copy is what gets the qmldirs, so the repository never does. `qs` is the
# directory name and not a decoration: it is the module Quickshell registers
# the config root as, so `import qs.components` has to resolve to <root>/qs/
# components/qmldir for qmllint the same way it does for the shell.
root="$sandbox/qs"
cp -r "$SHELL_DIR" "$root"

# --- a theme that lives somewhere else ---------------------------------------
#
# IT IS PUT WHERE GENESIS ALREADY IS, and that is the whole design rather than
# a convenience. The goal is that a theme is checked THE SAME wherever it
# lives; linting an out-of-tree theme through some other arrangement -- in
# place, with its own import paths -- would answer a different question about
# it than the one genesis is asked, and would be the same defect this change
# is closing, wearing a second mechanism. Dropped in at themes/<name>/ it gets
# the identical synthesized qmldirs, resolves `qs`, `qs.components` and
# `qs.modules.*` against the identical copy of the host, and is swept by the
# identical xargs below.
#
# tests/shell-load.sh already does exactly this -- it copies the shell tree
# and drops tests/fixtures/theme-probe/ in as a second theme -- so this is the
# arrangement the suite already runs the fixture under, not a new one.
#
# NOTHING IS COPIED THAT ALREADY EXISTS. tests/scrollbar-target.py builds its
# module graph out of relative paths back into the real tree instead of copies,
# because a QML type IS its document and a copy is a second type of the same
# name that a `required property <Facade>` will refuse. That hazard is about
# ASSIGNMENT between two live documents in a running engine, and it is real
# there. Here nothing is constructed and nothing is assigned: qmllint resolves
# names statically, the host tree is copied exactly once, and every theme
# resolves `qs.components.ScrollBar` to that one copy. What is copied a second
# time is only the theme's own files, which no other spelling reaches.
#
# The collision check is not decoration. Two themes of one name would have the
# second silently overwrite the first, and the sweep would report the survivor
# under both budgets.
theme_sandbox=()
for i in "${!theme_dirs[@]}"; do
    if [[ ${theme_dirs[i]} == "$SHELL_DIR"/* ]]; then
        # Already inside the copy above; nothing to do but record where it is.
        rel="${theme_dirs[i]#"$SHELL_DIR"/}"
        theme_sandbox+=("./$rel/")
        continue
    fi

    dest="$root/themes/${theme_names[i]}"
    if [[ -e $dest ]]; then
        echo "qml-lint: two themes are called ${theme_names[i]}" >&2
        echo "qml-lint:   ${theme_dirs[i]#"$REPO"/}" >&2
        echo "qml-lint: a name is how a theme is chosen, so it has to be unique" >&2
        exit 1
    fi
    cp -r "${theme_dirs[i]}" "$dest"
    theme_sandbox+=("./themes/${theme_names[i]}/")
done

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
swept="$(find "$root" -name '*.qml' -type f | wc -l)"
note "$swept file(s) in $modules module(s): the shell and ${#theme_dirs[@]} theme(s)"

# --- the floor under the parse check -----------------------------------------
#
# WHY THE FILE COUNT ABOVE IS NOT THE FLOOR THIS ONE NEEDS. Every other
# assertion in this file is over the tree, so an empty tree is the only way
# they can go quiet, and `qml_count` is what stops that. The parse check below
# has a second way to go quiet that no count of files can see: qmllint can stop
# reporting syntax at all, and then a tree full of garbage sweeps clean. `-s`
# suppresses it outright; a `.qmllint.ini` anywhere above the file being linted
# can turn categories off; and Qt 5's qmllint -- the one on the PATH here, see
# the note at the top -- exits 255 printing nothing on most of this tree. In
# every one of those the report comes back with no `[syntax]` line in it, which
# is byte for byte what a tree that parses looks like.
#
# So a file that cannot parse is written into the copy, linted on its own, and
# the answer is read. This is the assertion that the instrument still answers
# the question, and it fails the run rather than warning: with a qmllint that
# has gone quiet, everything below is a green tick over an empty set.
#
# NOT THROUGH A PIPE INTO `grep -q`, which is the version that was written
# first and was wrong in the direction that hides nothing and reports
# everything: `set -o pipefail` is on and qmllint exits 255 on a syntax error,
# so the pipeline carries 255 whatever grep found and `if !` fired on a clean
# run. The output goes into a variable and grep reads that.
canary="$root/SyntaxCanary.qml"
printf 'import QtQuick\nItem { }\nthis file does not parse {{{\n' > "$canary"
canary_out="$("$QMLLINT" -I "$sandbox" -I /usr/lib/qt6/qml "$canary" 2>&1 || true)"
rm -f "$canary"
if ! grep -q '\[syntax\]' <<<"$canary_out"; then
    fail "qmllint no longer reports a file that cannot parse as [syntax]"
    echo "qml-lint: a file of deliberate garbage was linted and it said:" >&2
    # `|| true` for the reason the examples below have it: head closes the pipe
    # and printf takes SIGPIPE, which under `set -o pipefail` would replace the
    # status this line is about to exit with.
    printf '%s\n' "${canary_out:-(nothing at all)}" | head -n 5 >&2 || true
    exit 1
fi

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

# --- who each finding belongs to, and where that file really is --------------
#
# TWO JOBS AT ONCE, AND THEY ARE THE SAME JOB. Every path in the report is
# relative to the copy, so it has to be rewritten to the repository -- a
# warning naming a file under /tmp that no longer exists is a warning nobody
# can act on -- and the rewrite is no longer one substitution, because
# ./themes/theme-probe/ came from tests/fixtures/ and ./modules/ came from
# quickshell/. Deciding which prefix to put back IS deciding which budget the
# finding counts against, so it is done once, here.
#
# THE PREFIXES ARE MATCHED WITH index() AND NOT A REGEX. A theme's name is a
# directory name off the filesystem: it is allowed to contain `.`, `+` and
# every other character a regular expression would read as an instruction,
# and a sed built by pasting one in is a sed a theme can rewrite. The awk
# below compares fixed strings.
#
# THE SHELL IS THE LAST ENTRY AND IT IS THE FALLBACK, so `./shell.qml` and
# `./modules/Themes.qml` land there while ./themes/genesis/ is claimed first
# by genesis. Order matters and is set here rather than inferred.
#
# A CONTINUATION LINE GOES WHERE ITS FINDING WENT. qmllint prints the offending
# source under each message, and an Info line of advice under some of them;
# neither carries a path. They are kept with the finding above them so the
# examples this script prints on a failure are readable.
scopes="$sandbox/scopes.tsv"
: > "$scopes"
for i in "${!theme_dirs[@]}"; do
    printf '%s\t%s/\t%s\t%s\n' "${theme_sandbox[i]}" \
        "${theme_dirs[i]#"$REPO"/}" "${theme_names[i]}" \
        "$sandbox/scope.${theme_names[i]}.txt" >> "$scopes"
done
printf '%s\t%s\t%s\t%s\n' "./" "${SHELL_DIR#"$REPO"/}/" "shell" \
    "$sandbox/scope.shell.txt" >> "$scopes"

awk -v map="$scopes" '
    BEGIN {
        while ((getline line < map) > 0) {
            split(line, f, "\t")
            n++; pfx[n] = f[1]; real[n] = f[2]; label[n] = f[3]; out[n] = f[4]
            printf "" > out[n]
        }
        close(map)

        # THE SHELL BEFORE ANYTHING HAS BEEN CLAIMED, so that a line arriving
        # before the first finding is kept rather than dropped. qmllint can say
        # things that carry no <file>:<line>:<col> -- an Error out of qmllint
        # itself is the one that matters -- and the whole report is
        # reassembled from these files for the parse check and the Error check
        # further down. A line this awk discards is a line those two never see.
        cur = n
    }
    # A finding, and not the source line or the advice under it: those carry no
    # <file>:<line>:<col>, which is what this insists on seeing.
    /^(Warning|Info|Error|Critical): [^ ]+:[0-9]+:[0-9]+: / {
        path = $2
        sub(/:[0-9]+:[0-9]+:$/, "", path)

        target = n                      # the shell, the fallback
        for (i = 1; i < n; i++)
            if (index(path, pfx[i]) == 1) { target = i; break }

        kind = index($0, ": ")
        rest = substr($0, kind + 2)
        $0 = substr($0, 1, kind + 1) real[target] substr(rest, length(pfx[target]) + 1)
        cur = target
    }
    cur { print > out[cur] }
' "$report"

# Back into one file for the two assertions that are about the whole sweep
# rather than about any one scope: the parse check and the Error check. Neither
# is budgeted, so neither needs to know whose file it is looking at.
: > "$report"
while IFS=$'\t' read -r _ _ _ file; do cat "$file" >> "$report"; done < "$scopes"

# Anchored at the end of the line, which is not fussiness. qmllint echoes the
# offending source under each message, and a delegate reading `root.list[index]`
# puts `[index]` at the end of an echoed line that is not a finding at all --
# counted loosely, that one line invented a whole category.
declare -A counts=()
declare -A scope_file=()
total=0
while IFS=$'\t' read -r _ _ label file; do
    scope_file["$label"]="$file"
    while read -r category count; do
        counts["$label:$category"]="$count"
        total=$(( total + count ))
    done < <(grep -oP '^(?:Warning|Info|Error|Critical):.*\[\K[a-z-]+(?=\]$)' \
                  "$file" | sort | uniq -c | awk '{print $2"\t"$1}')
done < "$scopes"

# --- does every file parse ---------------------------------------------------
#
# THE ONE FINDING THAT IS NOT A WARNING, whatever qmllint chooses to call it,
# and the only question in this repository that this check alone can answer.
# See the section on it in the header: tests/shell-load.sh comes up green with
# a line of garbage appended to any one of 46 of the 126 files here -- all 32
# under themes/ and 14 under components/ -- because QML compiles a type when
# something instantiates it, and a surface loaded by URL at runtime is not
# instantiated by a shell starting up.
#
# IT IS DELIBERATELY OUTSIDE THE BASELINE TABLE and skipped by the loop below,
# which is the whole point of lifting it out rather than adding `[syntax]=0` to
# the table with the other zeros. Every category down there is budgeted: it is
# compared against a number, and the way a category stops failing the run is
# that somebody writes its current count into the table. That is right for
# warnings and wrong for this. There is no number of files that do not parse
# which this repository is willing to carry, so there is no number to write.
#
# The prefix is anchored for the reason the counting grep two blocks up is:
# qmllint echoes the offending source line under each message, and an echoed
# line is not a finding.
#
# IT IS REPORTED BEFORE THE TABLE BECAUSE IT INVALIDATES THE TABLE. A file
# qmllint cannot parse is a file whose types it cannot resolve, so every
# category that reads one comes back short and the loop below helpfully offers
# to lower the baseline. Measured, with a line of garbage on
# themes/genesis/island/Island.qml: [unqualified] 246 -> 232 and
# [missing-property] 19 -> 9. Those notes are an artefact of the failure
# printed above them and not an invitation -- fix the file and the numbers come
# back.
syntax_lines="$(grep -P '^(?:Warning|Info|Error|Critical):.*\[syntax\]$' \
                     "$report" || true)"
if [[ -n $syntax_lines ]]; then
    syntax_count="$(grep -c '' <<<"$syntax_lines")"
    fail "$syntax_count file(s) in the tree do not parse:"
    printf '%s\n' "$syntax_lines" | head -n 10 >&2 || true
fi

# AND NOT THE SAME THING, which was measured rather than assumed after the
# comment here claimed it was. This used to say that a file qmllint cannot
# parse is reported as an `Error:`; it is not. qmllint 6.11.2 reports it as
# `Warning: <file>:<line>:<col>: Syntax error [syntax]` and exits 255, and the
# 255 is swallowed by the `|| true` the sweep needs for its 307 warnings. So
# this branch never fired for the fault it named, and the block above is what
# now asks that question. It is kept for the ones it does catch -- a `Critical`
# or an `Error` out of qmllint itself, which no baseline should absorb either.
if grep -q '^Error:' "$report"; then
    fail "qmllint reported errors, not just warnings:"
    errors="$(grep '^Error:' "$report" || true)"
    printf '%s\n' "$errors" | head -n 10 >&2 || true
fi

# Every scope:category in either table, so one that appears from nowhere is
# named rather than silently added to a total.
#
# A SCOPE THAT NOBODY BUDGETED IS COMPARED AGAINST ZERO, and that is the point
# of keying by scope at all. Drop a theme into this repository and every
# category it reports is a key that is not in the table above, so every one of
# them reads `0 -> n` and the run goes red naming the theme, the category and
# ten examples. The alternative -- one total for the tree -- let a new theme
# add its warnings to a number written about somebody else's code, and the only
# way to tell whose they were was to go and count.
for key in $(printf '%s\n' "${!counts[@]}" "${!BASELINE[@]}" | sort -u); do
    label="${key%%:*}"
    category="${key#*:}"
    # Handled above, and on purpose not budgetable. `if` rather than
    # `[[ ... ]] && continue`: the second form is the last command in the loop
    # body on every iteration that is not syntax, and under `set -e` a false
    # test there ends the script.
    if [[ $category == syntax ]]; then continue; fi
    now="${counts[$key]:-0}"
    was="${BASELINE[$key]:-0}"
    if (( now > was )); then
        fail "$label [$category] $was -> $now"
        # THE FIRST FEW IN THE CATEGORY, which is not the same as the new ones:
        # nothing here knows which of 249 unqualified reads arrived with this
        # branch. They are printed to say what the category looks like; the diff
        # is what says which ones are yours.
        # Into a variable and not through `| head`: head closes the pipe on the
        # tenth line, grep takes SIGPIPE, and under `set -o pipefail` that 141
        # becomes the exit status of the whole check -- which is a failure, but
        # not the one being reported, and not one `exit "$failed"` chose.
        #
        # Out of the SCOPE's own findings and not the whole report, so a theme
        # that went red is illustrated with its own files rather than with
        # whichever ten of the shell's happen to sort first.
        examples="$(grep -P "\[$category\]$" "${scope_file[$label]:-$report}" || true)"
        #
        # QML_LINT_EXAMPLES raises the ten, and it exists because setting a
        # baseline needs the whole category rather than a sample of it. Ten is
        # right for a red run somebody has to read; writing a budget means
        # counting every line the budget covers.
        printf '%s\n' "$examples" | head -n "${QML_LINT_EXAMPLES:-10}" >&2 || true
    elif (( now < was )); then
        # Not a failure, and deliberately so: a branch that improves the tree
        # should not have to argue with a test. It does have to record it,
        # because a baseline nobody lowers stops being a baseline.
        note "$label [$category] $was -> $now -- lower the baseline in this file"
    fi
done

if [[ $failed -eq 0 ]]; then
    note "$total warning(s), none of them new"
fi
exit "$failed"
