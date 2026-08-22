// The Hyprland-native "click anywhere else to dismiss".
//
// The compositor hands the window an input grab and drops it the moment the
// user clicks elsewhere.
//
// IT DOES NOT PASS THAT CLICK ON, whatever this file used to claim. The line
// here said the click that dismisses still reaches whatever was under it, so
// closing a popout and pressing a button took one click rather than two. That
// was measured on Hyprland 0.56.2, twice, in separate sessions, driven by a
// virtual pointer one click at a time: the widget under the pointer receives
// NOTHING -- no press, no release, no click, no cancel -- and the popout
// simply closes. Switching from one of the bar's panels to the next costs two
// clicks here, and the same click on the same coordinates with no grab active
// reaches the widget perfectly, which is what rules out a mis-aimed click.
//
// So this is not the better half of a trade-off with ClickCatcher; it is the
// same behaviour arrived at differently, minus the extra surface. The portable
// side can be given a hole for the bar and this cannot, which is the one place
// they now genuinely differ -- see the header of ClickCatcher.qml.
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
