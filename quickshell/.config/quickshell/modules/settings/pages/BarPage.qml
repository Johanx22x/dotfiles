// What the bar shows.
//
// WHAT IS ON IT, NOT WHERE IT SITS. Which widget goes where is a set of
// decisions with reasons written next to them -- why the island is centred,
// why the power button is last, why the badges hang outside the centred row
// -- and turning those into a drag-and-drop layout editor would be offering
// to undo the design. Whether a widget is there at all is a different
// question, and one with no right answer: a tray is essential to somebody
// running Discord and clutter to somebody who is not.
//
// TWO OF THEM HAVE NO SWITCH, deliberately. The workspaces are how you know
// where you are; the power button is the only pointer-reachable way to end the
// session. A settings window able to hide the way out is one that can strand
// somebody.
//
// The island was a third until the bar could appear on more than one monitor.
// "This is how you know what the desktop is doing" argues for having an island,
// not for having one per screen, and SUPER + D opens the dashboard either way.

import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Bar"
    glyph: Icons.windowTiles
    keywords: ["bar", "clock", "time", "date", "panel", "24 hour",
        "widgets", "tray", "logo", "title", "battery", "hide",
        "laptop", "brightness", "backlight", "keyboard", "layout",
        "language", "indicator", "monitor", "monitors", "screen",
        "display", "second monitor", "per monitor"]

    // WHICH BAR THE WIDGET SWITCHES ARE EDITING. Empty is the base -- what
    // every bar shows unless its monitor says otherwise -- and a screen key is
    // one monitor's exceptions to it. See Config's monitor section for why the
    // shape is a base plus exceptions rather than one set per screen.
    property string editing: ""

    // How many of the connected monitors are carrying a bar. Used to keep the
    // last one from being switched off: an empty selection means "the main
    // monitor" rather than "nowhere" (see Screens.barScreens), so taking the
    // last bar away would put the bar back on the main monitor rather than
    // leaving none -- a switch that turns itself back on. Refusing the last one
    // is the honest reading, and it keeps a settings window from being the
    // thing that hides the settings button.
    readonly property int barCount: Screens.barScreens.length

    function screenLabel(screen: var): string {
        return `${screen.model || screen.name}${screen.model ? ` (${screen.name})` : ""}`;
    }

    // Unplugging the monitor being edited drops back to the base, rather than
    // leaving the switches pointed at a screen that is not there writing
    // exceptions nothing can show.
    Connections {
        target: Screens

        function onAllChanged(): void {
            if (root.editing && !Screens.all.some(screen => Config.screenKey(screen) === root.editing))
                root.editing = "";
        }
    }

    // ---------------- Monitors ----------------
    //
    // HIDDEN ON A SINGLE-MONITOR MACHINE, which is the one place in this window
    // where hiding a control is right: with one screen every row here answers a
    // question that cannot come up -- where the bar goes, and which bar these
    // switches mean -- and the answer would be the same whatever you pressed.
    SettingsSection {
        width: parent.width
        visible: Screens.all.length > 1
        glyph: Icons.monitor
        title: "Monitors"

        Repeater {
            model: Screens.all

            ToggleRow {
                required property var modelData

                glyph: Icons.monitor
                label: `Bar on ${root.screenLabel(modelData)}`
                checked: Screens.hasBar(modelData)
                // The last remaining bar cannot be switched off; see barCount.
                enabled: !checked || root.barCount > 1
                onToggled: value => Config.setBarOnScreen(Config.screenKey(modelData), value, Screens.mainKey)
            }
        }

        // The segments are the monitors plus "All", so this stays inside
        // ChoiceRow's four-option ceiling up to three screens. Past that the
        // control is the wrong one and this becomes a list -- worth knowing
        // before somebody plugs in a fourth.
        ChoiceRow {
            glyph: Icons.windowTiles
            label: "These switches change"
            hint: "\"All\" is what every bar shows. Pick a monitor to give that "
                + "one an exception; the rest keep following All."
            options: [{ label: "All", value: "" },
                ...Screens.all.map(screen => ({ label: screen.name, value: Config.screenKey(screen) }))]
            value: root.editing
            onChosen: value => root.editing = value
        }

        // Only when there is something to undo, and it says what it would undo:
        // "reset" on a monitor that never disagreed is a button that does
        // nothing, and one that has been clicked once with no visible result is
        // one nobody trusts again.
        ActionRow {
            visible: Config.barHasOverride(root.editing)

            glyph: Icons.restore
            label: "This monitor's exceptions"
            description: "Drop them and follow All again."
            actionText: "Reset"
            actionGlyph: Icons.restore
            onTriggered: Config.resetBarOverride(root.editing)
        }
    }

    SettingsSection {
        width: parent.width
        glyph: Icons.windowTiles
        // Says which bar is being edited, because the switches below look
        // identical either way and a change landing on the wrong monitor is
        // invisible from here -- the other screen is behind this window.
        title: root.editing ? "Widgets on this monitor" : "Widgets"

        ToggleRow {
            glyph: Icons.arch
            label: "Distribution logo"
            checked: Config.barWidget(root.editing, "logo")
            onToggled: value => Config.setBarWidget(root.editing, "logo", value)
        }

        ToggleRow {
            glyph: Icons.window
            label: "Focused window title"
            checked: Config.barWidget(root.editing, "activeWindow")
            onToggled: value => Config.setBarWidget(root.editing, "activeWindow", value)
        }

        // The island, and this is the row the second bar is for: the pill in
        // the middle saying what is playing, what changed and what is being
        // captured. One of them is the desktop talking; two of them is the same
        // sentence twice.
        ToggleRow {
            glyph: Icons.widgets
            label: "Island"
            checked: Config.barWidget(root.editing, "island")
            onToggled: value => Config.setBarWidget(root.editing, "island", value)
        }

        // Same shape as the note under the settings button: a switch that can
        // hide a way in says where the other one is. The badges either side of
        // it stay -- they are anchored to the middle of the bar, not to the
        // island -- which is worth saying before somebody reads their staying
        // as the switch not having worked.
        Text {
            visible: !Config.barWidget(root.editing, "island")

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "SUPER + D still opens the dashboard. The do-not-disturb "
                + "and capture badges stay: they belong to the middle of the "
                + "bar rather than to the island."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        ToggleRow {
            glyph: Icons.apps
            label: "System tray"
            checked: Config.barWidget(root.editing, "tray")
            onToggled: value => Config.setBarWidget(root.editing, "tray", value)
        }

        ToggleRow {
            glyph: Icons.battery
            label: "Peripheral battery"
            checked: Config.barWidget(root.editing, "battery")
            onToggled: value => Config.setBarWidget(root.editing, "battery", value)
        }

        // The switch is here; WHICH layouts it cycles through is on the Input
        // page, next to everything else about the keyboard. Turning this off
        // does not turn the layouts off -- SUPER + K still works -- it only
        // takes the reading off the bar, which is what this page is about.
        //
        // With one layout configured the pill is hidden whatever this says.
        // The row stays, and the line under it explains why nothing appeared.
        ToggleRow {
            glyph: Icons.keyboard
            label: "Keyboard layout"
            checked: Config.barWidget(root.editing, "keyboardLayout")
            onToggled: value => Config.setBarWidget(root.editing, "keyboardLayout", value)
        }

        Text {
            visible: Config.barWidget(root.editing, "keyboardLayout") && Config.keyboardLayouts.length < 2

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "Only one layout is configured, so there is nothing to "
                + "show and nothing to switch to. Add a second one under "
                + "Input and the indicator appears."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        ToggleRow {
            glyph: Icons.clock
            label: "Clock"
            checked: Config.barWidget(root.editing, "clock")
            onToggled: value => Config.setBarWidget(root.editing, "clock", value)
        }

        ToggleRow {
            glyph: Icons.settings
            label: "Settings button"
            checked: Config.barWidget(root.editing, "settingsButton")
            onToggled: value => Config.setBarWidget(root.editing, "settingsButton", value)
        }

        // ---------------- Laptop ----------------
        //
        // SHOWN ON EVERY MACHINE, INCLUDING THE ONES THEY DO NOTHING ON, and
        // that is a deliberate exception to the rule the rest of this shell
        // follows about not drawing readings with nothing to say. install.sh
        // asks the question once at install time; without these rows the
        // answer would be unreachable forever after, and a feature nobody can
        // find is a feature that does not exist. They carry a line saying what
        // they need, so an inert switch on a desktop is explained rather than
        // mysterious.
        //
        // THE BRIGHTNESS ONE IS NOT A BAR WIDGET. It sits in the island's
        // dashboard next to the volume, where a value you set by feel belongs.
        // It is here because this is the page about what the shell shows, and
        // an "Island" page for one row would be worse than a slightly wide
        // reading of "Bar".
        ToggleRow {
            glyph: Icons.laptop
            label: "Laptop battery"
            checked: Config.laptopBattery
            onToggled: value => Config.setLaptopModule("battery", value)
        }

        ToggleRow {
            glyph: Icons.brightness
            label: "Brightness slider"
            checked: Config.laptopBrightness
            onToggled: value => Config.setLaptopModule("brightness", value)
        }

        Text {
            visible: Config.laptopBattery || Config.laptopBrightness

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "These two need the hardware as well as the switch: the "
                + "battery needs one UPower reports, and the slider needs a "
                + "backlight under /sys/class/backlight. On a machine without "
                + "them they stay hidden and leave no gap."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // The one switch that can hide its own way back, so it says where the
        // other one is. SUPER + C is in the keybinds page too, but somebody
        // who has just made the gear disappear is looking at this row, not at
        // that page.
        Text {
            visible: !Config.barWidget(root.editing, "settingsButton")

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "The gear is gone. SUPER + C still opens this window."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    SettingsSection {
        width: parent.width
        glyph: Icons.clock
        title: "Clock"

        ToggleRow {
            glyph: Icons.clock
            label: "24-hour clock"
            checked: Config.use24Hour
            onToggled: value => Config.use24Hour = value
        }

        ToggleRow {
            glyph: Icons.calendar
            label: "Show the date"
            checked: Config.showDate
            onToggled: value => Config.showDate = value
        }
    }
}
