// One rounded corner of the screen.
//
// A small opaque wedge pinned to a corner of the monitor, so what shows
// through is a rounded display edge. It belongs to the SCREEN, not to the
// bar -- the bar happens to be underneath the two top ones, and that is
// precisely the effect: the bar looks clipped by the panel edge rather than
// rounded itself.
//
// It takes no input at all (empty mask), so clicking a window's corner still
// hits the window.
//
// Layer Top and not Overlay on purpose: a fullscreen window in Hyprland
// covers the Top layer, so the corners get out of the way for games and
// video instead of clipping them.
//
// IT HAS NO THEME HALF, AND THAT IS THE WHOLE FINDING OF SPLITTING IT.
// Everything above is a fact about a Wayland layer surface: the namespace, the
// layer, the anchors the corner string picks out, the empty input mask, the
// exclusion mode and the size the surface takes. A theme draws inside a window;
// it does not get to reconfigure one -- the same sentence components/Popout.qml
// opens with. What is left over, once all of that is set aside, is exactly one
// drawn thing: the wedge at the bottom of this file.
//
// So this file is not a facade with a Loader in it. Its one drawn thing is a
// component that IS split, and a themes/genesis/components/ScreenCorner.qml
// would be a second Loader wrapped around the first for no gain: the same
// pixels, two more objects per corner -- a Loader and the item it holds -- so
// eight more per monitor, and a theme still unable to change anything about
// the window it sits in. A theme that
// wants square screen corners says so where that is one line -- its
// CornerWedge draws nothing -- and these four windows go on existing,
// reserving nothing and taking no input, which is what they already do.

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

PanelWindow {
    id: root

    required property var modelData

    // "topLeft" | "topRight" | "bottomLeft" | "bottomRight"
    required property string corner

    readonly property bool isTop: corner === "topLeft" || corner === "topRight"
    readonly property bool isLeft: corner === "topLeft" || corner === "bottomLeft"

    screen: modelData

    WlrLayershell.namespace: "quickshell-screen-corner"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: root.isTop
        bottom: !root.isTop
        left: root.isLeft
        right: !root.isLeft
    }

    implicitWidth: Theme.screenCornerRadius
    implicitHeight: Theme.screenCornerRadius

    color: "transparent"

    // No input anywhere: an empty region.
    mask: Region {}

    // Never reserve space, and never be pushed around by the bar's
    // reservation -- these sit on the physical corner of the panel.
    exclusionMode: ExclusionMode.Ignore

    // The one thing on the screen. components/CornerWedge.qml is a facade now,
    // so what is actually painted here is the running theme's -- including,
    // legitimately, nothing at all. The window is the same size either way.
    CornerWedge {
        anchors.fill: parent
        corner: root.corner
        radius: Theme.screenCornerRadius
        fillColor: Theme.screenBezel
    }
}
