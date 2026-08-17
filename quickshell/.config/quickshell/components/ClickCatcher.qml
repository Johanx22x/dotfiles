// The generic "click anywhere else to dismiss", for compositors with no grab
// protocol of their own.
//
// A transparent layer surface covering the whole screen, sitting UNDER the
// thing it is dismissing. Any click that is not on that thing lands here
// instead, which is the only portable way to hear about a click that was never
// meant for us: a Wayland client is not told about input it does not receive.
//
// WHY THE LAYER MATTERS MORE THAN THE CREATION ORDER
// It has to be below the popout and above everything else. Stacking WITHIN one
// layer is decided by creation order, which is not something to rely on, so
// this sits on Top while the surfaces it serves sit on Overlay -- the layers
// themselves guarantee the order, and nothing has to be created in a
// particular sequence for it to work.
//
// It takes no keyboard focus. The surface being dismissed keeps whatever focus
// mode it asked for, and this only ever catches the pointer.
//
// Cost, stated plainly because it is a real difference from a compositor-side
// grab: the click that dismisses is SWALLOWED here, so it does not also reach
// the window underneath. With HyprlandFocusGrab the compositor drops the grab
// and the click goes on to do whatever it was going to do. One click versus
// two, and no way around it from this side of the protocol.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property var targetScreen
    signal dismissed

    screen: targetScreen
    color: "transparent"

    WlrLayershell.namespace: "quickshell-click-catcher"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The whole screen, and no room reserved for it.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
        anchors.fill: parent
        // Every button, so a right-click outside dismisses too -- which is what
        // a menu is expected to do.
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.dismissed()
    }
}
