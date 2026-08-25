// PROBE: Route A -- capture what is behind the panel, blur it here, mask it
// with the same antialiased shape the panel is painted with.
//
// Quickshell's ScreencopyView can only take a whole OUTPUT as its capture
// source on niri (wlr-screencopy-unstable-v1; the ext-image-copy-capture and
// hyprland-toplevel-export backends are not advertised), and the protocol
// copies the output's COMPOSITED contents. There is no way to ask it to leave
// the requesting client out.
//
// The panel is the shell's worst case: a full width strip at the top of the
// screen, always visible, so the capture and the blur never stop.
//
//   - top strip:   the finished thing -- blurred capture, masked, glass on top
//   - bottom left: the SAME capture drawn raw at 1/4 scale, which is where the
//                  feedback shows if there is any
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

            screen: modelData
            WlrLayershell.namespace: "blur-spike-screencopy"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}

            ScreencopyView {
                id: capture

                x: 0
                y: 0
                width: probe.modelData.width
                height: probe.modelData.height
                captureSource: probe.modelData
                live: true
                visible: false
                layer.enabled: true
            }

            // The shape: a strip with the two bottom corners rounded, drawn as
            // coverage rather than as a path.
            Item {
                id: shape

                width: probe.width
                height: probe.barH
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    bottomLeftRadius: 20
                    bottomRightRadius: 20
                    antialiasing: true
                    color: "black"
                }
            }

            MultiEffect {
                width: probe.width
                height: probe.barH

                source: capture
                blurEnabled: true
                blur: 1.0
                blurMax: 64

                maskEnabled: true
                maskSource: shape
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle {
                width: probe.width
                height: probe.barH
                bottomLeftRadius: 20
                bottomRightRadius: 20
                antialiasing: true
                color: Qt.rgba(0.08, 0.08, 0.10, 0.85)
            }

            // The same capture, raw and small, to see what it contains.
            Item {
                x: 100
                y: 900
                width: probe.modelData.width / 4
                height: probe.modelData.height / 4
                clip: true

                ShaderEffectSource {
                    sourceItem: capture
                    width: probe.modelData.width
                    height: probe.modelData.height
                    scale: 0.25
                    transformOrigin: Item.TopLeft
                }
            }

            Text {
                x: 100
                y: 870
                color: "#00ff00"
                font.pixelSize: 20
                text: "hasContent=" + capture.hasContent + "  sourceSize=" + capture.sourceSize.width + "x" + capture.sourceSize.height
            }
        }
    }
}
