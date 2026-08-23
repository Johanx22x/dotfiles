// WHICH THEME DRAWS THE DESKTOP, AND WHERE ITS FILES ARE.
//
// A theme is a directory under themes/ with a manifest.json in it. This
// singleton turns the NAME in Config.theme into the URLs the shell loads its
// surfaces from, and is the only place that knows how that name becomes a
// path. themes/genesis/README.md is what a theme is; this is how one is found.
//
// THE SURFACES ARE LOADED BY PATH AND NOT IMPORTED, which is the whole point
// and has consequences that are not obvious. shell.qml used to say
// `import qs.themes.genesis.bar` and instantiate a Bar; it now instantiates a
// ThemeSurface whose `file` is "bar/Bar.qml". It still IMPORTS the theme's
// directories -- that is what keeps them watched, and the header there says
// why -- but an import is not an instantiation: no line in shell.qml builds a
// type out of a theme, and which theme is drawn is decided here at runtime.
// What follows is what that costs and what it buys, all of it measured against
// Quickshell 0.3.1 in a headless compositor rather than assumed.
//
// NO BRACES ANYWHERE ABOVE `pragma Singleton`, and that is not a style rule.
// A curly brace inside this header is enough for Quickshell to build the
// singleton with none of its members on it -- the shell still loads, and every
// call into it says "is not a function" instead. It cost a test run here.
//
// A LOADED WINDOW IS A REAL WINDOW. A PanelWindow is a plain QObject in
// Quickshell -- ProxyWindowBase descends from Reloadable, not from Item -- so
// a Loader can hold one, and the layer surface it maps is indistinguishable
// from one declared straight into shell.qml. Loading one from a Variants over
// Screens.barScreens works too, and the screen arrives with it: see
// modules/ThemeSurface.qml for why that has to be an initial property rather
// than an assignment afterwards.
//
// A file:// URL, WHICH IS NOT A WORKAROUND AND IS WORTH SAYING SO. It reads
// like one -- most of this tree is spelled `qs.something` -- but there is no
// second scheme it is standing in for. Loader.setSource takes a URL and a
// module import is not one, and Quickshell 0.3.1 hands its files to the engine
// as ordinary file:// URLs -- `Qt.resolvedUrl(".")` inside shell.qml comes
// back as "file://" followed by exactly what `Quickshell.shellDir` returns,
// measured. So `"file://" + shellPath(...)` is not an escape from the qs:
// tree, it is how you spell the URL of a file in this tree at all. The
// encodeURI is what a home directory with a space in it needs; that is the
// only trick in the line.
//
// WHAT THE URL BUYS is ordinary QML resolution rules inside a theme: a theme
// file sees its own directory with no import, reaches a sibling directory with
// `import "../island"`, and still reaches the host through `import qs`,
// `import qs.components` and `import qs.modules.*` -- those are real modules on
// the import path and stay resolvable from anywhere. And it is what makes a
// theme directory COPYABLE: nothing inside it spells its own name, so
// `cp -r genesis tokyo` is a second theme rather than a directory full of
// references to the first.
//
// AND WHERE themes/ IS WHEN THIS LOOKS, WHICH IS NOT WHERE THE COPY WAS MADE.
// `Quickshell.shellPath` resolves against `Quickshell.shellDir`, and that is
// the directory the shell was LAUNCHED from -- both compositors run
// `qs -d --no-duplicate` with no `-p`, so it is $XDG_CONFIG_HOME/quickshell.
// That is stow's target and not this repository, and Quickshell 0.3.1 does not
// canonicalize it: a shell.qml reached through a symlink reports the LINK's
// directory as shellDir, measured in a scratch home. install.sh stows
// --no-folding on purpose, so ~/.config/quickshell/themes is a real directory
// holding one symlink per file rather than one link standing for the tree --
// lib/units/40-symlinks.sh says why -- and the consequence lands here: a
// directory ADDED to the checkout has nothing at all on the other side until
// `./install.sh apply symlinks` has run. `cp -r genesis tokyo` is two commands,
// and themes/genesis/README.md is where both of them are written down.
//
// SO AN UNSTOWED THEME IS NOT A GREYED ROW, IT IS NO ROW. The catalogue below
// lists that one directory and there is no second place to look: nothing in
// Quickshell 0.3.1 resolves a symlink -- its qmltypes carry no canonical and no
// readLink -- so finding the checkout from in here would mean spawning a
// process at every startup to ask about a directory this shell never loads
// from, and then a fault the picker has no wording for. `install.sh check` is
// the one thing that can see both sides at once, and it reports exactly this:
// the files a package has that $HOME does not, and the directory they are in.
//
// THE RELATIVE FORM IS NOW A RULE AND NOT A NECESSITY, which changed under it
// and is worth not mistaking. While nothing imported a theme,
// `import qs.themes.genesis.island` from inside one failed with "module is not
// installed" and there was no choice about it. shell.qml imports the theme's
// directories again -- for the watches, see the header there -- so the module
// form resolves once more; it was tried and the shell came up clean. It stays
// out anyway: a theme that spells its own name is a theme that cannot be
// copied, and the copy would quietly draw the original's island.
//
// THE PRICE USED TO BE THE FILE WATCH, and shell.qml is where it is bought
// back. The same startup scan that synthesizes the qmldirs is what registers
// the watches behind hot reload, so for as long as nothing imported a theme,
// editing a file under themes/ reloaded nothing -- no line logged, nothing on
// screen. The import list at the top of shell.qml restores it without giving
// up any of the above: the theme is still loaded by URL and still never named
// by anything that instantiates it, and an edit in each of the eight
// directories under themes/genesis reloads the shell again. What is left of
// the price is that a theme NOT on that list is not watched, which is the
// trade a hand-dropped theme makes and is written out beside the imports.
//
// Three ways of loading were measured on the way here and none of them is what
// decided this -- LazyLoader, BoundComponent and a QtQuick Loader all lose the
// watch, through the qs: tree and through file:// alike. The watch never
// depended on the primitive; it depended on the import.

