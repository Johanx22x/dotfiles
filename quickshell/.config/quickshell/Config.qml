// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// QUICKSHELL - user preferences
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// The handful of decisions that are a matter of taste rather than of design,
// kept on disk so the settings window can change them at runtime and they
// survive a restart.
//
// TWO STORES, not one, and the split is not arbitrary. Everything that only
// the shell cares about lives in the JSON at the bottom of this file. The
// desktop opacity does not: kitty, Zen and Hyprland read it too, so it lives
// in a file of its own that all four can reach. See the note on it below.
//
// WHAT BELONGS HERE AND WHAT DOES NOT
// Theme.qml is the design system: every constant in it is a decision with a
// reason written next to it, and exposing those as knobs would turn a
// coherent look into 40 sliders that can only make it worse. What lands here
// is the narrower set where there is no right answer -- 24-hour clock or 12,
// how long a notification stays up -- plus the one appearance value that is
// genuinely a preference rather than a decision, the transparency.
//
// Adding an option is three steps: a property below, a row in the settings
// window, and the binding that reads it. If the third step is not obvious --
// if nothing in the shell can react to the value changing -- it is not ready
// to be an option.
//
// WHY THE STATE DIRECTORY AND NOT ~/.config/quickshell
// Same reason NotificationState gives for notifications.json: the config
// directory is a stow tree of symlinks into a git repo, and a file the shell
// rewrites every time a switch is flipped does not belong in one.
//
// WHY THIS IS A SINGLETON READ IN-PROCESS AND NOT A FILE TWO PROCESSES SHARE
// The obvious shape -- and the one end-4's dots use -- is a separate
// `qs -p settings.qml` process talking to the shell through this file. That
// does not work here, and the reason is worth writing down because it fails
// silently: statePath() resolves under by-shell/<hash>, and the hash is per
// ENTRY POINT. Measured: the shell gets 73b54eaf..., a second process started
// from a .qml file in the same directory gets 919a9676.... Two files, both
// written, neither one read by the other.
//
// So the settings window lives inside the shell process (see
// modules/settings/), which also means it needs no synchronisation at all:
// flipping a switch assigns to a property that every binding already watches,
// and the write below is only about surviving a restart.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // The defaults duplicated as readonly constants, so "restore defaults"
    // has something to restore FROM. Reading them off the JsonAdapter is not
    // an option: by the time anything asks, the adapter holds the user's
    // values, not the initial ones.
    readonly property var defaults: ({
        opacity: 0.85,
        fontSize: 11,
        fontFamily: "JetBrainsMono Nerd Font",
        borderSize: 2,
        use24Hour: true,
        showDate: true,
        notificationTimeout: 10
    })

    // Where the cross-application state files live. Not statePath(): that
    // hashes the entry point into the directory name, and a script run from a
    // terminal has no way to compute the same hash. See the long note at the
    // bottom of this file.
    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`

    // ---------------- Appearance ----------------

    // The transparency of the whole desktop, not just of this shell: the bar
    // and everything sharing its glass, kitty, Zen's sidebar, and the windows
    // whose alpha Hyprland provides.
    //
    // IT IS NOT STORED IN THE JSON BELOW, and it is the only option here that
    // is not. Four programs need to read this value and only one of them is
    // the shell, so the store is a file all four can reach --
    // ~/.local/state/desktop-opacity, one number, no hash in the path (see
    // the note further down about statePath) and no JSON to parse from Lua.
    //
    // The `desktop-opacity` script is the only writer. This property is a
    // read of what it wrote, so a value set from a terminal moves the bar as
    // surely as the settings window does.
    //
    // Read by Theme.glass(). A fraction here, a percentage in the settings
    // window: 85 is a number a person can hold, 0.85 is one they translate.
    property real opacity: root.defaults.opacity

    // Set it. Everything that follows from it -- the shell's own surfaces
    // included -- comes back through the file.
    //
    // THE ASSIGNMENT IS IMMEDIATE AND THE PUSH IS DEBOUNCED, which is the
    // whole reason this is not simply bound to the file. The stepper repeats
    // while held, sixteen steps a second: pushing on each one would spawn
    // sixteen processes a second, each signalling every kitty on the machine.
    // The shell reacts to the property now, and the rest of the desktop
    // catches up once the value settles.
    function setOpacity(value: real): void {
        root.opacity = Math.round(value * 100) / 100;
        pushTimer.restart();
    }

    Timer {
        id: pushTimer

        interval: 150
        onTriggered: Quickshell.execDetached(["desktop-opacity", root.opacity.toFixed(2)])
    }

    FileView {
        id: opacityFile

        path: `${root.stateDir}/desktop-opacity`
        watchChanges: true
        // Absent until the script has run once, which is not an error: the
        // property already holds the same default the script does.
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.adoptFile()
    }

    // Take the value from the file, unless one of our own is still on its way
    // out -- otherwise the write we are about to make would be overwritten by
    // the file we are about to write, and a held-down stepper would fight
    // itself.
    function adoptFile(): void {
        if (pushTimer.running)
            return;

        const parsed = parseFloat(opacityFile.text());
        if (!isNaN(parsed) && parsed > 0 && parsed <= 1)
            root.opacity = parsed;
    }

    // ---------------- Type ----------------
    //
    // Size and family, in the same shape as the opacity above and for the
    // same reason: the terminal has to agree with the shell about them, so
    // the store is a file both can reach and the `desktop-font` script is the
    // only writer. Theme.qml's own note is the origin of this -- "kitty
    // measures in points... change it here only if kitty changes" -- and this
    // is that instruction made mechanical rather than remembered.
    //
    // THE FAMILY IS NOT FREE, and the settings window offers only the list
    // the script accepts. Every icon in this shell is a Nerd Font codepoint
    // drawn as text in Theme.fontFamily; a family without the glyph set turns
    // the whole desktop into tofu. The list is the JetBrainsMono Nerd Font
    // variants, which still leaves the choice that matters: monospaced or
    // proportional, ligatures or not.
    property int fontSize: root.defaults.fontSize
    property string fontFamily: root.defaults.fontFamily

    function setFont(size: int, family: string): void {
        root.fontSize = size;
        root.fontFamily = family;
        fontPushTimer.restart();
    }

    Timer {
        id: fontPushTimer

        interval: 150
        onTriggered: Quickshell.execDetached(["desktop-font", String(root.fontSize), root.fontFamily])
    }

    FileView {
        id: fontFile

        path: `${root.stateDir}/desktop-font`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.adoptFont()
    }

    // Two lines, size then family -- see the script. Anything malformed is
    // ignored rather than half-applied: a font size of NaN is a shell with no
    // text in it, and there would be no way left to open the window that
    // fixes it.
    function adoptFont(): void {
        if (fontPushTimer.running)
            return;

        const lines = (fontFile.text() || "").split("\n");
        const size = parseInt(lines[0]);
        const family = (lines[1] || "").trim();

        if (!isNaN(size) && size >= 8 && size <= 16)
            root.fontSize = size;
        if (family !== "")
            root.fontFamily = family;
    }

    // ---------------- The compositor's border ----------------
    //
    // NOT A Theme CONSTANT, and it is the clearest case on this page for why
    // some appearance settings cannot be: the border is drawn by Hyprland
    // around every window on the machine, including all the ones this shell
    // knows nothing about. The shell does not draw it, cannot draw it, and
    // only reads it here so the settings window has something to show.
    //
    // Same shape as the two above: a flat file, a script that owns the
    // writing, and hyprland.lua reading it at load so a reload does not undo
    // what `hyprctl eval` put into the running compositor.
    property int borderSize: root.defaults.borderSize

    function setBorder(size: int): void {
        root.borderSize = size;
        borderPushTimer.restart();
    }

    Timer {
        id: borderPushTimer

        interval: 150
        onTriggered: Quickshell.execDetached(["hypr-border", String(root.borderSize)])
    }

    FileView {
        id: borderFile

        path: `${root.stateDir}/hypr-border`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.adoptBorder()
    }

    function adoptBorder(): void {
        if (borderPushTimer.running)
            return;

        const parsed = parseInt(borderFile.text());
        if (!isNaN(parsed) && parsed >= 0 && parsed <= 6)
            root.borderSize = parsed;
    }

    // ---------------- The wallpaper collection ----------------
    //
    // ONE READER FOR TWO VIEWS. The launcher's picker and the settings
    // window's grid both list this folder, and until this property existed
    // they each carried their own `~/Pictures/wallpapers`. Pointing the
    // collection somewhere else moved one of them and not the other, which is
    // the worst outcome available: not a setting that fails, a setting that
    // half works.
    //
    // NOT $WALLPAPER_DIR, which `wallpaper-switch` also honours. That
    // variable is a per-invocation override -- run the script once against
    // some other folder -- and a process inherits its environment at launch,
    // so a shell started before it was set would show a folder nothing else
    // on the desktop agrees with.
    readonly property string wallpaperDirDefault: `${Quickshell.env("HOME")}/Pictures/wallpapers`

    property string wallpaperDir: root.wallpaperDirDefault

    FileView {
        id: wallpaperDirFile

        path: `${root.stateDir}/wallpaper-dir`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            const value = (text() || "").trim();
            root.wallpaperDir = value !== "" ? value : root.wallpaperDirDefault;
        }
    }

    // ---------------- Bar ----------------

    property alias use24Hour: adapter.use24Hour
    property alias showDate: adapter.showDate

    // ---------------- Notifications ----------------

    // In SECONDS here, milliseconds at the point of use. The file is meant to
    // be readable by hand and 10 is; 10000 invites the mistake that already
    // happened once in NotificationCard, where a value in milliseconds was
    // multiplied by 1000 and every notification stayed up for half an hour.
    //
    // This is the DEFAULT, applied to senders that express no preference
    // (expireTimeout -1). One that asks for a specific timeout still gets it,
    // and critical notifications still get their longer window: see the
    // header of NotificationCard.qml.
    property alias notificationTimeout: adapter.notificationTimeout

    function restoreDefaults(): void {
        root.setOpacity(root.defaults.opacity);
        root.setFont(root.defaults.fontSize, root.defaults.fontFamily);
        root.setBorder(root.defaults.borderSize);
        adapter.use24Hour = root.defaults.use24Hour;
        adapter.showDate = root.defaults.showDate;
        adapter.notificationTimeout = root.defaults.notificationTimeout;
    }

    // ---------------- Persistence ----------------
    //
    // The same four lines as NotificationState's FileView, and for the same
    // reasons: watchChanges only EMITS fileChanged, so the reload is the
    // handler's job; the first run has no file to read, which onLoadFailed
    // turns into a write of the defaults rather than an error on every
    // launch.
    //
    // Editing the file by hand while the shell is up works and is picked up
    // immediately -- that is what watchChanges buys, and it is the fastest
    // way to try a value that has no row in the settings window yet.
    FileView {
        id: file

        path: Quickshell.statePath("config.json")
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()

        JsonAdapter {
            id: adapter

            property bool use24Hour: true
            property bool showDate: true
            property int notificationTimeout: 10
        }
    }
}
