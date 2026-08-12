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
// THREE OF THEM HAVE NO SWITCH, deliberately. The workspaces and the island
// are how you know where you are and what the desktop is doing; the power
// button is the only pointer-reachable way to end the session. A settings
// window able to hide the way out is one that can strand somebody.

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
        "language", "indicator"]

    SettingsSection {
        width: parent.width
        glyph: Icons.windowTiles
        title: "Widgets"

        ToggleRow {
            glyph: Icons.arch
            label: "Distribution logo"
            checked: Config.barLogo
            onToggled: value => Config.barLogo = value
        }

        ToggleRow {
            glyph: Icons.window
            label: "Focused window title"
            checked: Config.barActiveWindow
            onToggled: value => Config.barActiveWindow = value
        }

        ToggleRow {
            glyph: Icons.apps
            label: "System tray"
            checked: Config.barTray
            onToggled: value => Config.barTray = value
        }

        ToggleRow {
            glyph: Icons.battery
            label: "Peripheral battery"
            checked: Config.barBattery
            onToggled: value => Config.barBattery = value
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
            checked: Config.barKeyboardLayout
            onToggled: value => Config.barKeyboardLayout = value
        }

        Text {
            visible: Config.barKeyboardLayout && Config.keyboardLayouts.length < 2

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
            checked: Config.barClock
            onToggled: value => Config.barClock = value
        }

        ToggleRow {
            glyph: Icons.settings
            label: "Settings button"
            checked: Config.barSettingsButton
            onToggled: value => Config.barSettingsButton = value
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
            visible: !Config.barSettingsButton

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
