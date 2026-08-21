// COST OF ROUTE B: the same strip, with the pre-blurred wallpaper composited
// under the glass inside one masked layer.
//
// Nothing here updates unless the wallpaper changes: the Image is decoded once
// and the mask is static, so the scene graph has one more textured quad and one
// more layer than the baseline beside it and no work per frame.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

ShellRoot {
    Variants {
        model: Quickshell.screens.filter(s => s.name === "DP-3")

        PanelWindow {
            id: probe

            required property var modelData
            readonly property int barH: 44
            readonly property string wallblur: "file:///tmp/claude-1000/-home-johan/c11ddbc5-7e23-4a19-8679-729aed84d77c/scratchpad/wallblur-DP-3.png"

            screen: modelData
            WlrLayershell.namespace: "blur-spike-cost-wallpaper"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true }
            implicitHeight: probe.barH
            color: "transparent"
            mask: Region {}

            Item {
                id: glass

                anchors.fill: parent
                visible: false
                layer.enabled: true

                Image {
                    x: 0
                    y: 0
                    source: probe.wallblur
                    cache: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.09, 0.09, 0.12, 0.85)
                }
            }

            Item {
                id: shape

                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    x: 0
                    y: -20
                    width: parent.width
                    height: parent.height + 20
                    radius: 20
                    antialiasing: true
                    color: "black"
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: glass
                maskEnabled: true
                maskSource: shape
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
    }
}
