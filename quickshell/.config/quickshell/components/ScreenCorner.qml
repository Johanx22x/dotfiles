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

import Quickshell
import Quickshell.Wayland
import QtQuick
import "root:/"

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

    CornerWedge {
        anchors.fill: parent
        corner: root.corner
        radius: Theme.screenCornerRadius
        fillColor: Theme.screenBezel
    }
}