pragma Singleton
// FOR EXACTLY ONE NESTED COMPONENT, the Instantiator's delegate at the bottom
// of this file, which reads `root` and would otherwise be an unqualified
// access -- qmllint says as much and names this pragma as the answer.
//
// tests/qml-lint.sh DECLINES THIS TREE-WIDE and is right to: 243 of its
// unqualified reads are delegates naming an outer id, the pragma rebinds how
// every one of them captures its context, and a shell that loads cannot tell a
// bound delegate from a broken one. None of that applies to a file whose only
// nested component is being written here, in the same change, with every
// property it takes from the model already declared `required` -- which is
// what Bound asks for. Track.qml is the other singleton that carries it.
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
// For Connections. A singleton that only declares properties does not need
// QtQuick; the handler at the bottom does.
import QtQuick
// For Instantiator, which is a QtQml.Models type and not a QtQuick one -- it
// is what lets a non-visual singleton hold one object per row of a model.
// See the catalogue below.
import QtQml.Models
// Qt's directory listing. Quickshell has no directory API of its own; the
// wallpaper carousel says the same thing next to its own FolderListModel.
import Qt.labs.folderlistmodel
import qs
// AND THE HOST MODULES ONLY A THEME REACHES FOR -- see keptInScope below,
// which is what this import is for and why it is not decoration.
import qs.modules.bar

