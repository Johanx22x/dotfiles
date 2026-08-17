// The Hyprland-native "click anywhere else to dismiss".
//
// The compositor hands the window an input grab and drops it the moment the
// user clicks elsewhere. Better than the portable fallback in one concrete way:
// the click that dismisses still reaches whatever was under it, so closing a
// popout and pressing a button take one click rather than two.
//
// IN ITS OWN FILE, and that is the point rather than tidiness. `import
// Quickshell.Hyprland` loads the module and makes it bind to the compositor, so
// a file that imports it unconditionally would drag Hyprland's protocols into a
// niri session -- which is where the "Compositor does not support
// hyprland-toplevel-mapping-v1" warning comes from. FocusGrab.qml loads this by
// URL, so under any other compositor this file is never read and the import
// never happens.

import Quickshell.Hyprland
import QtQuick

Item {
    id: root

    property bool grabActive: false
    property var grabWindows: []
    signal dismissed

    HyprlandFocusGrab {
        active: root.grabActive
        windows: root.grabWindows

        // The grab is dropped by the compositor as soon as the user clicks
        // outside, which is the signal to close.
        onActiveChanged: if (!active && root.grabActive)
            root.dismissed()
    }
}
