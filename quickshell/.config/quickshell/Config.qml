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
        notificationTimeout: 10,
        // Evening to morning, which is the only schedule anybody sets. See
        // the note on `dueNow` in NightLight.qml about why a window whose
        // start is later than its end is the normal case here rather than a
        // mistake to guard against.
        nightLightScheduled: false,
        nightLightFrom: 20 * 60,
        nightLightTo: 7 * 60,
        // Every widget on by default: this is the bar as designed, and the
        // switches below are for taking things away rather than for building
        // it up from nothing.
        barLogo: true,
        barActiveWindow: true,
        barTray: true,
        barBattery: true,
        barClock: true,
        barSettingsButton: true
    })

    // Where the cross-application state files live. Not statePath(): that
    // hashes the entry point into the directory name, and a script run from a
    // terminal has no way to compute the same hash. See the long note at the
    // bottom of this file.
    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`

    // Same idea for the caches wallpaper-switch writes. Kept beside stateDir
    // rather than spelled out where it is used, for the same reason: a script
    // and this shell have to agree on the path or neither finds the other's
    // files.
    readonly property string cacheDir: Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`

    // ---------------- Is this a laptop ----------------
    //
    // ONE ANSWER, GIVEN ONCE PER MACHINE, and the only thing in this file that
    // is about hardware rather than taste. These dotfiles are shared between a
    // desktop and a laptop, and the two things that differ most are a battery
    // and a backlight -- so install.sh asks, `laptop-modules` writes the
    // answer, and the two widgets read it here.
    //
    // OFF WHEN THE FILE IS ABSENT, which is every machine that has never been
    // asked. A bar that grows a battery indicator on a desktop is worse than
    // one that never had it: the number would be wrong and there would be
    // nothing to check it against.
    //
    // It is not the only gate. Both widgets ALSO hide themselves when the
    // hardware is not reported -- see their headers. This flag is the
    // intention; that is the check that the intention is possible.
    // TWO KEYS, because they are two widgets in two places and somebody may
    // want one without the other. install.sh sets both together -- at that
    // moment it is asking one question -- and the settings window then treats
    // them apart, which is what the rows in it are for.
    property bool laptopBattery: false
    property bool laptopBrightness: false

    function setLaptopModule(key: string, on: bool): void {
        if (key === "battery")
            root.laptopBattery = on;
        else
            root.laptopBrightness = on;

        Quickshell.execDetached(["laptop-modules", key, on ? "on" : "off"]);
    }

    FileView {
        id: laptopFile

        path: `${root.stateDir}/laptop-modules`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.adoptLaptopModules()
        onLoadFailed: {
            root.laptopBattery = false;
            root.laptopBrightness = false;
        }
    }

    // Tab-separated, one key per line, the same shape hypr-tweaks uses.
    function adoptLaptopModules(): void {
        const parsed = ({});

        for (const line of (laptopFile.text() || "").split("\n")) {
            const at = line.indexOf("\t");
            if (at < 0)
                continue;
            parsed[line.slice(0, at)] = line.slice(at + 1).trim();
        }

        root.laptopBattery = parsed["battery"] === "1";
        root.laptopBrightness = parsed["brightness"] === "1";
    }

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

    // ---------------- What the compositor is told ----------------
    //
    // NOT Theme CONSTANTS, and this is the clearest case on the page for why
    // some appearance settings cannot be: none of these is drawn by the
    // shell. Hyprland puts the border, the gaps and the rounded corners on
    // every window on the machine, including all the ones this shell knows
    // nothing about, and it owns the pointer and the mouse. The shell only
    // reads them so the settings window has something to show.
    //
    // ONE FILE AND ONE SCRIPT FOR ALL OF THEM, which is a change from how the
    // border alone used to work. That had its own state file, its own script
    // and its own reader function in hyprland.lua -- three new pieces for
    // every value, and the moment gaps, rounding, sensitivity and the cursor
    // followed, that was thirty. `hypr-tweak` owns the lot: one
    // tab-separated file here, one generated tweaks.lua for the compositor.
    //
    // Parsed rather than aliased, because the file is a small table and QML
    // has no reader for one. The defaults repeated below are the script's own
    // -- the two have to agree, and the script is the copy that gets to
    // refuse a value.
    property var tweaks: ({})

    readonly property int gapsIn: root.tweakInt("gaps-in", 5)
    readonly property int gapsOut: root.tweakInt("gaps-out", 20)
    readonly property int rounding: root.tweakInt("rounding", 10)
    readonly property int borderSize: root.tweakInt("border", root.defaults.borderSize)
    // In HUNDREDTHS of Hyprland's -1.0..1.0, the same units the script keeps
    // them in: bash has no floating point, and a settings window that had to
    // agree with it about rounding would be one more place to disagree.
    readonly property int sensitivity: root.tweakInt("sensitivity", 0)
    readonly property string accel: root.tweaks["accel"] ?? "adaptive"
    readonly property bool naturalScroll: (root.tweaks["natural-scroll"] ?? "0") === "1"
    readonly property int repeatRate: root.tweakInt("repeat-rate", 25)
    readonly property int repeatDelay: root.tweakInt("repeat-delay", 600)
    // Empty means "whatever the system already has". There is no sensible
    // default to invent: the theme in use came from the distribution.
    readonly property string cursorTheme: root.tweaks["cursor-theme"] ?? ""
    readonly property int cursorSize: root.tweakInt("cursor-size", 24)

    function tweakInt(key: string, fallback: int): int {
        const parsed = parseInt(root.tweaks[key]);
        return isNaN(parsed) ? fallback : parsed;
    }

    // The map moves at once and the script is called when the value settles,
    // for the reason setOpacity gives: a stepper repeats sixteen times a
    // second while held, and each one would otherwise be a process and a
    // round trip to the compositor.
    //
    // KEYED, so two different rows changed inside the same 150ms each get
    // their own call rather than one of them being lost.
    property var pendingTweaks: ({})

    function setTweak(key: string, value: var): void {
        const next = Object.assign({}, root.tweaks);
        next[key] = String(value);
        root.tweaks = next;

        const pending = Object.assign({}, root.pendingTweaks);
        pending[key] = String(value);
        root.pendingTweaks = pending;

        tweakPushTimer.restart();
    }

    Timer {
        id: tweakPushTimer

        interval: 150
        onTriggered: {
            for (const key in root.pendingTweaks)
                Quickshell.execDetached(["hypr-tweak", "set", key, root.pendingTweaks[key]]);

            root.pendingTweaks = ({});
        }
    }

    FileView {
        id: tweaksFile

        path: `${root.stateDir}/hypr-tweaks`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.adoptTweaks()
    }

    function adoptTweaks(): void {
        if (tweakPushTimer.running)
            return;

        const parsed = ({});

        for (const line of (tweaksFile.text() || "").split("\n")) {
            if (line.trim() === "")
                continue;

            // One tab, and split on the FIRST one only: a cursor theme name
            // is free text and nothing stops it containing another.
            const at = line.indexOf("\t");
            if (at < 0)
                continue;

            parsed[line.slice(0, at)] = line.slice(at + 1);
        }

        root.tweaks = parsed;
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

    // ---------------- What a wallpaper can be ----------------
    //
    // Here for the same reason wallpaperDir is: the launcher's strip and the
    // settings grid each had their own copy of five extensions, so adding
    // videos would have been two lists to keep in step and one of them
    // eventually not being.
    //
    // The stills include gif on purpose. awww animates a GIF by itself, so it
    // is a moving wallpaper that still goes down the image path and keeps the
    // transitions; only real video needs the other backend.
    //
    // The remaining copy of this list is in wallpaper-switch, which cannot ask
    // a running shell what it accepts. Change one, change the other.
    readonly property var wallpaperStillExtensions: ["jpg", "jpeg", "png", "webp", "bmp", "gif"]
    readonly property var wallpaperVideoExtensions: ["mp4", "webm", "mkv"]

    // Ready to hand to a FolderListModel.
    readonly property var wallpaperNameFilters: [...root.wallpaperStillExtensions, ...root.wallpaperVideoExtensions].map(e => `*.${e}`)

    function isWallpaperVideo(path: string): bool {
        const dot = path.lastIndexOf(".");
        if (dot < 0)
            return false;

        return root.wallpaperVideoExtensions.includes(path.slice(dot + 1).toLowerCase());
    }

    // What to point an Image at for a given wallpaper. An Image cannot decode
    // an mp4, so a video entry would draw as an empty rectangle -- in a picker
    // whose whole job is choosing by looking, that is the same as not being
    // there. wallpaper-switch extracts a frame per video and this reproduces
    // the name it files it under: the source path with its slashes flattened,
    // which is what keeps two `loop.mp4` in different subfolders apart.
    //
    // Returns a path and not a URL. The callers already build their own
    // file:// prefix and doing it here would leave them with two.
    function wallpaperThumb(path: string): string {
        if (!root.isWallpaperVideo(path))
            return path;

        return `${root.cacheDir}/wallpaper-frames/${path.replace(/^\//, "").replace(/\//g, "_")}.png`;
    }

    // Those frames have to exist before anything asks for one, and the two
    // views cannot each run the extraction: they would race over the same
    // output files the first time a folder of videos is opened. So it runs
    // once, here, on startup and whenever the collection moves.
    //
    // Cheap to repeat -- the script skips any video whose frame is already
    // newer than it is -- which is what makes running it on every folder
    // change acceptable rather than something that needs to be smart.
    property int wallpaperThumbsRevision: 0

    Process {
        id: wallpaperThumbsProcess

        command: ["wallpaper-switch", "thumbs"]

        // The bump is what tells the pickers to look again. Until ffmpeg has
        // finished, a video's thumbnail file does not exist, and an Image
        // pointed at a missing file does not retry on its own.
        onExited: root.wallpaperThumbsRevision++
    }

    onWallpaperDirChanged: wallpaperThumbsProcess.running = true

    Component.onCompleted: wallpaperThumbsProcess.running = true

    // ---------------- How often the wallpaper rotates ----------------
    //
    // In MINUTES, and the file is written by `wallpaper-interval`, which owns
    // the systemd drop-in that actually changes the timer. Same shape as
    // everything else here: a flat file one script writes and this reads, so
    // a value set from a terminal moves the row in the settings window.
    //
    // The default repeats the one in wallpaper-rotate.timer. Two copies of a
    // number is a cost, and the alternative is worse -- parsing a systemd unit
    // from QML to find out what the shell should draw before the script has
    // ever run.
    readonly property int wallpaperIntervalDefault: 30

    property int wallpaperInterval: root.wallpaperIntervalDefault

    function setWallpaperInterval(minutes: int): void {
        root.wallpaperInterval = minutes;
        intervalPushTimer.restart();
    }

    Timer {
        id: intervalPushTimer

        // Longer than the 150ms the other steppers use: this one ends in a
        // systemd daemon-reload, which is heavier than writing a number to a
        // file, and nobody holds this stepper down looking for a specific
        // value the way they do with the opacity.
        interval: 300
        onTriggered: Quickshell.execDetached(["wallpaper-interval", String(root.wallpaperInterval)])
    }

    FileView {
        id: intervalFile

        path: `${root.stateDir}/wallpaper-interval`
        watchChanges: true
        // Absent until the interval has been changed once, which is the normal
        // state: the timer's own value is in force and the default above says
        // so.
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            if (intervalPushTimer.running)
                return;

            const parsed = parseInt(intervalFile.text());
            if (!isNaN(parsed) && parsed >= 5 && parsed <= 10080)
                root.wallpaperInterval = parsed;
        }
        onLoadFailed: root.wallpaperInterval = root.wallpaperIntervalDefault
    }

    // ---------------- Bar ----------------

    property alias use24Hour: adapter.use24Hour
    property alias showDate: adapter.showDate

    // Which widgets the bar shows.
    //
    // NOT EVERY WIDGET IS HERE, and the ones missing are missing on purpose.
    // The workspaces, the island and the power button have no switch: the
    // first two are how you know where you are and what the desktop is doing,
    // and the last is the only pointer-reachable way to end the session. A
    // settings window that can hide the way out is a settings window that can
    // strand somebody.
    property alias barLogo: adapter.barLogo
    property alias barActiveWindow: adapter.barActiveWindow
    property alias barTray: adapter.barTray
    property alias barBattery: adapter.barBattery
    property alias barClock: adapter.barClock
    property alias barSettingsButton: adapter.barSettingsButton

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

    // ---------------- Night light ----------------
    //
    // ONLY THE SCHEDULE, and not whether the filter is on. That lives in
    // ~/.local/state/night-light, written by the `night-light` script, for the
    // same reason the opacity does: hyprsunset and a terminal have to agree
    // with the shell about it. What is here is the part nothing outside this
    // process has any use for -- see the header of NightLight.qml.
    //
    // Minutes since midnight.
    property alias nightLightScheduled: adapter.nightLightScheduled
    property alias nightLightFrom: adapter.nightLightFrom
    property alias nightLightTo: adapter.nightLightTo

    function restoreDefaults(): void {
        root.setOpacity(root.defaults.opacity);
        root.setFont(root.defaults.fontSize, root.defaults.fontFamily);
        root.setTweak("border", root.defaults.borderSize);
        adapter.use24Hour = root.defaults.use24Hour;
        adapter.showDate = root.defaults.showDate;
        adapter.notificationTimeout = root.defaults.notificationTimeout;
        adapter.nightLightScheduled = root.defaults.nightLightScheduled;
        adapter.nightLightFrom = root.defaults.nightLightFrom;
        adapter.nightLightTo = root.defaults.nightLightTo;
        adapter.barLogo = root.defaults.barLogo;
        adapter.barActiveWindow = root.defaults.barActiveWindow;
        adapter.barTray = root.defaults.barTray;
        adapter.barBattery = root.defaults.barBattery;
        adapter.barClock = root.defaults.barClock;
        adapter.barSettingsButton = root.defaults.barSettingsButton;
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
            property bool nightLightScheduled: false
            property int nightLightFrom: 1200
            property int nightLightTo: 420
            property bool barLogo: true
            property bool barActiveWindow: true
            property bool barTray: true
            property bool barBattery: true
            property bool barClock: true
            property bool barSettingsButton: true
        }
    }
}
