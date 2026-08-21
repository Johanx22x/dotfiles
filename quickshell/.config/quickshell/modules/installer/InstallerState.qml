// What ./install.sh knows, held where the bar and the settings window can both
// read it.
//
// WHY THIS IS A THIRD FRONTEND AND NOT A SECOND INSTALLER. install.sh is a
// unit registry with three modes over one engine -- see the header of that
// file and of lib/units.sh. What there is to do lives in lib/units/, one file
// per unit, each answering the same six questions and knowing nothing about
// how it is being driven. `check --json` is that engine's machine-readable
// mouth, and it prints one object per unit, with five fields:
//
//   id      symlinks
//   title   Symlinks
//   state   missing:1 not linked
//   kind    missing
//   note    1 not linked
//
// WRITTEN OUT AS FIELDS AND NOT AS THE JSON OBJECT IT REALLY IS, which looks
// like fussiness and is not: a pair of braces anywhere in the comment ABOVE
// `pragma Singleton` stops this file being a singleton at all. Nothing errors.
// Every property on it reads back undefined, every function on it is "not a
// function", and the only symptom is a widget that draws nothing. That is an
// afternoon already spent once on this desktop; the rule is written on the
// wall of it, and this comment is where the next person meets the wall.
//
// `kind` is a four-value enum -- ok, missing, drift, na -- which is why the
// page can draw a chip from it without interpreting anything, and `note` is
// the sentence a person reads. NOTHING IN THIS FILE DECIDES WHAT A UNIT IS OR
// WHETHER IT IS IN PLACE. The moment it did, there would be two answers to
// that question on this machine and no way to know which one is stale.
//
// THE COMPLAINT THIS EXISTS FOR, in the owner's words: "me se hace tedioso que
// la gente tenga que reproducir todos los pasos de vuelta al querer hacer
// update". Keeping a machine up to date should not mean remembering a sequence
// of terminal steps. So the desktop says when there is something to catch up
// on, and the catching up is one button.
//
// ------------------------------------------------------------------ PRIVILEGE
//
// THE RULE: THIS SHELL NEVER RUNS PRIVILEGED WORK ITSELF. It runs the units
// that need no root, in place, as the user who is sitting here. Everything
// that needs root is handed to a terminal running THE SAME CLI, where sudo can
// ask its question the way sudo asks questions.
//
// No unit file mentions sudo at all -- it lives in lib/pkg.sh and lib/ui.sh --
// so the split falls along whole units, and `terminalUnits` below is all of it.
//
// WHY NOT pkexec, WITH THE POLKIT AGENT THAT IS ALREADY RUNNING. Because
// pkexec would run the WHOLE installer as root, and most of these units write
// into $HOME: symlinks stows into ~/.config, seeds copies there, nvim clones
// there, palette writes caches there. Root-owned files under a home directory
// are how a desktop stops being editable by the person who owns it, and
// install.sh refuses to run as root at all for exactly this reason -- see "THE
// TWO REFUSALS" in that file.
//
// The other shape -- one process that raises and drops privilege around the
// units that need it -- is worse than not splitting at all: it puts the
// boundary inside a program instead of between two of them, so every future
// unit has to be classified correctly by somebody who may not know the rule
// exists. A terminal is a boundary nobody can erase by accident.
//
// This paragraph is here rather than in a commit message because it is the
// kind of decision somebody will otherwise "simplify" later.
//
// ------------------------------------------------------------- WHEN IT CHECKS
//
// `check --json` is read-only and takes about three seconds on the machine
// this repository comes from -- it asks pacman about a hundred and nineteen
// packages, walks a hundred and sixty-five files resolving symlinks, and asks
// systemd about a dozen units. Measured, not guessed:
//
//   $ time ./install.sh check --json
//   1.15s user 2.21s system  3.18s total
//
// A POLL WOULD BE THREE SECONDS OF SHELL WORK, FOREVER, TO ANSWER A QUESTION
// WHOSE ANSWER ONLY CHANGES WHEN SOMEBODY CHANGES SOMETHING. So there is no
// poll. It checks:
//
//   - once, shortly after the shell starts, which is also after every reload
//     -- and a `git pull` that brings in new .qml files reloads this shell, so
//     the commonest way of falling behind announces itself for free;
//   - when the session comes back from suspend (see wakeTimer);
//   - when the settings page is looked at;
//   - when anything is applied, because the table it just changed is the one
//     thing on screen that must not be stale;
//   - whenever somebody asks: the widget, the page's button, or
//     `qs ipc call updates check` from a terminal.
//
// The honest limit of that list is that a pull touching only packages/, on a
// session that stays up for a week, is not noticed until something asks. That
// is a missed notification and not a wrong answer, and the alternative was a
// timer nobody could defend.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"
import "root:/modules/settings"

