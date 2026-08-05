// What the bar shows.
//
// ONLY THE CLOCK SO FAR, and the emptiness is honest rather than unfinished:
// the rest of the bar is a set of decisions with reasons written next to them
// -- which widget sits where, why the island is centred, why the power button
// is last -- and turning those into switches would be offering to undo the
// design. What lands here is the narrow set where there is no right answer.

import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Bar"
    glyph: Icons.windowTiles
    keywords: ["bar", "clock", "time", "date", "panel", "24 hour"]

    SettingsSection {
        width: parent.width
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
