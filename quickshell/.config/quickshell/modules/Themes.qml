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
// ThemeSurface whose `file` is "bar/Bar.qml", and never names a theme at all.
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
// A file:// URL AND NOT A MODULE PATH, and this is the part that was found the
// hard way. Quickshell resolves `import qs.anything` through qmldir files it
// SYNTHESIZES at startup, and it synthesizes one only for directories it
// reached by following the imports out of shell.qml. Nothing imports a theme
// any more, so nothing walks its directories, so inside the qs: module tree a
// theme file cannot see its own siblings: `import qs.themes.genesis.island`
// from a theme loaded by path fails with "module is not installed", and even
// a file in the same directory is "not a type".
//
// Loading the file through an explicit file:// URL steps outside that tree and
// puts ordinary QML rules back: a theme file sees its own directory with no
// import, reaches a sibling directory with `import "../island"`, and still
// reaches the host through `import qs`, `import qs.components` and
// `import qs.modules.*` -- those are real modules on the import path and stay
// resolvable from anywhere. It is also what makes a theme directory COPYABLE:
// nothing inside it spells its own name, so `cp -r genesis tokyo` is a second
// theme rather than a directory full of references to the first.
//
// AND THE PRICE, WHICH IS THE FILE WATCH. The same startup scan that
// synthesizes the qmldirs is what registers the file watches behind
// Quickshell's hot reload, so a directory nothing imports is a directory
// nothing watches. Editing a file under themes/ no longer reloads the shell --
// no reload is logged and nothing on screen changes -- while editing anything
// under modules/, components/ or this file still does. Restarting is what
// picks a theme edit up:
//
//   qs kill && qs -d --no-duplicate
//
// which is the same restart shell.qml's header already asks for after a pull,
// for a related reason. Three ways of loading were measured and all three lose
// the watch -- LazyLoader, BoundComponent and a QtQuick Loader, through the qs:
// tree and through file:// alike -- so it is the price of loading by name and
// not of the primitive chosen to do it.

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
    // the imports out of shell.qml, and a theme is no longer on that path -- so
    // a host module whose only importer is a theme is a directory the scan
    // never reaches, and `import qs.modules.bar` from inside a theme fails with
    // "module is not installed" at the moment the widget that wanted it is
    // drawn. modules/bar is exactly that: one singleton, BatteryAlerts, read by
    // the bar's two battery widgets and by nothing in the host.
    //
    // Naming it here is what keeps the module real. It is the host saying which
    // modules are part of the seam rather than an accident of who imported
    // what, and the next host module a theme reaches for belongs on this line.
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