Singleton {
    id: root

    // ---------------- Where the repository is ----------------
    //
    // FOUND RATHER THAN WRITTEN DOWN. ~/.config/quickshell is a tree of
    // symlinks back into the clone, so the shell's own root file, resolved
    // through those links, is inside the repository; walking up from it to the
    // first directory holding an executable install.sh finds the clone
    // wherever it is. That covers the repo moved somewhere else, a second
    // checkout, and a git worktree -- all three of which happen on this
    // machine -- without this file carrying a path that would be wrong on any
    // of them.
    //
    // Empty until the probe answers, and the widget and the page both say so
    // rather than pretending: a shell running from a copy that is not a clone
    // has no installer to drive and should admit it.
    property string repoDir: ""
    readonly property bool repoKnown: root.repoDir !== ""

    // ---------------- What check last said ----------------
    //
    // The array from `check --json`, verbatim. Kept as it arrived so that a
    // field added to that JSON later is available here without this file being
    // edited.
    property var units: []
    property bool checking: false

    // Date.now() of the last answer, or 0 if there has never been one. The
    // page shows it, because a table with no timestamp is a table you cannot
    // tell from a stale one.
    property double checkedAt: 0

    // Non-empty when the last attempt did not produce a table. This is NOT the
    // same as "the machine has problems": check exits 1 whenever a unit that
    // applies here is not ok, which is its normal answer on a machine with
    // work to do.
    property string checkError: ""

    readonly property bool ready: (root.units ?? []).length > 0

    // ---------------- Reading the table ----------------

    // Units this machine has something to do about. `na` is not work -- a
    // desktop is not broken for not being a laptop -- and `ok` is not work
    // either. That is the same count the CLI prints under its table.
    // `?? []` AND NOT BECAUSE units MIGHT NOT BE AN ARRAY. Bindings inside a
    // singleton are not evaluated in declaration order, so a reader that
    // touches this during construction can arrive before `units: []` has been
    // applied and get undefined -- which is not an error anywhere, it is a
    // warning on stderr and an `outstanding` of undefined for one frame. The
    // guard costs nothing and keeps the log clean; the same one is on every
    // derived property below.
    readonly property var outstandingUnits: {
        const out = [];

        for (const unit of (root.units ?? []))
            if (unit.kind === "missing" || unit.kind === "drift")
                out.push(unit);

        return out;
    }

    readonly property int outstanding: (root.outstandingUnits ?? []).length

    // The worst kind outstanding, for whoever has one colour to spend. Drift
    // beats missing, which is the order the CLI's table colours them in:
    // something that is there and wrong is worth more attention than something
    // that is not there yet.
    readonly property string worst: {
        let seen = "";

        for (const unit of (root.outstandingUnits ?? [])) {
            if (unit.kind === "drift")
                return "drift";
            seen = "missing";
        }

        return seen;
    }

    // ---------------- The privilege split ----------------
    //
    // VERIFIED AGAINST THE UNIT FILES, not inferred from their names:
    //
    //   grep -n 'run_sudo\|sudo_begin\|pkg_install\|chsh' lib/units/*.sh
    //
    // packages, optional and gpu install with pacman, which goes through
    // run_sudo in lib/pkg.sh. services-system enables system units with
    // run_sudo directly. aur-patched calls sudo_begin itself, because makepkg
    // -i runs `pacman -U` through sudo at the end of a build and no wrapper in
    // this repository can get in front of that.
    //
    // `shell` IS IN THIS LIST AND IS NOT ABOUT ROOT. chsh authenticates the
    // USER through PAM and will not take a cached sudo ticket -- its own unit
    // file says so out loud. It needs a terminal for the same reason the
    // others do: something has to type a password into it.
    readonly property var terminalUnits: ["packages", "optional", "gpu", "aur-patched",
                                          "services-system", "shell"]

    function needsTerminal(id: string): bool {
        return root.terminalUnits.indexOf(id) >= 0;
    }

    // THE ONE UNIT NOTHING OFFERS TO APPLY. `etc` stopped writing anything: it
    // diffs system/ against /etc, reports what differs and prints the command,
    // because half of those files describe one machine and pacman owns the
    // other half. Its state is always `na`, so it never counts as outstanding
    // either -- this list is here so the page can say why, rather than leaving
    // a row with no action looking broken.
    readonly property var reportOnlyUnits: ["etc"]

    function isReportOnly(id: string): bool {
        return root.reportOnlyUnits.indexOf(id) >= 0;
    }

    // What this shell may run itself: ticked, not already in place, and with
    // no password anywhere in it.
    readonly property var runnableNow: {
        const out = [];

        for (const unit of (root.outstandingUnits ?? [])) {
            if (root.needsTerminal(unit.id) || root.isReportOnly(unit.id))
                continue;
            if (!root.unitWanted(unit.id))
                continue;
            out.push(unit.id);
        }

        return out;
    }

    // And what it must hand over. The same tests, the other way round.
    readonly property var runnableInTerminal: {
        const out = [];

        for (const unit of (root.outstandingUnits ?? [])) {
            if (!root.needsTerminal(unit.id))
                continue;
            if (!root.unitWanted(unit.id))
                continue;
            out.push(unit.id);
        }

        return out;
    }

    // ---------------- The profile ----------------
    //
    // ${XDG_STATE_HOME}/dotfiles-profile, TSV, one key<TAB>value per line,
    // sorted. It is what `update` reads, and writing it from here is what
    // makes a tick in this window and a tick in the terminal menu the same
    // act -- which is this repository's stated rule for everything bin/ owns:
    // any of it can be driven from a terminal and the settings window follows.
    //
    // WRITTEN WHOLE AND SORTED, because lib/state.sh writes it whole and
    // sorted, and a file the two ends rewrite in different orders produces a
    // reshuffle in git for a one-value change.
    //
    // COMMENT LINES DO NOT SURVIVE A WRITE. Neither do they survive one from
    // the CLI -- state_save prints the map it holds and nothing else -- but it
    // is the one way this file is lossy, so it is said out loud.
    FileView {
        id: profileFile

        path: `${Config.stateDir}/dotfiles-profile`
        watchChanges: true

        // A missing file is a valid profile and not an error; lib/state.sh
        // opens with that sentence. It is what a machine that has never opened
        // the menu looks like.
        printErrors: false

        // Through a temporary file and one rename, which is the rule the CLI
        // follows for this exact file: a profile truncated halfway through
        // comes back as something that parses perfectly and says something
        // nobody chose.
        atomicWrites: true

        onFileChanged: reload()

        // THE WRITE THIS SHELL JUST MADE IS NOW ON DISK, so the file is the
        // authority again and the copy held in memory can go. Cleared on
        // `loaded` and not on `fileChanged`: the second fires before the new
        // text has been read, and dropping the copy there would leave one
        // frame in which the boxes show the file as it was a moment ago.
        onLoaded: root.written = null
    }

    // WHAT THIS SHELL WROTE, UNTIL THE FILE CATCHES UP -- and this is a bug
    // fixed rather than a nicety. A FileView write is asynchronous: setText
    // returns, the write happens, the watcher fires, the file is re-read, and
    // only then does text() answer differently. Two clicks inside that window
    // -- ticking a pack and then a package in it, which is the ordinary way to
    // use the section below -- both read the OLD text, so the second write
    // rebuilt the file without the first one in it. Measured: ticking
    // `gaming` and then unticking `steam` in the same tick produced a profile
    // holding `pkg.gaming.steam 0` and no `group.gaming` at all.
    //
    // Null except during that window. The file wins the moment it can, so a
    // `./install.sh` run in a terminal still moves the boxes here -- what this
    // does not do is let an asynchronous read overwrite a decision somebody
    // has already made.
    property var written: null

    // Parsed as a BINDING on the file's text, the same shape Theme uses for
    // colors.json: reload() re-evaluates it, so a `./install.sh` run in a
    // terminal moves the boxes in this window without anything being told.
    readonly property var fileProfile: {
        const map = ({});

        for (const line of (profileFile.text() || "").split("\n")) {
            const tab = line.indexOf("\t");
            if (tab < 0)
                continue;

            const key = line.slice(0, tab);
            if (key === "" || key.startsWith("#"))
                continue;

            map[key] = line.slice(tab + 1);
        }

        return map;
    }

    readonly property var profile: root.written ?? root.fileProfile

    function profileGet(key: string, fallback: string): string {
        const value = root.profile[key];
        return value === undefined ? fallback : value;
    }

    function profileSet(key: string, value: string): void {
        const next = Object.assign({}, root.profile);
        next[key] = value;

        // Held in memory as well as written, so that the click after this one
        // builds on it rather than on a file that has not been re-read yet.
        // See `written` above for the bug this is the fix for.
        root.written = next;

        const lines = [];
        for (const name of Object.keys(next))
            lines.push(`${name}\t${next[name]}`);

        // sort() with no comparator is UTF-16 code-unit order, which for the
        // ASCII these keys are made of is byte order -- the same order
        // `LC_ALL=C sort` gives the CLI, so the two ends produce the same file.
        lines.sort();
        profileFile.setText(lines.join("\n") + "\n");
    }

    // The three questions lib/state.sh answers, with the same defaults, so a
    // box in this window and a box in the terminal menu mean the same thing. A
    // unit nobody has answered for is wanted; a group nobody has answered for
    // is not, because the packs are opt-in.
    function unitWanted(id: string): bool {
        return root.profileGet(`unit.${id}`, "1") === "1";
    }

    function setUnitWanted(id: string, wanted: bool): void {
        root.profileSet(`unit.${id}`, wanted ? "1" : "0");
    }

    function groupWanted(group: string): bool {
        return root.profileGet(`group.${group}`, "0") === "1";
    }

    function setGroupWanted(group: string, wanted: bool): void {
        root.profileSet(`group.${group}`, wanted ? "1" : "0");
    }

    // A package with no line of its own follows its group. That rule is what
    // keeps the file short and what lets a package added to a list in a later
    // release reach every machine that ticked the pack.
    function pkgWanted(group: string, name: string): bool {
        return root.profileGet(`pkg.${group}.${name}`,
                               root.groupWanted(group) ? "1" : "0") === "1";
    }

    function setPkgWanted(group: string, name: string, wanted: bool): void {
        root.profileSet(`pkg.${group}.${name}`, wanted ? "1" : "0");
    }

    // How many of a pack's packages this machine has asked for. The drill-down
    // is only worth opening when it disagrees with the box above it, and this
    // is what lets the row say so.
    function pkgWantedCount(group: var): int {
        let n = 0;

        for (const name of (group.packages ?? []))
            if (root.pkgWanted(group.name, name))
                n += 1;

        return n;
    }

    // ---------------- The optional packs ----------------
    //
    // Names, one-line descriptions and contents of packages/optional/*.txt, so
    // that the drill-down can exist. No mode of install.sh prints this:
    // `optional_groups` and `pkg_read_list` are shell functions, and the CLI
    // has no surface that hands them over.
    property var groups: []

    // ---------------- Talking to the engine ----------------

    function check(): void {
        if (root.checking || !root.repoKnown)
            return;

        root.checking = true;
        checker.running = true;
    }

    // The same thing, for a caller that fires on an event it does not control
    // -- the settings page coming on screen, which happens every time somebody
    // clicks past it in the rail. Three seconds of pacman per glance down a
    // list of pages is a cost with nothing to show for it: the answer cannot
    // have changed in the ten seconds since the last one unless this window
    // changed it, and the paths that do change it call check() directly.
    function checkIfStale(): void {
        if (Date.now() - root.checkedAt < 10000)
            return;

        root.check();
    }

    // What this shell may do itself. `apply` and not `update`, and the
    // difference is the whole privilege rule: `update` applies everything the
    // profile wants, which on this machine includes pacman, and a pacman
    // behind a Process with no terminal attached is a sudo prompt nobody can
    // answer. `apply` runs exactly the units it is handed.
    //
    // It also does not pull in their requirements. That is `apply`'s
    // documented behaviour and it is the right one here: what the page lists
    // is what runs, and anything missing underneath is named on screen by the
    // CLI itself rather than being smuggled into the run.
    //
    // NOTHING DESTRUCTIVE CAN HAPPEN DOWN HERE WITHOUT SOMEBODY SAYING SO, and
    // that falls out of the CLI rather than out of anything this file does. A
    // Process has no terminal attached, ui_confirm sees no tty and takes the
    // question's default, and the default for anything destructive is no. The
    // one question in the set is `symlinks` offering to move files that are in
    // the way into a timestamped folder: with nothing to answer on, it
    // declines, stops, and says why -- and the reason lands in `log` below,
    // where the page shows it. Measured with --dry-run against a checkout with
    // 184 files in the way; nothing was moved and the account of it was
    // readable on the page.
    function applyHere(): void {
        if (root.applying || !root.repoKnown || root.runnableNow.length === 0)
            return;

        root.log = "";
        root.applying = true;
        applier.command = ["./install.sh", "apply"].concat(root.runnableNow);
        applier.running = true;
    }

    property bool applying: false

    // Everything the run printed, for the page to show. A settings window that
    // hides what a command said is a settings window somebody has to leave in
    // order to find out what happened.
    property string log: ""

    // THE HANDOFF. kitty, because that is this setup's terminal everywhere
    // else: hyprland.lua names it, niri's config names it, the launcher spawns
    // terminal entries with it, and the bluetooth page opens bluetoothctl the
    // same way.
    //
    // --hold, because otherwise the window closes on the last line of output
    // and takes the account of what happened with it. A run that asks for a
    // password and then vanishes is the worst of both worlds.
    //
    // --directory rather than an absolute path to the script, so that what is
    // on screen in that terminal is exactly the command a person would have
    // typed: `./install.sh apply packages`. Somebody watching it should be
    // able to run it again without translating anything.
    //
    // execDetached and not a Process: the terminal must outlive this shell. A
    // `git pull` that changes a .qml file reloads Quickshell, and a
    // half-finished pacman transaction dying with it is not a trade anybody
    // would take.
    function handOff(ids: var): void {
        if (!root.repoKnown || ids.length === 0)
            return;

        Quickshell.execDetached(["kitty", "--hold", "--directory", root.repoDir,
                                 "-e", "./install.sh", "apply"].concat(ids));
    }

    // ---------------- Opening the page ----------------
    //
    // THE PAGE'S POSITION IN THE RAIL IS NOT KNOWABLE FROM HERE. It is an
    // index into the list Settings.qml builds by walking its pages and
    // dropping the ones that are not available on this machine, so it moves
    // with the compositor; and the pages are built lazily, on the first
    // opening of the window, so before that there is nothing to ask.
    //
    // So the page reports where it landed, and a request that arrives before
    // it exists is held until it does. One latch, and no number written down
    // anywhere.
    property int pageIndex: -1
    property bool pageWanted: false

    function registerPage(index: int): void {
        root.pageIndex = index;

        if (root.pageWanted) {
            root.pageWanted = false;
            SettingsState.currentPage = index;
        }
    }

    function openPage(): void {
        if (root.pageIndex >= 0) {
            SettingsState.open(root.pageIndex);
            return;
        }

        root.pageWanted = true;
        SettingsState.isOpen = true;
    }

    // ---------------- Processes ----------------

    Process {
        id: finder

        running: true

        // One shell, because this is a loop and a test rather than a command.
        // $1 is the shell's own root file as Quickshell resolved it -- through
        // ~/.config/quickshell, which is a symlink into the clone -- and
        // readlink -f is what turns that into a path inside the repository.
        //
        // Both tests, not just install.sh: a directory can hold a script by
        // that name and be something else entirely, and lib/units is the part
        // that makes it this repository.
        command: ["sh", "-c",
            'd=$(dirname "$(readlink -f "$1")"); ' +
            'while [ "$d" != "/" ]; do ' +
            '  if [ -x "$d/install.sh" ] && [ -d "$d/lib/units" ]; then echo "$d"; exit 0; fi; ' +
            '  d=$(dirname "$d"); ' +
            'done; ' +
            'exit 1',
            "installer-find", Quickshell.shellPath("shell.qml")]

        stdout: StdioCollector {
            onStreamFinished: {
                root.repoDir = text.trim();

                if (root.repoDir === "")
                    return;

                groupQuery.running = true;
                firstCheck.start();
            }
        }
    }

    Process {
        id: checker

        workingDirectory: root.repoDir
        command: ["./install.sh", "check", "--json"]

        stdout: StdioCollector {
            id: checkOut
        }

        stderr: StdioCollector {
            id: checkErr
        }

        // EXIT 1 IS NOT A FAILURE HERE. `check` exits 1 whenever a unit that
        // applies to this machine is not ok, which is precisely the state this
        // widget exists to show. What counts as a failure is output that is
        // not a table: no /etc/arch-release, a broken clone, a unit file that
        // crashed the shell it was sourced into.
        onExited: {
            root.checking = false;

            let parsed;
            try {
                parsed = JSON.parse(checkOut.text || "[]");
            } catch (e) {
                console.warn("InstallerState: could not parse check --json --", e.message);
                root.checkError = checkErr.text.trim() || e.message;
                return;
            }

            if (!Array.isArray(parsed)) {
                root.checkError = "check --json did not print an array";
                return;
            }

            root.checkError = "";
            root.units = parsed;
            root.checkedAt = Date.now();
        }
    }

    Process {
        id: applier

        workingDirectory: root.repoDir

        stdout: StdioCollector {
            id: applyOut
        }

        stderr: StdioCollector {
            id: applyErr
        }

        onExited: {
            root.applying = false;

            // Both streams, in that order, with the colour codes taken out:
            // this is a Text item and not a terminal, and it would otherwise
            // draw them as a literal "ESC[1;31m". The escape is written as a
            // numeric escape and never pasted in as itself, which is the rule
            // Icons.qml states for glyphs and which holds here for the same
            // reason: a control character sitting in a source file does not
            // survive every editor it passes through, and when it is lost
            // nothing errors -- the pattern simply stops matching. install.sh
            // prints its headings and its notices to stderr, so dropping
            // either stream would leave half a story.
            root.log = [applyOut.text, applyErr.text]
                .join("\n")
                .replace(/\u001b\[[0-9;]*m/g, "")
                .trim();

            // The table on screen is about to be wrong, and it is the one
            // thing the person just changed. Re-read rather than assume: a
            // unit that failed is still not ok, and a page that painted
            // success on click would be reporting its own intention back to
            // itself.
            root.check();
        }
    }

    Process {
        id: groupQuery

        workingDirectory: root.repoDir

        // Three kinds of record, tab separated:
        //
        //   group<TAB>name<TAB>
        //   sum<TAB>group<TAB>one line of the list's own description
        //   pkg<TAB>group<TAB>package
        //
        // THE PACKAGE sed IS lib/pkg.sh's, copied rather than re-invented --
        // pkg_read_list, at the top of that file. If it ever changes, this is
        // the second place. Three expressions of sed is the smaller evil
        // against a settings page that disagrees with the installer about what
        // is in a pack.
        //
        // THE DESCRIPTION IS NOT pkg_list_summary's, and that is deliberate.
        // That function takes line one, which is right for a one-line hint at
        // a terminal and wrong for a paragraph in a window: four of the six
        // lists open with a sentence that wraps onto a second comment line, so
        // line one on its own ends mid-clause -- "borgmatic for the". The
        // leading block of comment down to the first blank one is the sentence
        // whoever wrote the list actually wrote, and it arrives here a line at
        // a time to be joined below.
        //
        // THE TWO `q` EXPRESSIONS COME BEFORE THE SUBSTITUTION, which is not a
        // style choice: sed applies every expression to the pattern space as
        // it stands, so stripping the leading "# " first turns the very next
        // line into one that matches /^[^#]/ and quits after one line. That is
        // the bug this ordering is the fix for, and it looked exactly like a
        // truncated sentence.
        command: ["sh", "-c",
            'for f in packages/optional/*.txt; do ' +
            '  [ -f "$f" ] || continue; ' +
            '  g=$(basename "$f" .txt); ' +
            '  printf "group\\t%s\\t\\n" "$g"; ' +
            '  sed -n -e "/^#[[:space:]]*$/q" -e "/^[^#]/q" ' +
            '         -e "s/^#[[:space:]]*//;s/[[:space:]]*$//;p" "$f" | ' +
            '    while IFS= read -r line; do printf "sum\\t%s\\t%s\\n" "$g" "$line"; done; ' +
            '  sed -e "s/#.*//" -e "s/[[:space:]]*$//" -e "/^[[:space:]]*$/d" "$f" | ' +
            '    while IFS= read -r p; do printf "pkg\\t%s\\t%s\\n" "$g" "$p"; done; ' +
            'done']

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const byName = ({});

                for (const line of (text || "").split("\n")) {
                    const cell = line.split("\t");
                    if (cell.length < 3)
                        continue;

                    if (cell[0] === "group") {
                        byName[cell[1]] = ({ name: cell[1], summary: "", packages: [] });
                        out.push(byName[cell[1]]);
                    } else if (!byName[cell[1]]) {
                        continue;
                    } else if (cell[0] === "sum") {
                        // Joined with a space, because what was split was a
                        // sentence wrapped across comment lines and not a list.
                        const group = byName[cell[1]];
                        group.summary = group.summary === "" ? cell[2] : `${group.summary} ${cell[2]}`;
                    } else if (cell[0] === "pkg") {
                        byName[cell[1]].packages.push(cell[2]);
                    }
                }

                root.groups = out;
            }
        }
    }

    // ---------------- When it checks ----------------

    // NOT AT ZERO. The shell reloads on every saved .qml file and starts with
    // the session; three seconds of pacman and find competing with the bar
    // being drawn is three seconds nobody asked for, at the worst moment. By
    // the time this fires the desktop is up and the cost is invisible.
    Timer {
        id: firstCheck

        interval: 15000
        repeat: false
        onTriggered: root.check()
    }

    // ON WAKE, WITHOUT A SIGNAL THAT SAYS SO. logind announces suspend and
    // resume over D-Bus, and Quickshell 0.3 exposes no general D-Bus client,
    // so this reads the clock instead: a timer that should have fired sixty
    // seconds ago and fires ten minutes late did not run slowly -- it was not
    // running, and the machine was asleep.
    //
    // The heartbeat costs one comparison a minute and starts nothing. Five
    // minutes is well clear of any scheduling delay a desktop produces and
    // well inside the shortest nap anybody takes.
    Timer {
        id: wakeTimer

        property double last: Date.now()

        interval: 60000
        repeat: true
        running: true

        onTriggered: {
            const now = Date.now();
            const asleep = now - wakeTimer.last > 5 * 60 * 1000;

            wakeTimer.last = now;

            if (asleep)
                root.check();
        }
    }

    // ---------------- From a terminal ----------------
    //
    // The same rule as everything else this desktop can be told to do: if the
    // window can do it, a line in a terminal can do it too.
    IpcHandler {
        target: "updates"

        function check(): void {
            root.check();
        }

        function open(): void {
            root.openPage();
        }

        function status(): string {
            if (!root.repoKnown)
                return "no clone found from this shell's own path";
            if (root.checkError !== "")
                return `check failed: ${root.checkError}`;
            if (!root.ready)
                return "not checked yet";
            if (root.outstanding === 0)
                return "everything applicable is in place";

            const names = (root.outstandingUnits ?? []).map(unit => unit.id).join(" ");
            return `${root.outstanding} unit(s) need attention: ${names}`;
        }
    }
}
