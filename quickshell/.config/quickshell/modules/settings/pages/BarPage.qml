// What the bar shows, one bar at a time.
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
//
// ONE SECTION PER BAR, AND NO SCOPE SELECTOR. Every bar carries its own
// complete set of widgets now -- see Config's widget section for the model and
// for what was given up to get it -- so the switches below are drawn once per
// bar, under a heading naming the monitor they belong to.
//
// WHAT WAS HERE BEFORE AND WHY IT IS NOT. A ChoiceRow labelled "These switches
// change" offered "All" plus each monitor, and the switches underneath meant
// whichever of those was selected. Two things were wrong with it and only one
// was the model's fault. The control was dead on a machine with one bar, where
// "All" and "that monitor" are the same thing and every option did the same
// work. And it was worse than dead with two: the switches look identical
// whichever way it is pointed, so a change landing on the wrong bar is
// invisible from here -- the other screen is behind this window. A heading
// that names the monitor cannot be pointed at the wrong one.
//
// It also had a ceiling. ChoiceRow's own header puts it at about four options
// at this width, which was three monitors plus "All", and a fourth screen
// would have made the segments too narrow to label. Sections have no such
// number in them: the page gets longer, which is the honest cost of eight
// switches per bar and the reason the sections are drawn only for the monitors
// that actually carry one.

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
        "display", "second monitor", "per monitor", "reset", "defaults"]

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

    // ---------------- Monitors ----------------
    //
    // HIDDEN ON A SINGLE-MONITOR MACHINE, which is the one place in this window
    // where hiding a control is right: with one screen the only row here
    // answers a question that cannot come up -- where the bar goes -- and the
    // answer would be the same whatever you pressed.
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
    }

    // ---------------- The widgets, once per bar ----------------
    //
    // DRAWN FOR THE MONITORS THAT CARRY A BAR AND NOT FOR ALL OF THEM. Eight
    // switches for a bar that is not on screen would be eight controls with
    // nothing to change, which is the failure the rows above were written to
    // avoid; and switching a bar on here makes its section appear, which ties
    // the two halves of the page together without a word of explanation.
    //
    // Screens.barScreens and not Config.barMonitors, so the fallbacks are part
    // of the answer: an empty stored list means the main monitor, and a list
    // whose monitors are all unplugged falls back to it too. A section per
    // SCREEN also means an unplugged monitor's section simply goes, taking with
    // it the old problem of switches pointed at a screen that is not there.
    Repeater {
        model: Screens.barScreens

        SettingsSection {
            id: barSection

            required property var modelData

            readonly property string key: Config.screenKey(modelData)

            // root.width and not parent.width, which is what DisplayPage's own
            // per-monitor sections do: a Repeater reparents its delegates, so
            // `parent` here is resolved at creation and is one more thing to be
            // wrong about. The page's width is not.
            width: root.width
            glyph: Icons.windowTiles

            // Named only when there is more than one bar to tell apart. With a
            // single bar the monitor's name answers nothing -- there is nowhere
            // else the switches could be landing -- and a heading reading
            // "Widgets on PG32QF2B (DP-1)" above the only card on the page is
            // the same furniture the scope selector was.
            title: root.barCount > 1 ? `Widgets on ${root.screenLabel(modelData)}` : "Widgets"

            ToggleRow {
                glyph: Icons.arch
                label: "Distribution logo"
                checked: Config.barWidget(barSection.key, "logo")
                onToggled: value => Config.setBarWidget(barSection.key, "logo", value)
            }

            ToggleRow {
                glyph: Icons.window
                label: "Focused window title"
                checked: Config.barWidget(barSection.key, "activeWindow")
                onToggled: value => Config.setBarWidget(barSection.key, "activeWindow", value)
            }

            // The island, and this is the row the second bar is for: the pill in
            // the middle saying what is playing, what changed and what is being
            // captured. One of them is the desktop talking; two of them is the
            // same sentence twice -- which is why a new bar now starts without
            // one, and why this switch is the one most likely to be the reason
            // somebody opened this section.
            ToggleRow {
                glyph: Icons.widgets
                label: "Island"
                checked: Config.barWidget(barSection.key, "island")
                onToggled: value => Config.setBarWidget(barSection.key, "island", value)
            }

            // Same shape as the note under the settings button: a switch that can
            // hide a way in says where the other one is. The badges either side of
            // it stay -- they are anchored to the middle of the bar, not to the
            // island -- which is worth saying before somebody reads their staying
            // as the switch not having worked.
            Text {
                visible: !Config.barWidget(barSection.key, "island")

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
                checked: Config.barWidget(barSection.key, "tray")
                onToggled: value => Config.setBarWidget(barSection.key, "tray", value)
            }

            ToggleRow {
                glyph: Icons.battery
                label: "Peripheral battery"
                checked: Config.barWidget(barSection.key, "battery")
                onToggled: value => Config.setBarWidget(barSection.key, "battery", value)
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
                checked: Config.barWidget(barSection.key, "keyboardLayout")
                onToggled: value => Config.setBarWidget(barSection.key, "keyboardLayout", value)
            }

            Text {
                visible: Config.barWidget(barSection.key, "keyboardLayout") && Config.keyboardLayouts.length < 2

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
                checked: Config.barWidget(barSection.key, "clock")
                onToggled: value => Config.setBarWidget(barSection.key, "clock", value)
            }

            ToggleRow {
                glyph: Icons.settings
                label: "Settings button"
                checked: Config.barWidget(barSection.key, "settingsButton")
                onToggled: value => Config.setBarWidget(barSection.key, "settingsButton", value)
            }

            // The one switch that can hide its own way back, so it says where the
            // other one is. SUPER + C is in the keybinds page too, but somebody
            // who has just made the gear disappear is looking at this row, not at
            // that page.
            Text {
                visible: !Config.barWidget(barSection.key, "settingsButton")

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

            // REPURPOSED RATHER THAN REMOVED. This row used to read "This
            // monitor's exceptions / Drop them and follow All again", which was
            // the only way to get a screen back to inheriting once it had
            // disagreed. With nothing left to inherit from, the sentence has no
            // referent -- but the button still has a job, because eight
            // switches is enough that "put this bar back" is a thing to want
            // and clicking eight times is not it.
            //
            // Still only when there is something to undo, and it still says
            // what it would undo: a reset on a bar that already matches the
            // seed is a button that does nothing, and one that has been clicked
            // once with no visible result is one nobody trusts again.
            //
            // A ROW AND NOT THE SECTION'S HEADING CHIP, which is where
            // SettingsSection's own header argues a section-wide action
            // belongs, and the argument is a good one -- a chip costs no
            // vertical space and does not look like a setting. It loses here on
            // one point only: a chip has nowhere to put the line underneath,
            // and after the change above that line is the whole explanation of
            // what "reset" now means.
            ActionRow {
                visible: !Config.barIsDefault(barSection.key)

                glyph: Icons.restore
                label: "This bar's widgets"
                description: "Back to the set a new bar starts with."
                actionText: "Reset"
                actionGlyph: Icons.restore
                onTriggered: Config.resetBar(barSection.key)
            }
        }
    }

    // ---------------- Laptop ----------------
    //
    // A SECTION OF ITS OWN NOW, because these two are not per-bar and the
    // widgets above are. `laptop-modules` writes one answer for the MACHINE --
    // whether it has a battery and a backlight at all -- and repeating that
    // question once per monitor would be asking which screens the hardware is
    // attached to, which is not a question.
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
    SettingsSection {
        width: parent.width
        glyph: Icons.laptop
        title: "Laptop"

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
    }

    // ---------------- Clock ----------------
    //
    // ONE ANSWER FOR EVERY BAR, and the one place on this page where that is
    // still right. Whether a bar HAS a clock is per bar, above; whether a clock
    // is written in 24-hour time is about how this person reads a time, and two
    // clocks on two screens disagreeing about it would be a bug, not a setting.
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
