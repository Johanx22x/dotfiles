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
        "widgets", "tray", "logo", "title", "battery", "hide"]

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
