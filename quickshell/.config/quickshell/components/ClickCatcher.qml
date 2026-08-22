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
// COST, AND WHAT IS DONE ABOUT IT. The click that dismisses is SWALLOWED
// here, so it does not also reach the window underneath -- press a button
// while a popout is open and the first click only puts the popout away. That
// is worth one exception, and `passthrough` below is it: the bar keeps its own
// clicks, so moving from one of its panels to the next takes one click rather
// than two.
//
// This is NOT the portable path being worse than the compositor's own grab.
// Both were driven with a virtual pointer, one click at a time: under Hyprland
// 0.56.2 the click that drops a HyprlandFocusGrab reaches the widget under it
// with nothing at all -- no press, no release, no cancel -- so a bar widget is
// just as unreachable there. The difference is that a grab cannot be given a
// hole and this can.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property var targetScreen

    // A rectangle of this screen the catcher does not take input over, in
    // screen coordinates. Anything there reaches whatever is underneath --
    // for a bar popout, the bar itself. Empty by default: a catcher with no
    // hole is the plain "every click outside dismisses" this file describes.
    property rect passthrough: Qt.rect(0, 0, 0, 0)

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

    // THE HOLE IS IN THE INPUT REGION, not in the MouseArea.
    //
    // A MouseArea that ignored the strip would still be the surface the
    // compositor picks for those coordinates, and the click would land on a
    // window that decided to do nothing with it -- swallowed just the same.
    // The input region is what the compositor reads when it decides WHICH
    // surface a click belongs to, so subtracting the strip there is what sends
    // the click to the bar instead of here.
    mask: Region {
        width: root.width
        height: root.height

        Region {
            intersection: Intersection.Subtract
            x: root.passthrough.x
            y: root.passthrough.y
            width: root.passthrough.width
            height: root.passthrough.height
        }
    }

    MouseArea {
        anchors.fill: parent
        // Every button, so a right-click outside dismisses too -- which is what
        // a menu is expected to do.
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.dismissed()
    }
}
