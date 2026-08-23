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

import Quickshell
import Quickshell.Io
// For Connections. A singleton that only declares properties does not need
// QtQuick; the handler at the bottom does.
import QtQuick
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

    // What a picker would call the current theme, out of its manifest. Nothing
    // draws it yet -- there is one theme and no picker -- but the manifest is
    // parsed here anyway to check the interface number, and publishing what
    // was parsed is better than reading it and dropping it on the floor.
    property string title: ""

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

    // Reading the manifest, which is the one thing a theme has to have.
    function adoptManifest(text: string): void {
        let manifest = null;

        try {
            manifest = JSON.parse(text);
        } catch (error) {
            console.warn(`Themes: ${Config.theme}/manifest.json is not JSON, falling back to ${root.fallbackName}`);
            root.configuredUsable = false;
            return;
        }

        if (manifest.interface !== root.interfaceVersion) {
            console.warn(`Themes: ${Config.theme} speaks interface ${manifest.interface} and this shell speaks ${root.interfaceVersion}, falling back to ${root.fallbackName}`);
            root.configuredUsable = false;
            return;
        }

        // NOT FATAL, and deliberately so: the directory is what the shell
        // loads from and the manifest's own name is a label. It is worth
        // saying out loud all the same, because a theme copied from another
        // one and left with the original's manifest is exactly the mistake
        // nothing else here would notice.
        if (manifest.name !== Config.theme)
            console.warn(`Themes: themes/${Config.theme} carries a manifest calling itself "${manifest.name}"`);

        root.title = manifest.title || Config.theme;
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
        onLoadFailed: {
            console.warn(`Themes: themes/${Config.theme}/manifest.json cannot be read, falling back to ${root.fallbackName}`);
            root.configuredUsable = false;
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
