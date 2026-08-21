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
        // Empty means "work it out", which is what Screens.qml did on its own
        // before this was a choice, and what every single-monitor machine
        // wants. An empty bar list means "the main monitor only", which is
        // where the bar has always been.
        mainMonitor: "",
        barMonitors: [],
        // And an empty replay monitor means nobody has chosen one yet, which
        // leaves the buffer on whichever screen the shell is on -- where it has
        // always been pointed.
        replayMonitor: "",
        // Recording. Armed is the resting state; 0 seconds means nobody has
        // chosen a length and 30 is used; an empty codec is gsr's own auto;
        // an empty directory is the one the recorder has always written to;
        // and an empty microphone is the system default rather than "none".
        // See the Recording section below for each of them.
        replayEnabled: true,
        replaySeconds: 0,
        replayStorage: "ram",
        replayDirectory: "",
        recordingDirectory: "",
        recordingContainer: "mp4",
        recordingFramerate: 60,
        recordingCodec: "",
        recordingBitrateMode: "cbr",
        recordingBitrate: 40000,
        recordingQuality: "very_high",
        recordingDesktopAudio: true,
        recordingMicrophone: true,
        recordingMicrophoneDevice: "",
        recordingAudioCodec: "aac",
        // The set a bar starts with, and the only thing in this file that
        // decides what a NEW bar shows. Every bar keeps its own copy from the
        // first switch touched on it, so this is a seed and not a live value:
        // changing it moves the bars nobody has customised and leaves the rest
        // alone. See the widget section below for the whole shape.
        //
        // WHY THESE FIVE AND NOT ALL EIGHT. The question asked of each widget
        // was whether a SECOND copy of it, on a screen plugged in beside the
        // first, is worth anything -- because that is the case this seed is
        // for, and the case the old base never had to answer.
        //
        // Three of them read the screen they are on, so a second copy says
        // something new: the focused window title, and the clock and the logo
        // that make a strip of pixels read as this desktop's bar rather than
        // as a gap. The other two are ways back rather than readings. The
        // settings button is the only pointer-reachable way into this window,
        // which is the same argument the power button already wins; the tray
        // is where an application with no window of its own lives, and a
        // session where Discord is minimised to a tray that is not drawn is a
        // session with no way to reach it.
        //
        // The three that start off are the three that would say it twice. The
        // island narrates the desktop and there is only one desktop -- its own
        // header has made that argument since the bar learned to repeat, and
        // SUPER + D opens the dashboard whether or not it is drawn. The
        // peripheral battery is a fact about the mouse, not about the monitor,
        // and this repo has already had to stop it warning once per bar. The
        // keyboard layout is one layout for the whole session and hides itself
        // below two of them anyway.
        //
        // THIS CHANGES WHAT A FRESH CLONE COMES UP WITH, and that is the cost
        // being accepted rather than an oversight. The bar used to arrive with
        // everything on -- "the bar as designed", with the switches there to
        // take things away. One seed now has to serve the first bar and the
        // fourth, and a seed tuned for the first would put a second island and
        // a second tray on every screen anybody adds. Nobody with an existing
        // config sees this: what they had is written out per monitor the first
        // time this version loads.
        barWidgets: ({
            logo: true,
            activeWindow: true,
            island: false,
            tray: true,
            battery: false,
            keyboardLayout: false,
            clock: true,
            settingsButton: true
        })
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

    // Tab-separated, one key per line, the same shape desktop-tweaks uses.
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
    // shell. The compositor puts the border, the gaps and the rounded corners
    // on every window on the machine, including all the ones this shell knows
    // nothing about, and it owns the pointer and the mouse. The shell only
    // reads them so the settings window has something to show.
    //
    // ONE FILE AND ONE SCRIPT FOR ALL OF THEM, AND FOR EVERY COMPOSITOR. That
    // is two changes from how the border alone used to work. It had its own
    // state file, its own script and its own reader function in hyprland.lua --
    // three new pieces for every value, and the moment gaps, rounding,
    // sensitivity and the cursor followed, that was thirty. And a second
    // compositor would have doubled whatever was left. `desktop-tweak` owns the
    // lot: one tab-separated file here, and one generated override file per
    // flavor (tweaks.lua for Hyprland, tweaks.kdl for niri) written from it.
    //
    // WHICH IS WHY NOTHING IN THIS SECTION BRANCHES ON THE COMPOSITOR. The
    // values mean the same thing on both -- the script is where the spelling
    // differs -- and the page that shows them asks `Compositor.can("inputConfig")`
    // rather than which one is running.
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
    // ON when nothing says otherwise, which is the opposite default to
    // naturalScroll above and deliberate: the machine this repository
    // describes installs a pack of themes built from the same Material 3
    // roles the shell paints with, and leaving them unused until somebody
    // finds the switch is a worse first impression than the pointer simply
    // matching. The fallback has to agree with desktop-tweak's own default
    // for the key, or the switch shows one thing and the script does another.
    readonly property bool cursorAuto: (root.tweaks["cursor-auto"] ?? "1") === "1"

    // ---------------- Push to talk ----------------
    //
    // IN THE TWEAK STORE AND NOT IN config.json, although the switch that
    // flips it is a settings row like any other. The value is not the shell's
    // to keep: what it means is a pair of KEYBINDS in the compositor, written
    // by desktop-tweak into the generated override file, and the shell is only
    // the thing those binds call. A copy here would be a second answer to
    // "is push-to-talk on" that nothing keeps in step with the binds.
    //
    // OFF unless the store says otherwise, and the fallback has to agree with
    // desktop-tweak's own default for the key -- see cursorAuto above for why
    // that agreement is load-bearing. Off is also the only safe default: on
    // means the microphone is closed, and a machine that came up muted without
    // anyone asking is a machine whose microphone looks broken.
    readonly property bool pushToTalk: (root.tweaks["ptt"] ?? "0") === "1"

    // The keysym the binds are written on: "backslash", "F13", or "code:NN"
    // for a key xkb has no name for. Shown verbatim in the settings window
    // rather than prettied up, because it is literally what goes into the
    // bind -- a row that said "\" while the file said something else would be
    // the harder of the two to debug.
    readonly property string pushToTalkKey: root.tweaks["ptt-key"] ?? "backslash"

    // ---------------- Keyboard layouts ----------------
    //
    // THE LIST IS THE STATE AND THE FIRST ENTRY IS THE ACTIVE LAYOUT. There is
    // no index kept here: on Hyprland switching rotates the cycle, so
    // "us,latam" becomes "latam,us" and back. The argument for that shape is in
    // desktop-tweak's header -- the short version is that Hyprland's own
    // active-layout index is session-only and is reset by anything that
    // re-applies the input block, including changing the mouse speed on the
    // same settings page. On niri the compositor keeps the index and the list
    // stays put, which is what keyboardLayoutIndex below is about.
    //
    // Either way this is the whole truth about WHICH LAYOUTS EXIST, and both
    // the bar's indicator and the settings page read it from here.
    readonly property var keyboardLayouts: (root.tweaks["layouts"] ?? "us")
        .split(",").map(code => code.trim()).filter(code => code !== "")

    // WHICH OF THEM IS ACTIVE, and the answer comes from two different places
    // because the two compositors keep it in two different ones.
    //
    // Hyprland's own index is session-only and is thrown away by anything that
    // re-applies the input block -- including changing the mouse speed on the
    // same settings page -- so nothing outside the compositor can trust it. The
    // list is rotated instead and the FIRST entry is the active one, which is
    // the whole argument in desktop-tweak's header.
    //
    // niri publishes the index and keeps it: `niri msg -j keyboard-layouts`
    // answers with the names and which one is current, and the shell watches
    // that live. So there the list stays in the order it was written and the
    // index says where in it we are -- no rotation, and the pill cannot drift
    // from what the keyboard is doing because it is reading the keyboard.
    readonly property int keyboardLayoutIndex: {
        if (!Compositor.can("keyboardLayout"))
            return 0;
        const i = Compositor.keyboardLayouts.currentIndex ?? 0;
        // Guarded: the compositor's list and this one come from different
        // places and a config edit can leave them disagreeing for an instant.
        return i < root.keyboardLayouts.length ? i : 0;
    }

    readonly property string keyboardLayout:
        root.keyboardLayouts[root.keyboardLayoutIndex] ?? "us"

    // Four, and it is xkb's limit rather than a choice: a keymap has four
    // groups and a fifth layout is parsed, accepted and then never reached.
    // The script refuses it; this is the copy the settings window uses to stop
    // offering what would be refused.
    readonly property int keyboardLayoutMax: 4

    // Change WHICH layouts exist, keeping the order given -- the first one
    // becomes the active one. Debounced through setTweak like every other
    // value on that page.
    function setKeyboardLayouts(codes: var): void {
        root.setTweak("layouts", codes.join(","));
    }

    // Change which of them is active, and step the cycle. Both go through the
    // script rather than rotating the array here, and that is deliberate:
    // SUPER + K runs the same command, and one implementation of "rotate" is
    // what keeps the keybind and the window from disagreeing about the order.
    // The new value comes back through the file watcher below.
    function useKeyboardLayout(code: string): void {
        Quickshell.execDetached(["desktop-tweak", "layout", code]);
    }

    // STEPPING IT GOES TO WHOEVER OWNS THE ANSWER. Where the compositor keeps a
    // readable index, ask the compositor to move it -- rotating the stored list
    // there would fight the index and the two would disagree. Where it does
    // not, the script rotates the list, which is the only place the answer can
    // live. SUPER + K runs the same code path either way, so the keybind and
    // the settings window cannot drift apart.
    function cycleKeyboardLayout(): void {
        if (Compositor.can("keyboardLayout"))
            Compositor.switchKeyboardLayout();
        else
            Quickshell.execDetached(["desktop-tweak", "layout", "next"]);
    }

    // ---------------- What the layout codes mean ----------------
    //
    // `latam` is what the compositor takes and "Spanish (Latin American)" is
    // what a person is looking for, so the settings list needs both. Ninety-
    // nine of them, read out of xkb's own rules file by the script.
    //
    // LOADED ON DEMAND AND ONCE. Nothing at startup needs it -- the bar shows
    // the code -- so the process runs the first time something asks: opening
    // the Input page, or hovering the pill for its tooltip. Both call
    // ensureLayoutNames(); whichever gets there first pays for it.
    property var layoutNames: ({})

    function ensureLayoutNames(): void {
        if (!layoutNamesProcess.running && Object.keys(root.layoutNames).length === 0)
            layoutNamesProcess.running = true;
    }

    // The English name for a code, or the code itself. Falling back to the
    // code is not a placeholder: before the table has loaded, and on a system
    // whose rules file is missing, the code is a true answer and "Unknown" is
    // not.
    function layoutName(code: string): string {
        return root.layoutNames[code] ?? code;
    }

    Process {
        id: layoutNamesProcess

        command: ["desktop-tweak", "layouts"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = ({});

                for (const line of (text || "").split("\n")) {
                    const at = line.indexOf("\t");
                    if (at < 0)
                        continue;
                    parsed[line.slice(0, at)] = line.slice(at + 1).trim();
                }

                root.layoutNames = parsed;
            }
        }
    }

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
                Quickshell.execDetached(["desktop-tweak", "set", key, root.pendingTweaks[key]]);

            root.pendingTweaks = ({});
        }
    }

    FileView {
        id: tweaksFile

        path: `${root.stateDir}/desktop-tweaks`
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.adoptTweaks()
    }

    // WHAT IS PENDING WINS, KEY BY KEY -- it does not skip the whole file.
    // This used to return early while the push timer was running, which was
    // right when the settings window was the only writer: the file could only
    // be a moment behind our own values. It stopped being right when the
    // layout arrived, because `desktop-tweak layout next` writes the file
    // WITHOUT going through the timer, and a rotation landing inside the
    // 150ms after some other row was touched was thrown away -- the bar kept
    // showing the old layout until something else happened to change.
    //
    // Overlaying the pending keys keeps the original guarantee (a stepper
    // being held does not fight the file it is writing) without discarding
    // everything else the file has to say.
    function adoptTweaks(): void {
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

        for (const key in root.pendingTweaks)
            parsed[key] = root.pendingTweaks[key];

        root.tweaks = parsed;
    }

    // ---------------- The wallpaper collection ----------------
    //
    // ONE READER FOR TWO VIEWS. The carousel lists this folder and the
    // settings page counts it, and back when the second view was a grid of its
    // own they each carried their own `~/Pictures/wallpapers`. Pointing the
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
    // Here for the same reason wallpaperDir is: the two views each had their
    // own copy of five extensions, so adding videos would have been two lists
    // to keep in step and one of them eventually not being.
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

    // What to point an Image at for a given wallpaper, which is NEVER the
    // wallpaper itself.
    //
    // A VIDEO HAS NOTHING AN IMAGE CAN DECODE, so wallpaper-switch extracts a
    // frame per video and this reproduces the name it files it under: the
    // source path with its slashes flattened, which is what keeps two
    // `loop.mp4` in different subfolders apart.
    //
    // A STILL IS SKIPPED FOR A DIFFERENT REASON, and it is the one that costs.
    // The collection is 4K and about half of it is PNG, which has no scaled
    // decoding: asked for a card-sized thumbnail of one, Qt decodes all 8.3
    // million pixels and throws most of them away -- measured at 170 to 220 ms
    // and some 35 MB, every time a card slides into the carousel's fan. The
    // script keeps a 960 px JPEG of each one, which is about 5 ms.
    //
    // THE FILE MAY NOT BE THERE YET, on a collection the script has not been
    // over. The caller is expected to fall back to the wallpaper itself when
    // the Image reports an error -- see the carousel -- because a missing
    // thumbnail should be slow, not blank.
    function wallpaperThumb(path: string): string {
        const flat = path.replace(/^\//, "").replace(/\//g, "_");

        if (root.isWallpaperVideo(path))
            return `${root.cacheDir}/wallpaper-frames/${flat}.png`;

        return `${root.cacheDir}/wallpaper-thumbs/${flat}.jpg`;
    }

    // The wallpaper itself as a URL, for that fallback. Encoded segment by
    // segment for the reason the two below are.
    function wallpaperFullUrl(path: string): string {
        return `file://${path.split("/").map(encodeURIComponent).join("/")}`;
    }

    // The same thing as a URL, which is what an Image actually wants.
    //
    // Encoded segment by segment rather than pasted behind `file://`. These
    // names come off the internet -- "sunset (4k) #2.mp4" is an ordinary thing
    // to download -- and a raw `#` in a URL starts a fragment, so the Image
    // would look for a file whose name stops at the hash. Splitting on the
    // separator first is what keeps the slashes as slashes.
    function wallpaperThumbUrl(path: string): string {
        return `file://${root.wallpaperThumb(path).split("/").map(encodeURIComponent).join("/")}`;
    }

    // ---------------- The preview clip of a video ----------------
    //
    // WHAT THE CAROUSEL ACTUALLY PLAYS. These wallpapers are 4K -- one of them
    // 4K at 120 fps -- and playing one measured about two thirds of a core.
    // wallpaper-switch builds a 960x540 copy at 24 fps beside the still
    // frames, and twelve seconds of that decodes in a third of a second of
    // CPU.
    //
    // Same naming as the frame: the source path with its slashes flattened,
    // which is what keeps two `loop.mp4` in different subfolders apart. This
    // reproduces it rather than asking the script, for the reason the thumb
    // path already does -- a running shell cannot ask a script where it filed
    // something without spawning it.
    //
    // NOT DEFINED FOR A STILL. A caller with an image has nothing to play, and
    // an empty string is the answer that makes that obvious at the call site
    // instead of handing back a path that will never exist.
    function wallpaperPreview(path: string): string {
        if (!root.isWallpaperVideo(path))
            return "";

        return `${root.cacheDir}/wallpaper-previews/${path.replace(/^\//, "").replace(/\//g, "_")}.mp4`;
    }

    // The same thing as a URL, encoded segment by segment. See the note on
    // wallpaperThumbUrl: "(live)-persona3.mp4" is a real name in this
    // collection and a raw "#" in one of them would cut the URL short.
    function wallpaperPreviewUrl(path: string): string {
        const preview = root.wallpaperPreview(path);
        if (preview === "")
            return "";

        return `file://${preview.split("/").map(encodeURIComponent).join("/")}`;
    }

    // Those files have to exist before anything asks for one, and the views
    // cannot each run the extraction: they would race over the same output
    // files the first time a folder is opened. So it runs once, here, and the
    // views ask for it rather than doing it.
    //
    // Cheap to repeat -- the script skips any wallpaper whose cached files are
    // already newer than it is -- which is what makes calling it on every
    // change acceptable rather than something that needs to be smart.
    property int wallpaperThumbsRevision: 0

    Process {
        id: wallpaperThumbsProcess

        // Builds ALL THREE caches in one pass -- a thumbnail for every
        // wallpaper, plus a still frame and a preview clip for every video --
        // because they are named after the same file and go stale together.
        // See the mode's own note in the script.
        command: ["wallpaper-switch", "thumbs"]

        // The bump is what tells the views to look again. Until ffmpeg has
        // finished, a video's thumbnail and its preview do not exist, and
        // neither an Image nor a MediaPlayer pointed at a missing file retries
        // on its own.
        onExited: root.wallpaperThumbsRevision++
    }

    // ON THE CONTENTS CHANGING, not only on the folder moving. That was the
    // first version and it left a video added to the collection showing an
    // empty rectangle for the rest of the session: the shell had already run
    // the extraction at startup, the file arrived afterwards, the Image asked
    // for a frame that did not exist yet, and nothing ever asked again.
    //
    // Guarded because both views call it and they see the same new file at
    // roughly the same moment. Re-entering a running extraction would restart
    // it and lose the work it had already done.
    function refreshWallpaperThumbs(): void {
        if (!wallpaperThumbsProcess.running)
            wallpaperThumbsProcess.running = true;
    }

    onWallpaperDirChanged: root.refreshWallpaperThumbs()

    Component.onCompleted: root.refreshWallpaperThumbs()

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

    // ---------------- Which monitor is which ----------------
    //
    // HOW A MONITOR IS NAMED IN THIS FILE, and it is not the connector. "DP-3"
    // is assigned by the kernel and moves between kernel versions -- this
    // machine's main panel was DP-4 a week ago -- so a setting written against
    // one silently applies to the wrong monitor after an update. The rest of
    // this desktop already solved that: hyprland.lua matches monitors by their
    // EDID description and desktop-monitors keys its records by the same string.
    //
    // This uses MODEL + SERIAL, which is that same description minus the
    // manufacturer. Not a second convention, a shorter spelling of the one
    // convention: Quickshell's ShellScreen exposes `model` and `serialNumber`
    // and no description, and the serial is what makes it unique -- it is the
    // one field that tells two identical monitors apart, which is the case the
    // connector name cannot survive either.
    //
    // Falls back to the connector when a screen reports neither, which happens
    // with virtual outputs and with a KVM in between. A key that is wrong after
    // a kernel update beats no key at all: the failure is a bar on the wrong
    // monitor, not a shell with no bar.
    function screenKey(screen: var): string {
        if (!screen)
            return "";

        const key = `${screen.model ?? ""} ${screen.serialNumber ?? ""}`.trim();
        return key || (screen.name ?? "");
    }

    // Which monitor the shell lives on -- the bar's default home, and the one
    // the launcher, the notifications, the power menu and the cheatsheet are
    // pinned to. Empty means Screens.qml chooses, see its header for the rule.
    property alias mainMonitor: adapter.mainMonitor

    // The monitors carrying a bar, as screenKey() strings. EMPTY MEANS THE MAIN
    // ONE ALONE, which is where the bar has always been and therefore what a
    // machine that has never opened this page must keep doing -- pulling this
    // change should not grow bars on screens nobody asked about. It is also not
    // "none": there is no state here that leaves a desktop with no bar at all.
    //
    // WHICH SCREENS THAT ACTUALLY MEANS is Screens.qml's answer and not this
    // file's, because resolving it needs to know which screen is the main one
    // and Screens is the singleton that decides that -- it already imports this
    // one, and the reverse would be a cycle. Config stores the choice; Screens
    // reads it. See Screens.barScreens and Screens.hasBar.
    property alias barMonitors: adapter.barMonitors

    function setBarOnScreen(key: string, on: bool, mainKey: string): void {
        // The empty list means "main only", so the first change has to spell
        // that out before it can add to it or take from it -- otherwise
        // switching the second monitor on would produce ["<second>"], which
        // reads as "and not the main one".
        const current = (root.barMonitors ?? []).length > 0 ? root.barMonitors.slice() : (mainKey ? [mainKey] : []);

        const at = current.indexOf(key);
        if (on && at < 0)
            current.push(key);
        else if (!on && at >= 0)
            current.splice(at, 1);

        root.barMonitors = current;
    }

    // Which monitor the instant replay buffer keeps, as a screenKey() string.
    //
    // EMPTY IS "NOBODY HAS SAID YET" AND NOT AN ANSWER OF ITS OWN. The
    // dashboard offers monitors and only monitors -- there is no "automatic"
    // to pick, because an automatic answer nobody gave and nobody could see is
    // the exact failure this setting was written to end. What empty gets you is
    // what the buffer did before it was a choice: the shell's own screen, so a
    // fresh clone and a single-monitor machine both record something sensible
    // without being asked. The first click writes a real monitor here and it
    // never goes back to empty on its own.
    //
    // A SEPARATE CHOICE FROM `mainMonitor` AND NOT AN ALIAS OF IT, because the
    // two answer different questions. The main monitor is where the shell
    // lives; this is what is worth keeping the last minute of, and the second
    // is a game on the big panel while the bar sits on the small one. Tying
    // them together would mean moving the bar to change what gets recorded.
    //
    // WHY THIS EXISTS AT ALL: the buffer was pointed at the shell's monitor
    // and nothing said which that was. The recorder resolves the connector
    // name once, when it starts, and the name it resolved is invisible from
    // the desk -- so a buffer that came up holding the wrong screen went on
    // holding it, and every clip saved from it was of the wrong screen. The
    // resolution now happens live and it is on the dashboard, next to the
    // switch. See ReplayState.monitor.
    property alias replayMonitor: adapter.replayMonitor

    // ---------------- Bar ----------------

    property alias use24Hour: adapter.use24Hour
    property alias showDate: adapter.showDate

    // ---------------- Which widgets each bar shows ----------------
    //
    // ONE COMPLETE SET PER MONITOR, WITH NO SHARED BASE ABOVE THEM. Every bar
    // is configured on its own: `barWidgetsByMonitor` maps a screenKey() to
    // the eight answers for that screen, and nothing a bar says can move
    // another one. A monitor with no entry shows `defaults.barWidgets`, the
    // seed at the top of this file, and gets an entry of its own the first
    // time a switch on it is touched.
    //
    // THIS REPLACES A BASE PLUS EXCEPTIONS, and the reasoning that shape had
    // is kept here rather than deleted, because it was not wrong -- it stopped
    // being what this desktop wanted. The old model had eight `barLogo`-style
    // switches saying what EVERY bar showed and a sparse `barOverrides` map
    // holding only where one monitor disagreed, per widget. What it bought was
    // real: plugging in a monitor gave you the bar you had already designed,
    // and changing your mind about the tray moved every bar that had never had
    // an opinion about trays.
    //
    // It was dropped because the price of that is a control nobody can read.
    // Inheritance meant every switch answered two questions at once -- what
    // this bar shows, and whether this bar has an opinion -- and the settings
    // page needed a scope selector saying which of the two you were editing
    // before any switch below it meant anything. On this machine, with one bar
    // switched on, "All" and "that monitor" did the same thing and the
    // selector was furniture. With two bars it was worse than furniture: the
    // switches looked identical whichever way it was pointed, and a change
    // landing on the wrong bar is invisible from a window that covers the
    // other screen.
    //
    // WHAT IS GIVEN UP, said plainly. There is no longer any way to change one
    // thing on every bar at once; with two bars that is two visits to the same
    // switch, and with four it is four. That is the trade accepted for a page
    // where every switch means exactly what it is next to.
    //
    // NOT EVERY WIDGET IS IN THE SET, and the ones missing are missing on
    // purpose. The workspaces and the power button have no switch: the first
    // is how you know where you are, and the last is the only pointer-reachable
    // way to end the session. A settings window that can hide the way out is a
    // settings window that can strand somebody.
    //
    // THE ISLAND USED TO BE ON THAT LIST and no longer is, because the argument
    // for it stopped holding when the bar could repeat. It was "this is how you
    // know what the desktop is doing", which is true of HAVING one and not of
    // having one per monitor -- a second copy narrating the same desktop
    // beside the first is noise. It is also not a way out of anywhere:
    // SUPER + D opens the dashboard whether or not the island is drawn, which
    // is the test the power button fails and this passes. It is now also the
    // clearest case for the seed starting a new bar without one.

    // The widget names, in bar order, derived from the seed rather than
    // written out beside it. One list and one set would be two places to add a
    // widget and one place to forget it; `Object.keys` on an object literal
    // hands them back in the order they were written, which is the order the
    // page draws them in.
    readonly property var barWidgets: Object.keys(root.defaults.barWidgets)

    // screenKey() -> { widget: bool }. A stored set is written whole and holds
    // every widget, so reading one needs no second lookup and a bar cannot end
    // up half-inheriting from something that no longer exists.
    //
    // A MONITOR IS WRITTEN IN LAZILY, on the first switch touched on it, and
    // not when it is connected. A screen seen once at somebody else's desk
    // should not leave a permanent record behind, and a bar nobody has
    // customised is better described by the seed -- which can improve -- than
    // by a frozen copy of what the seed said the day it was plugged in.
    property alias barWidgetsByMonitor: adapter.barWidgetsByMonitor

    // What a given bar actually shows. Per widget rather than per set, so a
    // widget added to the seed after a monitor was customised appears on that
    // monitor too, with the seed's answer, instead of being read as "off"
    // because the stored set predates it.
    function barWidget(key: string, widget: string): bool {
        const set = key ? root.barWidgetsByMonitor?.[key] : null;

        if (set && set[widget] !== undefined)
            return set[widget] === true;

        return root.defaults.barWidgets[widget] === true;
    }

    // The complete set for one bar: what is stored, over the seed for anything
    // it does not mention. Every value comes back a real bool, because this is
    // what gets written back and a `1` read out of a hand-edited file should
    // not survive a round trip.
    function barWidgetSet(key: string): var {
        const set = {};

        for (const widget of root.barWidgets)
            set[widget] = root.barWidget(key, widget);

        return set;
    }

    function setBarWidget(key: string, widget: string, on: bool): void {
        // No key is no bar. The old model read an empty key as "the base", and
        // there is no base any more -- silently writing under "" would build a
        // set nothing ever reads.
        if (!key)
            return;

        // Assigned whole rather than mutated in place, at both levels:
        // JsonAdapter watches the property, and writing through an object it
        // already holds changes the value without ever telling it to save. It
        // is also what makes the `visible:` bindings in Bar.qml re-run -- see
        // the note above Bar.widget().
        const next = Object.assign({}, root.barWidgetsByMonitor);
        const set = root.barWidgetSet(key);

        set[widget] = on;
        next[key] = set;

        root.barWidgetsByMonitor = next;
    }

    // Whether this bar is still showing the seed. Used by the settings page to
    // decide whether "reset" has anything to undo: a reset offered on a bar
    // that already matches is a button that does nothing, and one that has been
    // clicked once with no visible result is one nobody trusts again.
    function barIsDefault(key: string): bool {
        return root.barWidgets.every(widget => root.barWidget(key, widget) === (root.defaults.barWidgets[widget] === true));
    }

    // Back to the seed, by DELETING the entry rather than by writing a copy of
    // the seed into it. The two look identical on screen and are not the same
    // state: a deleted entry follows the seed from then on, a copy freezes
    // today's answer and would quietly stop matching the day a widget is added.
    function resetBar(key: string): void {
        if (!key || !root.barWidgetsByMonitor?.[key])
            return;

        const next = Object.assign({}, root.barWidgetsByMonitor);
        delete next[key];
        root.barWidgetsByMonitor = next;
    }

    // ---------------- Reading a config written before the split ----------------
    //
    // WHY THIS EXISTS: the old keys cannot be read through the adapter. A
    // JsonAdapter writes every property it declares, so leaving `barLogo` and
    // friends declared would keep them in the file forever, and removing them
    // -- which is the point -- means the next write drops them. So the old
    // shape is read once out of the file's raw TEXT, before any write, folded
    // into one complete set per monitor, and never looked at again.
    //
    // WHICH MONITORS GET AN ENTRY: every key the old file named, plus every
    // screen connected right now. The first is what it knew about; the second
    // is what somebody can see. Together they cover the case that has no key
    // anywhere in the file -- a single-monitor machine that customised its bar
    // and never opened the display page, whose `barMonitors` is empty because
    // empty meant "the main one".
    //
    // A monitor the old file did not name and that is not plugged in gets no
    // entry, and therefore the seed if its bar is ever switched on. That is the
    // one place the old and new models give different answers, and it is the
    // new behaviour rather than a loss: nothing was on screen to change.
    //
    // The map is written out rather than built from `"bar" + capitalise()`,
    // which is the same choice the old `barBase` switch statement made and for
    // a reason that still holds: a name assembled at runtime fails at runtime,
    // on one monitor, long after the rename that broke it.
    readonly property var legacyBarKeys: ({
        logo: "barLogo",
        activeWindow: "barActiveWindow",
        island: "barIsland",
        tray: "barTray",
        battery: "barBattery",
        keyboardLayout: "barKeyboardLayout",
        clock: "barClock",
        settingsButton: "barSettingsButton"
    })

    // The parsed old shape, held until it can be folded. It usually folds on
    // the first attempt; it is kept because the fold needs the screen list and
    // this singleton can, in principle, be built before the compositor has
    // named a single output -- at which point throwing the old settings away
    // because nothing was plugged in yet would be the worst possible moment.
    property var pendingBarMigration: null

    function migrateBarWidgets(stored: var): void {
        if (!stored || typeof stored !== "object")
            return;

        // Already in the new shape. Also the normal path on every reload after
        // the first write, and on every launch from then on.
        if (stored.barWidgetsByMonitor && Object.keys(stored.barWidgetsByMonitor).length > 0)
            return;

        const overrides = (stored.barOverrides && typeof stored.barOverrides === "object") ? stored.barOverrides : {};

        // The base the old model resolved against. A key the file does not
        // carry falls back to TRUE and not to the seed: true is what the old
        // defaults said, and reconstructing that model with this model's
        // answers would be reading the file wrong on purpose.
        const base = {};
        let legacy = Object.keys(overrides).length > 0;

        for (const widget of root.barWidgets) {
            const value = stored[root.legacyBarKeys[widget]];

            if (typeof value === "boolean") {
                base[widget] = value;
                legacy = true;
            } else {
                base[widget] = true;
            }
        }

        if (!legacy) {
            root.pendingBarMigration = null;
            return;
        }

        const keys = [];
        const add = key => {
            if (key && keys.indexOf(key) < 0)
                keys.push(key);
        };

        Object.keys(overrides).forEach(add);
        (Array.isArray(stored.barMonitors) ? stored.barMonitors : []).forEach(add);
        if (typeof stored.mainMonitor === "string")
            add(stored.mainMonitor);
        Quickshell.screens.forEach(screen => add(root.screenKey(screen)));

        // No key to write under yet. Keep the old shape and try again when a
        // screen appears; see pendingBarMigration.
        if (keys.length === 0) {
            root.pendingBarMigration = stored;
            return;
        }

        const next = {};

        for (const key of keys) {
            const over = (overrides[key] && typeof overrides[key] === "object") ? overrides[key] : {};
            const set = {};

            for (const widget of root.barWidgets)
                set[widget] = over[widget] !== undefined ? over[widget] === true : base[widget];

            next[key] = set;
        }

        root.pendingBarMigration = null;
        root.barWidgetsByMonitor = next;
    }

    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            if (root.pendingBarMigration)
                root.migrateBarWidgets(root.pendingBarMigration);
        }
    }

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

    // ---------------- Recording ----------------
    //
    // WHAT A CAPTURE OF THIS SCREEN LOOKS LIKE, for the two programs that make
    // one. Until the recording page existed, all of it was a literal in
    // modules/recorder: the buffer was 30 seconds at 60 fps, h264 in mp4 at 40
    // Mbit/s CBR with aac audio, and the microphone was one particular NZXT USB
    // mic named in full -- on any other machine that name resolves to nothing
    // and the preference silently falls back to default_input. None of it was
    // wrong; none of it was reachable either.
    //
    // TWO PREFIXES, AND THE SPLIT IS THE PROGRAM. `replay*` is the buffer's own
    // machinery -- whether it is armed, how long it keeps, which screen, where
    // it saves -- and only gpu-screen-recorder has any of that. `recording*` is
    // what a capture LOOKS like, and the buffer obeys all of it.
    //
    // A MANUAL RECORDING OBEYS TWO OF THE recording* VALUES, not six, and that
    // is a fact about wf-recorder rather than a gap to fill in later. It takes
    // the container, because the muxer follows the extension of -f; and it
    // takes desktop audio as a yes or no, because -a takes ONE device and
    // cannot merge a microphone into it the way gsr's `default_output|device:`
    // does. The codec names it wants are ffmpeg's -- libx264, h264_vaapi --
    // which are not the names gsr's --info prints, and mapping between them
    // would be a translation layer able to produce a recorder that refuses to
    // start for reasons neither program said. The recording page says as much
    // beside the controls.
    //
    // ALL OF IT IS A COMMAND-LINE FLAG, so none of it can change under a
    // running recorder: the buffer comes back when any of these move, and the
    // seconds it was holding are gone. See ReplayState.reapply().

    // Is the buffer meant to be armed? IT USED TO BE A FACT ABOUT THIS RUN OF
    // THE SHELL and it is now a setting, which is a change worth naming: armed
    // is still the resting state and the default is still true, but switching
    // it off used to last until the next reload -- and this config reloads
    // every time a .qml file is saved. A switch that comes back on by itself is
    // not a switch.
    property alias replayEnabled: adapter.replayEnabled

    // How many seconds the buffer keeps.
    //
    // 0 MEANS NOBODY HAS CHOSEN, exactly as an empty replayMonitor does, and it
    // is what makes the value below migratable: this setting used to live in
    // replay.json, a file of its own next to this one, written by ReplayState
    // through an adapter of its own. Two stores for one feature is one more
    // than the split at the top of this file describes, so it moved here -- and
    // a machine that had chosen 60 seconds would have been quietly reset to 30
    // by that move, which is exactly the kind of silent loss a settings page is
    // supposed to end. ReplayState reads the old file once and copies the
    // answer over when this is still 0. See the note on legacy in that file.
    property alias replaySeconds: adapter.replaySeconds

    // ram or disk. gsr's own default is ram, and ram is what a replay buffer is
    // for -- the cost is memory that scales with the length, which is the one
    // number the island and the settings page both show. disk is there for the
    // machine that would rather spend an SSD than 590 MB, and gsr's man page
    // says in those words that it "may reduce SSD lifespan".
    property alias replayStorage: adapter.replayStorage

    // Where clips land. Empty means ~/Videos/Replays, which is where they have
    // always landed; the same rule the two monitor settings above use, and for
    // the same reason -- a fresh clone should not need this page opened before
    // it can keep anything.
    property alias replayDirectory: adapter.replayDirectory

    // Where a manual recording lands. Empty means ~/Videos/recordings.
    property alias recordingDirectory: adapter.recordingDirectory

    // mp4 or mkv, AND IT IS A DECISION RATHER THAN A DETAIL on this machine.
    // DaVinci Resolve on Linux refuses MKV outright, so a recording made to be
    // edited has to be mp4 -- while mkv is the container that survives the
    // recorder being killed, because it does not need a header rewritten at the
    // end. mp4 stays the default: these clips are made to be sent to somebody
    // and to be cut, and the crash case is what SIGINT and gsr's own finalising
    // are for.
    property alias recordingContainer: adapter.recordingContainer

    // Frames per second the buffer captures at. The manual recorder is left to
    // follow the screen: wf-recorder's -r forces CONSTANT frame rate, which is
    // a different recording rather than the same one at a chosen rate.
    property alias recordingFramerate: adapter.recordingFramerate

    // The video codec, as gpu-screen-recorder spells it. EMPTY MEANS ITS OWN
    // `auto`, which is h264 -- and empty is the default because the honest
    // answer to "which codec" on a machine nobody has asked about is the one
    // the recorder picks for itself. What can be picked here is not a literal:
    // the recording page reads `gpu-screen-recorder --info` and offers the
    // section=video_codecs list that THIS card reports, because offering a
    // codec the GPU cannot do is how a buffer refuses to arm.
    property alias recordingCodec: adapter.recordingCodec

    // cbr, vbr or qp. CBR is what gsr's man page recommends for a replay buffer
    // and it is also what makes the memory cost predictable: a buffer is its
    // bitrate times its duration and nothing else, which is the number on the
    // island. In qp and vbr the size varies with what is on screen, so that
    // reading stops being a number and says so.
    property alias recordingBitrateMode: adapter.recordingBitrateMode

    // Kbit/s, and only CBR reads it. gsr's -q is overloaded: a number of kbit/s
    // in CBR, and one of four named presets in qp and vbr. Two settings rather
    // than one because they are two different values -- a page that stored
    // "40000" and sent it to a qp recorder would be sending a preset name that
    // does not exist.
    property alias recordingBitrate: adapter.recordingBitrate

    // medium, high, very_high or ultra: -q in qp and vbr. very_high is gsr's
    // own default.
    property alias recordingQuality: adapter.recordingQuality

    // Is the machine's own sound in the recording? Both programs obey this one.
    property alias recordingDesktopAudio: adapter.recordingDesktopAudio

    // Is the microphone in it? The buffer merges it into the desktop track --
    // gsr's `default_output|device:NAME` is ONE track containing both, because
    // two -a flags give a file with two audio tracks and most players play only
    // the first.
    property alias recordingMicrophone: adapter.recordingMicrophone

    // WHICH microphone, as PipeWire names the node. EMPTY IS "SYSTEM DEFAULT"
    // and it is not the same kind of empty as the monitor settings above: this
    // one is a real answer somebody can choose, and it means gsr's
    // `default_input` -- follow whatever the system currently calls the input.
    //
    // A NAME THAT IS NOT PRESENT IS THE DANGEROUS CASE, which is why the shell
    // resolves this against the live node list before it ever reaches a command
    // line: gpu-screen-recorder given an audio device that does not exist
    // REFUSES TO START AT ALL. Storing the name is still right -- it is what
    // survives the device being unplugged over lunch -- but it is a preference
    // and never a requirement. See ReplayState.microphone.
    property alias recordingMicrophoneDevice: adapter.recordingMicrophoneDevice

    // aac, opus or flac. AAC AND NOT THE mp4 DEFAULT OF opus, and the reason is
    // where these clips go: opus-in-mp4 is the combination some players and
    // some editors refuse, and a clip that will not open is worth more to fix
    // than the bitrate it saves. flac is lossless and large; it is offered
    // because gsr offers it, not because anything here wants it.
    property alias recordingAudioCodec: adapter.recordingAudioCodec

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
        // Every bar back to the seed, which is a deletion and not eight
        // assignments: with no shared base left there is nothing to restore
        // TO except the seed, and an empty map is how a bar says it follows it.
        // Back to one bar on the monitor the rule picks, with no monitor
        // holding an opinion of its own. The Hyprland side is deliberately NOT
        // reset from here: desktop-monitors owns that file, and a "restore
        // defaults" in this window that silently moved the compositor's game
        // rules would be reaching a long way outside the shell.
        adapter.mainMonitor = root.defaults.mainMonitor;
        adapter.barMonitors = root.defaults.barMonitors;
        adapter.barWidgetsByMonitor = ({});
        // Back to recording whatever screen the shell ends up on. This one
        // restarts the replay buffer as it lands -- see ReplayState.monitor --
        // which costs the seconds it was holding, and that is the same cost
        // changing the buffer length has always had.
        adapter.replayMonitor = root.defaults.replayMonitor;

        // And back to the capture this shell shipped with. EVERY ONE OF THESE
        // RESTARTS THE BUFFER as it lands -- see ReplayState.reapply() -- so a
        // restore costs the seconds it was holding, once, rather than once per
        // value: they are assigned in the same turn and the recorder is taken
        // down and brought back after it.
        //
        // replayEnabled IS RESET WITH THE REST, which means a buffer somebody
        // switched off comes back armed. That is the intended reading of
        // "restore defaults" -- armed is the state this shell ships in -- and
        // it is visible the instant it happens, on the island and on this page.
        adapter.replayEnabled = root.defaults.replayEnabled;
        adapter.replaySeconds = root.defaults.replaySeconds;
        adapter.replayStorage = root.defaults.replayStorage;
        adapter.replayDirectory = root.defaults.replayDirectory;
        adapter.recordingDirectory = root.defaults.recordingDirectory;
        adapter.recordingContainer = root.defaults.recordingContainer;
        adapter.recordingFramerate = root.defaults.recordingFramerate;
        adapter.recordingCodec = root.defaults.recordingCodec;
        adapter.recordingBitrateMode = root.defaults.recordingBitrateMode;
        adapter.recordingBitrate = root.defaults.recordingBitrate;
        adapter.recordingQuality = root.defaults.recordingQuality;
        adapter.recordingDesktopAudio = root.defaults.recordingDesktopAudio;
        adapter.recordingMicrophone = root.defaults.recordingMicrophone;
        adapter.recordingMicrophoneDevice = root.defaults.recordingMicrophoneDevice;
        adapter.recordingAudioCodec = root.defaults.recordingAudioCodec;
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
    // HAS THE FILE BEEN READ YET? Nothing needed to know until the recorder
    // did, and what it needs it for is worth spelling out: the read is
    // asynchronous, so for the first turns of the shell's life every property
    // above reads its DEFAULT rather than what is on disk. A binding that only
    // paints is fine with that -- it repaints. A binding that SPAWNS A PROCESS
    // built out of these values is not: the buffer would arm at the defaults,
    // the real settings would land a moment later, and the recorder would be
    // torn down and rebuilt for nothing at every login.
    //
    // True after the first read either way, because a machine with no file yet
    // has read everything there is to read: onLoadFailed writes the defaults
    // and those defaults are already what the properties hold.
    property bool loaded: false

    FileView {
        id: file

        path: Quickshell.statePath("config.json")
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // TWO THINGS ON LOAD, and the order matters. The migration reads the
        // raw text and rewrites the bar shape, so it has to finish before
        // anything is told the config is usable -- a consumer that armed itself
        // on `loaded` would otherwise see the pre-migration values for one turn.
        onLoaded: {
            try {
                root.migrateBarWidgets(JSON.parse(file.text()));
            } catch (e) {
                // A file this cannot parse is one FileView has already
                // complained about; there is nothing here worth a second
                // error, and the adapter has kept its defaults either way.
            }
        
            root.loaded = true;
        }
        onLoadFailed: {
            root.loaded = true;
            writeAdapter();
        }

        // The one thing that has to happen between the file being read and
        // anything being written back: a config in the old bar shape is folded
        // into the new one from the RAW TEXT, because the old keys are no
        // longer declared on the adapter and the first write would drop them.
        // See the migration section above. It parses the file a second time,
        // once per load, which is a few hundred bytes of JSON and is the price
        // of not keeping a dead shape declared forever.

        JsonAdapter {
            id: adapter

            property bool use24Hour: true
            property bool showDate: true
            property int notificationTimeout: 10
            property bool nightLightScheduled: false
            property int nightLightFrom: 1200
            property int nightLightTo: 420
            // See the monitor section above for what goes in these three and
            // why the empty values mean "decide for me" rather than "nothing".
            property string mainMonitor: ""
            property var barMonitors: []
            property string replayMonitor: ""
            // See the Recording section above. Every one of these was a
            // literal in modules/recorder until this page existed.
            property bool replayEnabled: true
            property int replaySeconds: 0
            property string replayStorage: "ram"
            property string replayDirectory: ""
            property string recordingDirectory: ""
            property string recordingContainer: "mp4"
            property int recordingFramerate: 60
            property string recordingCodec: ""
            property string recordingBitrateMode: "cbr"
            property int recordingBitrate: 40000
            property string recordingQuality: "very_high"
            property bool recordingDesktopAudio: true
            property bool recordingMicrophone: true
            property string recordingMicrophoneDevice: ""
            property string recordingAudioCodec: "aac"
            // One complete widget set per monitor; see the widget section
            // above. The eight `barLogo`-style booleans and the sparse
            // `barOverrides` map that used to sit here are gone, and a file
            // still carrying them is folded into this one on load -- which is
            // also why they cannot stay declared: an adapter writes back every
            // property it declares, so the old keys would never leave the file.
            property var barWidgetsByMonitor: ({})
        }
    }
}
