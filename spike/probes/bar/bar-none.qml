// COST BASELINE: the bar's shape and nothing else. A full width strip at the
// top of DP-3, painted, never animated. Whatever this costs is what the shell
// pays for the bar's glass before any blur is added.
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
            WlrLayershell.namespace: "blur-spike-cost-none"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true }
            implicitHeight: probe.barH
            color: "transparent"
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.09, 0.09, 0.12, 0.85)
            }
        }
    }
}
