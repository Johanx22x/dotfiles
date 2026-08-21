// Night light: the blue light filter, drawn where the screen's own settings
// are and not where the shell's colours are.
//
// ON THIS PAGE AND NOT ON APPEARANCE, which is where a colour setting
// would normally go. What this changes is not how the shell is drawn --
// it is a matrix applied to the whole output, below every window, by the
// compositor. It belongs with the other things that are true of the
// screen rather than with the things that are true of the desktop.
//
// The state and the schedule both live in NightLight.qml; this section
// only draws them. See its header for why the schedule is the shell's job
// and the filter is not.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"
// SettingsSection lives two directories UP, and QML's implicit import covers a
// file's own directory only.
import "root:/modules/settings"

SettingsSection {
    id: root

    glyph: Icons.nightLight
    title: "Night light"

    // FIRST, AND ONLY WHEN IT IS TRUE. Everything below this line is a
    // control that silently does nothing without a daemon, and a page full
    // of switches that do nothing is a worse bug than a missing feature --
    // the user concludes the setting is broken rather than absent.
    //
    // WHICH DAEMON IS NOT THIS PAGE'S BUSINESS, and that is why the sentence
    // is built around what the script answered rather than naming one.
    // `night-light` picks one per session -- hyprsunset under Hyprland,
    // wl-gammarelay-rs under niri -- and naming the wrong one is how a
    // person spends an evening trying to start a service that was never
    // going to help.
    Text {
        visible: !root.nightLightAvailable

        x: Theme.groupPadding
        width: parent.width - Theme.groupPadding * 2
        topPadding: 4
        bottomPadding: 6

        text: "Nothing below will reach the screen: this session has no blue-light "
            + "daemon. Hyprland uses hyprsunset and niri uses wl-gammarelay-rs; "
            + "`night-light show` says which one it looked for and what it found."
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        color: Theme.warning

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    ToggleRow {
        glyph: Icons.nightLight
        label: "Warm the screen"
        checked: NightLight.enabled
        // Off to the pointer while the schedule owns it. Not hidden: the
        // switch is still the clearest statement of whether the filter is
        // on right now, and watching it move at 20:00 is how you find out
        // the schedule works.
        enabled: !NightLight.scheduled && root.nightLightAvailable

        onToggled: value => NightLight.setEnabled(value)
    }

    Text {
        visible: NightLight.scheduled

        x: Theme.groupPadding
        width: parent.width - Theme.groupPadding * 2
        bottomPadding: 4

        text: "The schedule below is driving this."
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 2
        color: Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    StepperRow {
        glyph: Icons.palette
        label: "Temperature"
        value: NightLight.temperature
        from: NightLight.minTemperature
        to: NightLight.maxTemperature
        step: 100
        suffix: "K"
        enabled: root.nightLightAvailable
        hint: "Lower is warmer. 6000K is roughly daylight and is where the "
            + "screen sits with no filter at all, which is why the range "
            + "stops there — the top of the scale and the switch above "
            + "would otherwise mean the same thing."

        onMoved: value => NightLight.setTemperature(value)
    }

    ToggleRow {
        glyph: Icons.clock
        label: "Turn on automatically"
        checked: NightLight.scheduled
        enabled: root.nightLightAvailable

        onToggled: value => NightLight.setScheduled(value)
    }

    // HALF HOURS, and the value behind them is minutes since midnight --
    // see the note on `display` in StepperRow.qml. Anything finer is a
    // precision nobody has an opinion about: the difference between 20:15
    // and 20:30 for a blue light filter is not a difference.
    StepperRow {
        glyph: Icons.nightLight
        label: "From"
        value: NightLight.from
        from: 0
        to: 23 * 60 + 30
        step: 30
        display: NightLight.clockText(NightLight.from)
        enabled: NightLight.scheduled && root.nightLightAvailable

        onMoved: value => NightLight.setFrom(value)
    }

    StepperRow {
        glyph: Icons.clock
        label: "To"
        value: NightLight.to
        from: 0
        to: 23 * 60 + 30
        step: 30
        display: NightLight.clockText(NightLight.to)
        enabled: NightLight.scheduled && root.nightLightAvailable
        hint: "An end earlier than the start is the normal case, not a "
            + "mistake: 20:00 to 07:00 is the two ends of the day rather "
            + "than the middle of it, and that is what this reads it as."

        onMoved: value => NightLight.setTo(value)
    }

    // Whether there is a daemon to talk to at all, asked when the page is looked
    // at rather than polled. The same argument the Wi-Fi scanner makes: every
    // page in this window is built and alive, so `visible` is the only honest
    // signal that somebody is reading this one.
    //
    // It is asked ONCE per visit and not watched, because the answer only
    // changes when a person installs a package or a session restarts -- and
    // both of those end with a trip back to this page. Asked by DisplayPage, from
    // its single onVisibleChanged handler, next to the monitor queries -- QML
    // allows one handler per signal, and this section has no `visible` of its own
    // that means anything: it is a child of the page and goes wherever the page
    // goes. `probe()` is the whole of what it asks for.
    //
    // OPTIMISTIC UNTIL THE ANSWER ARRIVES, deliberately: the probe takes a
    // moment and controls that flash from dead to alive on every visit read as a
    // page that is broken and then recovers.
    property bool nightLightAvailable: true

    Process {
        id: nightLightProbe

        // THE SCRIPT IS ASKED, and not the process table. It used to be `pgrep
        // -x hyprsunset`, which is wrong twice over now: it names one flavor's
        // daemon, and the other one's cannot be pgrep'd at all -- the name
        // wl-gammarelay-rs is 16 characters, the kernel caps comm at 15, and
        // pgrep answers zero matches rather than an error. `night-light show`
        // already knows: it prints the backend it chose for this session and
        // whether that daemon is up.
        //
        // A BACKEND OF `none` IS THE ONLY HARD NO. Both daemons are started on
        // demand by the script, so "not running" is a state it fixes on the
        // first toggle rather than a reason to grey the controls out.
        command: ["night-light", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const backend = /^backend:\s+(\S+)$/m.exec(text);
                root.nightLightAvailable = !!backend && backend[1] !== "none";
            }
        }
    }

    // Asked by the page when somebody looks at it. Guarded, because a second
    // visit while the first answer is still on its way is a visit that has
    // nothing to add.
    function probe(): void {
        if (!nightLightProbe.running)
            nightLightProbe.running = true;
    }
}