Singleton {
    id: root

    // THE INTERFACE NUMBER THIS HOST SPEAKS, and a theme's manifest has to
    // claim the same one. It is a promise about the seam rather than about the
    // shell's version: what a theme is handed, what it is expected to draw,
    // and where its files are looked for. The day any of that changes in a way
    // an existing theme cannot survive, this goes to 2 and every theme that
    // has not been updated stops being loaded instead of half-drawing.
    readonly property int interfaceVersion: 1

    // The theme that ships with the shell, and where everything lands when the
    // configured one cannot be used. It is the one name the host is allowed to
    // know -- see the fallback below for the only moment it is spoken.
    readonly property string fallbackName: "genesis"

    // Whether the CONFIGURED theme answered with a manifest this host can use.
    // False only after a failed read or a refused interface number, and reset
    // the moment the setting names something else so a typo corrected is a
    // theme drawn again.
    property bool configuredUsable: true

    // THE THEME BEING DRAWN. Everything that loads a surface reads this and
    // nothing reads Config.theme directly.
    //
    // THE FALLBACK IS NOT TIDINESS. A theme that is not there draws nothing at
    // all: no bar, no launcher, no notifications, no power menu -- a desktop
    // with no way back to the setting that broke it except editing JSON from a
    // terminal that also has no bar. A `git pull` that retires a theme, or a
    // hand-edited config.json with a typo in it, both land there. So a theme
    // whose manifest does not read falls back to the one that ships with the
    // shell, loudly, rather than leaving an empty screen.
    readonly property string name: root.configuredUsable ? Config.theme : root.fallbackName

    // What a picker calls the current theme, out of its manifest. The picker
    // in the settings window reads the catalogue below rather than this, which
    // carries a title per theme; this is still the answer for anything that
    // wants to name the one being drawn without going through a list.
    property string title: ""

    // ---------------- Every theme on disk, and what is wrong with it --------
    //
    // WHY THE SHELL LOOKS RATHER THAN ASKS. The colour schemes next to this in
    // the settings window come out of `desktop-scheme list`, because a scheme
    // is a file in a directory no part of the shell has any business knowing
    // the path of -- the script owns it. A theme is the opposite: it lives in
    // the shell's OWN tree, this singleton is already the one place that turns
    // a name into a path there, and `Quickshell.shellPath` is how it does it.
    // A `desktop-theme list` invented to answer this would be a second opinion
    // about a directory the shell can see, kept in step by hand.
    //
    // AN ENTRY IS name, title AND fault. The name is the directory, which is
    // the whole contract with Config.theme; the title is what the manifest
    // calls itself and what a person reads; the fault is "" for a theme this
    // host can draw and otherwise says why not, which is the picker's business
    // rather than this file's. "interface" is a manifest that reads but claims
    // a number this shell does not speak. "unreadable" is one that is not JSON.
    //
    // A DIRECTORY WITH NO MANIFEST IS NOT A THEME AND IS NOT IN HERE. The
    // header of this file is what says so -- a theme is a directory under
    // themes/ WITH A MANIFEST IN IT -- and the alternative is a picker that
    // offers a build directory somebody left behind. A manifest that is
    // present and wrong is a different thing entirely, and stays: it is
    // somebody's theme, halfway to working, and the picker is the only place
    // they will find out why it is not being drawn.
    //
    // IT IS BUILT AT STARTUP AND NOT WHEN THE PAGE IS OPENED, which is the one
    // place this deliberately does not copy the scheme picker. What that one
    // defers is a PROCESS, and a process is worth deferring. This is a
    // directory listing and one small read per theme -- the same read this
    // file already does for the configured theme, times the two directories
    // that are there -- and having it always be true means the picker has no
    // loading state to be wrong about and no empty list to draw for a frame.
    property var available: []

    // WHAT EACH PROBE LAST ANSWERED, KEYED BY THE PROBE ITSELF. Nothing else
    // is a stable key: the directory NAME is what a rename changes, and the
    // model INDEX is what an insertion changes. The probe object outlives both
    // -- it is created when its directory appears and destroyed when it goes,
    // and everything in between is the same object saying different things.
    //
    // A Map AND NOT AN OBJECT, because the key is a QObject and a plain
    // object's keys are strings: every probe would stringify to the same
    // "QObject(0x...)"-shaped thing or, worse, to different ones per call.
    //
    // WHY IT IS NOT `probes.objectAt(i)` IN A LOOP, which is the obvious
    // shape and was the first one written here. It works, and qmllint reports
    // four `Member "entry" not found on type "QObject"` for it -- objectAt is
    // typed as QObject and the delegate's properties are invisible through it.
    // tests/qml-lint.sh gates that category at the number that is there, so
    // the obvious shape costs four warnings for nothing this cannot do.
    readonly property var entries: new Map()

    // The probe says what it found, or that it found nothing. `entry` is
    // deliberately the whole of the contract: a probe that comes back null
    // has stopped being a theme -- see the delegate.
    function record(probe: QtObject, entry: var): void {
        if (entry)
            root.entries.set(probe, entry);
        else
            root.entries.delete(probe);

        root.rebuild();
    }

    // A directory that went away, which no `entry` change can report because
    // the object holding it is the thing that was destroyed.
    function forget(probe: QtObject): void {
        root.entries.delete(probe);
        root.rebuild();
    }

    // Rebuilt from what the probes hold and never appended to, which is what
    // makes a theme directory RENAMED under a running shell come out right. A
    // list added to as manifests arrived would keep the old name forever, and
    // `count` cannot see a rename either -- tests/qml-rules.sh carries the
    // whole story of that against the wallpaper carousel.
    //
    // DE-DUPLICATED BY NAME, which only a directory changing under the shell
    // can need. Two probes answering with the same theme is what a rename
    // looks like for the frame between the model re-sorting and the moved
    // directory's manifest being read again -- it was watched happening. A
    // list that shows one theme twice is wrong in a way a list that is briefly
    // one short is not, and both are gone by the next read.
    //
    // SORTED HERE AND NOT BY THE MODEL. The model is sorted too -- see its
    // `sortField` -- but a Map keeps insertion order, and a theme added to a
    // running shell is inserted last however its directory sorts.
    function rebuild(): void {
        const list = [];
        const seen = ({});

        for (const entry of root.entries.values()) {
            if (seen[entry.name])
                continue;

            seen[entry.name] = true;
            list.push(entry);
        }

        list.sort((first, second) => first.name < second.name ? -1
            : first.name > second.name ? 1 : 0);
        root.available = list;
    }

    // ONE READING OF A MANIFEST, USED TWICE. adoptManifest below decides
    // whether the CONFIGURED theme can be drawn and falls back when it cannot;
    // this decides the same thing for every theme on disk so the picker can
    // say so before anybody clicks. Two copies of the interface check would be
    // two answers to "can this host draw that theme", and the day they
    // disagreed the picker would offer a theme that falls straight back.
    //
    // `declaredInterface` and `declaredName` are what the file claimed, kept
    // because adoptManifest's warnings quote both and a caller that only wants
    // to draw a row can ignore them.
    function describe(name: string, text: string): var {
        let manifest = null;

        try {
            manifest = JSON.parse(text);
        } catch (error) {
            return {
                name: name,
                title: name,
                declaredName: undefined,
                declaredInterface: undefined,
                fault: "unreadable"
            };
        }

        return {
            name: name,
            title: manifest.title || name,
            declaredName: manifest.name,
            declaredInterface: manifest.interface,
            fault: manifest.interface === root.interfaceVersion ? "" : "interface"
        };
    }

    // THE HOST MODULES A THEME IMPORTS AND NOTHING ELSE DOES, HELD IN SCOPE.
    //
    // The startup scan that decides which directories become modules follows
    // the imports out of shell.qml, so a host module whose only importer is a
    // theme is a directory the scan reaches only if that theme is on the import
    // list -- and `import qs.modules.bar` from inside a theme it never reached
    // fails with "module is not installed" at the moment the widget that wanted
    // it is drawn. modules/bar is exactly that: one singleton, BatteryAlerts,
    // read by the bar's two battery widgets and by nothing in the host.
    //
    // shell.qml importing themes/genesis/bar would now cover THIS theme by
    // accident -- deleting the line below and loading the tree comes up clean,
    // measured. It stays because the accident is the whole problem. A theme
    // dropped into themes/ by hand is not on that import list and a theme that
    // drops the two battery widgets stops importing modules/bar at all, and in
    // either case the next theme to reach for it would find it gone. This line
    // is the host saying which modules are part of the seam rather than leaving
    // it to who happened to import what, and the next host module a theme
    // reaches for belongs on it.
    //
    // NOTHING IS STARTED BY BEING NAMED. BatteryAlerts is thresholds and
    // formatting -- no timer, no process, no connection -- so building it early
    // costs one object and changes nothing. A module that DID start something
    // would want the `armed` treatment shell.qml gives the services instead.
    readonly property var keptInScope: [BatteryAlerts]

    // THE URL OF ONE FILE INSIDE THE CURRENT THEME, which is the only thing
    // this singleton is asked for at runtime. `file` is a path relative to the
    // theme directory, "bar/Bar.qml" and the like.
    //
    // encodeURI because the result is a URL and Quickshell.shellPath returns a
    // filesystem path: a home directory with a space in it would otherwise
    // produce a URL that silently loads nothing.
    function surface(file: string): string {
        return "file://" + encodeURI(Quickshell.shellPath(`themes/${root.name}/${file}`));
    }

    // Reading the manifest, which is the one thing a theme has to have. The
    // reading itself is describe() above; what is left here is the half that
    // only the CONFIGURED theme has -- the fallback, and the warnings that say
    // why the desktop is not the one that was asked for.
    function adoptManifest(text: string): void {
        const described = root.describe(Config.theme, text);

        if (described.fault === "unreadable") {
            console.warn(`Themes: ${Config.theme}/manifest.json is not JSON, falling back to ${root.fallbackName}`);
            root.configuredUsable = false;
            return;
        }

        if (described.fault !== "") {
            console.warn(`Themes: ${Config.theme} speaks interface ${described.declaredInterface} and this shell speaks ${root.interfaceVersion}, falling back to ${root.fallbackName}`);
            root.configuredUsable = false;
            return;
        }

        // NOT FATAL, and deliberately so: the directory is what the shell
        // loads from and the manifest's own name is a label. It is worth
        // saying out loud all the same, because a theme copied from another
        // one and left with the original's manifest is exactly the mistake
        // nothing else here would notice.
        if (described.declaredName !== Config.theme)
            console.warn(`Themes: themes/${Config.theme} carries a manifest calling itself "${described.declaredName}"`);

        root.title = described.title;
        root.configuredUsable = true;
    }

    // THE MANIFEST FOLLOWS Config.theme AND NOT root.name, which is what keeps
    // the fallback from chasing its own tail: when the configured theme is
    // refused, `name` moves to the built-in one while this stays pointed at
    // the setting, so correcting the setting is what re-reads a manifest.
    //
    // It is read asynchronously, and nothing waits for it. The surfaces are
    // built from Config.theme the instant the shell starts -- see the note on
    // the default in Config.qml -- and this arrives a moment later to say
    // whether that was the right thing to build.
    FileView {
        id: manifestFile

        path: Quickshell.shellPath(`themes/${Config.theme}/manifest.json`)
        printErrors: false

        onLoaded: root.adoptManifest(manifestFile.text())
        // THE PATH AND NOT THE NAME, and it is the one line here where the
        // difference matters. This is the failure of a file that is not there,
        // and `themes/tokyo/manifest.json` reads like the checkout somebody
        // just copied a directory into -- which is the exact wrong place to
        // send them looking. The absolute path says out loud that the shell
        // read ~/.config/quickshell, and the header above says why. Every other
        // warning in this file names the theme instead: those manifests were
        // read, and what is wrong with them is not where they are.
        onLoadFailed: {
            console.warn(`Themes: ${manifestFile.path} cannot be read, falling back to ${root.fallbackName}`);
            root.configuredUsable = false;
        }
    }

    // THE DIRECTORIES UNDER themes/, WHICH IS THE WHOLE OF THE DISCOVERY.
    // Spelled the same way surface() spells a file inside a theme, and for the
    // same reason its note gives: a filesystem path is not a URL, and a home
    // directory with a space in it is what the encodeURI is for.
    //
    // NO onStatusChanged, and tests/qml-rules.sh is the file to read before
    // deciding that is an omission. Its rule is about a model whose rows are
    // pulled out with `get()`, where a rename changes every path and never
    // moves `count`, so a listing driven off the count goes stale. Nothing
    // here calls get(): the rows are read by the Instantiator below, and the
    // signal the rule says the count misses is the one an Instantiator acts
    // on -- whether it moves a delegate's `fileName` or builds a new delegate
    // beside the old one, rebuild() below is written to come out right either
    // way, because what it reads is the set of probes that exist.
    //
    // MEASURED RATHER THAN REASONED: `themes/ancient` renamed to
    // `themes/elder` under a running shell left exactly one entry, under the
    // new name, still carrying the manifest's own "ancient" and still refused
    // for its interface number. No restart, no stale row.
    FolderListModel {
        id: folder

        folder: "file://" + encodeURI(Quickshell.shellPath("themes"))
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        // So the picker is in a stable order rather than in whatever order the
        // filesystem hands them back, which is not the same twice.
        sortField: FolderListModel.Name
    }

    // ONE MANIFEST READER PER DIRECTORY, HELD OPEN. An Instantiator and not a
    // Repeater because this is a singleton and not an Item -- a Repeater needs
    // a visual parent and there is none here, while an Instantiator builds
    // plain objects and is exactly the QtQml half of the same idea.
    //
    // ONE PER DIRECTORY AND NOT ONE FileView MOVED DOWN THE LIST, and that is
    // measured rather than preferred. The tidy version is a single reader with
    // `blockLoading` -- Theme.qml reads a theme's theme.json exactly that way,
    // one file, synchronously, and says why next to it -- walked down the
    // directories in a loop, reading text() at each. It does not work and it
    // does not say so: `blockLoading` blocks the FIRST load, and MOVING the
    // path afterwards schedules an asynchronous reload while text() keeps
    // answering out of the buffer it already had. A probe over four
    // directories returned the first one's manifest four times, so every theme
    // on the machine was called by the first theme's title and given the first
    // theme's interface number. Nothing was logged. A reader whose path is set
    // once and never moved has no such state to be stale.
    //
    // AND WHY EACH ONE STAYS RATHER THAN A QUEUE. A queue would need to know
    // when to start, when it had finished, and what to do about the directory
    // changing halfway through -- three pieces of state, all of them mine to
    // keep right. This has none: a directory appears and a reader appears with
    // it, a directory goes and its reader goes with it.
    //
    // NOTHING WATCHES A MANIFEST FOR CHANGES, only the directory it is in. An
    // edit under themes/ already needs the restart this file documents, and
    // Theme.qml declines to watch a theme's tokens for the same reason: half
    // an edit landing live, over QML that did not reload, is worse than none.
    Instantiator {
        id: probes

        model: folder

        delegate: QtObject {
            id: probe

            // FolderListModel's own roles. `required` is what makes them
            // arrive at all in a delegate that is not a visual one, and it is
            // what `pragma ComponentBehavior: Bound` at the top asks for.
            required property string fileName
            required property string filePath

            // What describe() made of this directory's manifest, or null for a
            // directory that has none -- which is a directory that is NOT A
            // THEME, and the reason there is no third state for "missing". The
            // header says it: a theme is a directory under themes/ with a
            // manifest in it, and the alternative is a picker offering
            // somebody's leftover build directory.
            property var entry: null
            onEntryChanged: root.record(probe, probe.entry)

            // The catalogue is keyed by this object, so its going away is an
            // event in its own right -- see forget().
            Component.onDestruction: root.forget(probe)

            readonly property FileView manifest: FileView {
                id: probeFile

                path: `${probe.filePath}/manifest.json`
                // A directory that is not a theme is the ordinary case here,
                // not an error worth a line in the log. adoptManifest above is
                // where a theme that was actually ASKED for gets said out loud.
                printErrors: false

                onLoaded: probe.entry = root.describe(probe.fileName, probeFile.text())
                onLoadFailed: probe.entry = null
            }
        }
    }

    // A NEW NAME IS INNOCENT UNTIL ITS MANIFEST SAYS OTHERWISE. Without this,
    // one refused theme would leave the shell pinned to the fallback for the
    // rest of the session however many times the setting was corrected.
    Connections {
        target: Config

        function onThemeChanged(): void {
            root.configuredUsable = true;
        }
    }
}
