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

        root.applyEnabled(value);
    }

    // The same thing WITHOUT the equality guard, for the schedule to use.
    //
    // `enabled` is what this shell believes, and belief is not the screen.
    // hyprsunset cannot be asked what it is doing -- see the long note at the
    // top of the `night-light` script about `hyprctl hyprsunset temperature`
    // reporting the last temperature it was handed rather than the one in
    // effect -- so there is no reading that would let us tell a stale belief
    // from a true one. The only repair available is to say it again.
    //
    // setEnabled keeps its guard because it runs off a switch a person is
    // holding; this one runs twice a day and when the schedule is turned on.
    function applyEnabled(value: bool): void {
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
    //
    // MINUS ONE MEANS "THE CLOCK HAS NOT BEEN READ YET", and it is not
    // decoration -- it is the fix for a bug that shipped. This started at 0,
    // which is not "unset", it is MIDNIGHT: the bindings below evaluated once
    // before the timer had ever fired, an evening-to-morning window contains
    // midnight by definition, and so the filter came on for an instant every
    // time the shell started. Worse, it did it at any hour of the day, so a
    // reload at one in the afternoon turned the screen orange and then turned
    // it back.
    property int minuteOfDay: -1

    Timer {
        running: true
        interval: 30000
        repeat: true
        triggeredOnStart: true

        onTriggered: root.readClock()
    }

    // Read once more at startup, before anything can look at it. Timers fire
    // from the event loop, so triggeredOnStart is not early enough on its own
    // -- the property bindings are evaluated first.
    Component.onCompleted: root.readClock()

    function readClock(): void {
        const now = new Date();
        root.minuteOfDay = now.getHours() * 60 + now.getMinutes();
    }

    // WRAPS AROUND MIDNIGHT, which is the whole difficulty and the only reason
    // this is not a single comparison. The interesting schedule is the one
    // that starts in the evening and ends in the morning, so `from` is
    // usually GREATER than `to` and the window is the two ends of the day
    // rather than the middle of it.
    // PURELY A QUESTION ABOUT THE CLOCK. It used to answer false whenever the
    // schedule was off, which folded two different questions -- "is it evening"
    // and "are we obeying the schedule" -- into one property, and that is what
    // broke re-enabling the schedule inside its own window.
    //
    // With the switch in it, turning the schedule off pushed this to false and
    // turning it back on pushed it to true, so applying the schedule depended
    // on the order QML happened to deliver two changes derived from a single
    // assignment: the handler on `scheduled` could read a `dueNow` that had not
    // caught up yet, decide the filter was not due, and leave the evening
    // untinted until the next boundary hours later.
    //
    // Now the window is the window whatever the switch says, `scheduled` is
    // checked once in followSchedule, and nothing depends on that ordering.
    readonly property bool dueNow: {
        // Nothing decided until the clock has been read. See minuteOfDay.
        if (root.minuteOfDay < 0)
            return false;

        if (root.from === root.to)
            return false;

        return root.from < root.to
            ? root.minuteOfDay >= root.from && root.minuteOfDay < root.to
            : root.minuteOfDay >= root.from || root.minuteOfDay < root.to;
    }

    // The policy, and the only place it is applied. Turning the schedule ON
    // settles the filter immediately instead of waiting for the next boundary
    // -- a switch that does nothing for four hours reads as broken.
    //
    // Turning it OFF deliberately changes nothing on screen. The filter stays
    // where it was and the manual switch, live again, is how it moves; a
    // schedule one stops obeying is not a schedule that says "off".
    onDueNowChanged: root.followSchedule()
    onScheduledChanged: root.followSchedule()

    function followSchedule(): void {
        if (!root.scheduled)
            return;

        // applyEnabled and not setEnabled: this has to hold when the answer
        // has not changed. Re-enabling the schedule at nine in the evening
        // asks for exactly the state the shell already thinks it is in, and
        // the guarded version reads that as nothing to do.
        root.applyEnabled(root.dueNow);
    }

    // "20:30" out of 1230. Kept here rather than in the settings page because
    // the page is not the only thing that will want to say it.
    function clockText(minutes: int): string {
        const hours = Math.floor(minutes / 60) % 24;
        const rest = minutes % 60;
        return `${String(hours).padStart(2, "0")}:${String(rest).padStart(2, "0")}`;
    }
}
