// PROBE: what does niri's ext-background-effect blur actually blur?
//
// Two identical translucent patches side by side on DP-3. The LEFT one asks
// for blur behind itself through ext-background-effect; the RIGHT one asks for
// nothing. Whatever is on the workspace shows through both, so one capture
// answers the question:
//
//   - left shows a blurred version of the WINDOW behind it  -> not xray
//   - left shows blurred WALLPAPER while the right shows the window -> xray
//
// The namespace is deliberately not the shell's, the surface takes no input
// (empty mask) and it is killed by a recorded PID, never by name.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens.filter(s => s.name === "DP-3")

        PanelWindow {
            id: probe

            required property var modelData

            screen: modelData
            WlrLayershell.namespace: "blur-spike-xray"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            // Nothing here is clickable: the desktop underneath keeps its input.
            mask: Region {}

            BackgroundEffect.blurRegion: Region {
                x: 200
                y: 200
                width: 500
                height: 400
            }

            // Blurred, magenta border.
            Rectangle {
                x: 200; y: 200; width: 500; height: 400
                color: Qt.rgba(1, 1, 1, 0.15)
                border.color: "#ff00ff"
                border.width: 2
            }

            // Same paint, same backdrop, no blur asked for. Green border.
            Rectangle {
                x: 200; y: 700; width: 500; height: 400
                color: Qt.rgba(1, 1, 1, 0.15)
                border.color: "#00ff00"
                border.width: 2
            }
        }
    }
}
