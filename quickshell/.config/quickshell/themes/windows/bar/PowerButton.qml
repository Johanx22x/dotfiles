// Power options. The only control on this bar that can end the session.
//
// IT IS NOT AT THE END OF THE BAR ANY MORE, AND THAT IS THIS FILE'S OWN RULE
// BEING KEPT. What this button has asked for since it moved out from under the
// logo is that nothing sit one slipped click from it. On a bar across the top
// of the screen the far right end satisfied that, because it was the end of a
// row of controls; on a bar across the BOTTOM the far right end is the
// bottom-right corner of the screen -- the one target a pointer cannot
// overshoot, the same fact Logo.qml spends a paragraph on from the other side.
// Giving the session-ending control the easiest click on the desktop is the
// opposite of what this file has always asked for. The clock and the
// notification centre take that corner instead; see Bar.qml.
//
// THE FILL IS WINDOWS' AND THE INK IS OURS. Every hover in a Windows taskbar is
// the same subtle brush whatever the item does, so the backplate here is the
// one TaskbarItem draws and nothing else. The GLYPH still turns Theme.critical:
// every other hover in this corner promises "this opens something" and this one
// has to promise something else, and colour is the cheapest way to say it
// before the click. That is a deviation from Windows and it is deliberate --
// Windows has no destructive control on its taskbar to disagree with.

import QtQuick
import qs
import qs.modules.powermenu

TaskbarItem {
    id: root

    // The shell's own menu, not the wofi script. Toggle and not open: clicking
    // the button that opened it should put it away again.
    onActivated: PowerMenuState.toggle()

    Text {
        anchors.centerIn: parent

        text: Icons.power
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: root.hovered ? Theme.critical : Theme.textOnSurfaceVariant
    }
}
