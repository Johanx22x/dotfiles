// COST OF THE COMPOSITOR ROUTE: the same strip, asking niri for blur behind it
// through ext-background-effect. Nothing is measured in this process that the
// baseline does not also do -- the work moves into niri, so niri is the process
// to watch while this one is up.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens.filter(s => s.name === "DP-3")

        PanelWindow {
            id: probe

            required property var modelData
            readonly property int barH: 44

            screen: modelData
            WlrLayershell.namespace: "blur-spike-cost-blur"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true }
            implicitHeight: probe.barH
            color: "transparent"
            mask: Region {}

            BackgroundEffect.blurRegion: Region {
                x: 0
                y: 0
                width: probe.width
                height: probe.barH - 1
                bottomLeftRadius: 19
                bottomRightRadius: 19
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.09, 0.09, 0.12, 0.85)
            }
        }
    }
}
