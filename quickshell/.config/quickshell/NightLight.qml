// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
// NIGHT LIGHT - the blue light filter, and when it comes on
// -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
//
// TWO HALVES WITH A LINE BETWEEN THEM, and the line is where this file's
// design lives. hyprsunset owns the colour matrix. The `night-light` script
// owns what was asked for -- on or off, and how warm -- in a file a terminal
// can read. This singleton owns the only part neither of them can: WHEN.
//
// hyprsunset 0.4 has no schedule at all. It takes a temperature and applies
// it; there is no configuration file, no sunset calculation, nothing that
// happens on its own. So the schedule has to live in a process that is always
// running and can watch a clock, which is this shell -- and it is expressed
// as a policy that calls the same script a person would call by hand, rather
// than as a second way of driving the daemon.
//
// WHY NOT A SYSTEMD TIMER, which would be the usual answer here and is what
// wallpaper-rotate uses. A timer that fires at 20:00 does the wrong thing on
// the evening the machine was asleep at 20:00 and woke at 20:30: the boundary
// passed with nobody watching and the filter stays off until tomorrow. This
// asks "should it be on right now" every half minute and does not care how it
// got here -- suspend, a clock change, the shell restarting mid-evening.
//
// THE STATE FILE IS THE TRUTH AND THE SCRIPT IS THE ONLY WRITER, exactly as
// with the opacity and the font: a value changed from a terminal moves the
// switch in the settings window, because both are reading the same file.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`

    // The two values the script keeps. Defaults chosen to match its own, so a
    // machine where it has never run reads the same numbers rather than
    // showing a switch in a state nothing is in.
    property bool enabled: false
    property int temperature: 4000

    readonly property int minTemperature: 2500
    readonly property int maxTemperature: 6000

    // ---------------- Setting it ----------------

    function setEnabled(value: bool): void {
        if (value === root.enabled)
            return;

        root.enabled = value;
        Quickshell.execDetached(["night-light", value ? "on" : "off"]);
    }

    // DEBOUNCED, like the opacity's stepper and for the same reason: the
    // buttons repeat while held, and each press would otherwise spawn a
    // process and a round trip to the compositor. The property moves at once
    // so the number on screen keeps up with the finger; the screen itself
    // catches up when the value settles.
    function setTemperature(value: int): void {
        root.temperature = Math.max(root.minTemperature, Math.min(root.maxTemperature, value));
        temperaturePush.restart();
    }

    Timer {
        id: temperaturePush

        interval: 200
        onTriggered: Quickshell.execDetached(["night-light", "temp", String(root.temperature)])
    }

    // ---------------- Reading it back ----------------

    FileView {
        id: stateFile

        path: `${root.stateDir}/night-light`
        watchChanges: true
        // Absent until the script has run once, which is not an error: the
        // properties already hold the same defaults it would write.
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.adopt()
    }

    function adopt(): void {
        if (temperaturePush.running)
            return;

        const lines = (stateFile.text() || "").split("\n");

        root.enabled = lines[0]?.trim() === "1";

        const parsed = parseInt(lines[1]);
        if (!isNaN(parsed) && parsed >= root.minTemperature && parsed <= root.maxTemperature)
            root.temperature = parsed;
    }

    // ---------------- The schedule ----------------
    //
    // Minutes since midnight, in half-hour steps. Stored in the shell's own
    // preferences and not in the state file, because it is the one thing here
    // the script has no use for: it never decides anything, it is told.
    //
    // Read through bindings and written through the functions below rather
    // than aliased: a QML alias can only name an id inside its own file, and
    // Config is a different singleton.
    readonly property bool scheduled: Config.nightLightScheduled
    readonly property int from: Config.nightLightFrom
    readonly property int to: Config.nightLightTo

    function setScheduled(value: bool): void {
        Config.nightLightScheduled = value;
    }

    function setFrom(minutes: int): void {
        Config.nightLightFrom = minutes;
    }

    function setTo(minutes: int): void {
        Config.nightLightTo = minutes;
    }

    // Recomputed every half minute rather than by an alarm set for the
    // boundary. See the header: an alarm is only correct on a machine that
    // was awake to hear it ring.
    property int minuteOfDay: 0

    Timer {
        running: true
        interval: 30000
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            const now = new Date();
            root.minuteOfDay = now.getHours() * 60 + now.getMinutes();
        }
    }

    // WRAPS AROUND MIDNIGHT, which is the whole difficulty and the only reason
    // this is not a single comparison. The interesting schedule is the one
    // that starts in the evening and ends in the morning, so `from` is
    // usually GREATER than `to` and the window is the two ends of the day
    // rather than the middle of it.
    readonly property bool dueNow: {
        if (!root.scheduled)
            return false;

        if (root.from === root.to)
            return false;

        return root.from < root.to
            ? root.minuteOfDay >= root.from && root.minuteOfDay < root.to
            : root.minuteOfDay >= root.from || root.minuteOfDay < root.to;
    }

    // The policy, and the only place it is applied. A Binding rather than a
    // handler on `dueNow`, so that turning the schedule ON also settles the
    // filter immediately instead of waiting for the next boundary -- a switch
    // that does nothing for four hours reads as broken.
    onDueNowChanged: root.followSchedule()
    onScheduledChanged: root.followSchedule()

    function followSchedule(): void {
        if (!root.scheduled)
            return;

        root.setEnabled(root.dueNow);
    }

    // "20:30" out of 1230. Kept here rather than in the settings page because
    // the page is not the only thing that will want to say it.
    function clockText(minutes: int): string {
        const hours = Math.floor(minutes / 60) % 24;
        const rest = minutes % 60;
        return `${String(hours).padStart(2, "0")}:${String(rest).padStart(2, "0")}`;
    }
}
