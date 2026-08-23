// Opens the settings window. A glyph in the notification area, which on Windows
// is where an application that wants a door on the taskbar puts one -- and that
// is exactly what this shell is doing with it.
//
// NO DISC AND NO PILL. Genesis draws a circle behind this glyph on hover,
// sized six under its group so it reads as a target the glyph sits inside
// rather than a badge stuck to it. The reasoning is sound and the shape is
// genesis's: every hover in a Windows taskbar is a 4px-radius rectangle the
// full height of the item, and TaskbarItem.qml draws it.
//
// HOVER SPEAKS IN PRIMARY, which is the other half of what makes the red on the
// power button mean anything.

import QtQuick
import qs
import qs.modules.settings

TaskbarItem {
    id: root

    // Toggle and not open: clicking the button that opened the window should
    // put it away again.
    onActivated: SettingsState.toggle()

    Text {
        anchors.centerIn: parent

        text: Icons.settings
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: root.hovered ? Theme.primary : Theme.textOnSurfaceVariant
    }
}
