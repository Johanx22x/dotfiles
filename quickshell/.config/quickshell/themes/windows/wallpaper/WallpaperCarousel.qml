// NOT DRAWN YET.
//
// One of the seven surfaces the host loads by path. It declares its own
// window, because that is where a surface's anchors, layer and exclusive zone
// live -- and it draws nothing until this surface's turn comes.
//
// The namespace is not decorative: Hyprland's blur-quickshell layer rule
// matches on it, and a namespace that is not on that list falls through to the
// global blur with different parameters and no xray.

import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    visible: false

    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay

    implicitWidth: 1
    implicitHeight: 1
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
}
