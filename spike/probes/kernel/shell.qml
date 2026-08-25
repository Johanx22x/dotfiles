// PROBE: measure niri's blur, so a client-side blur can be matched to it.
//
// One layer surface that PAINTS NOTHING and asks for blur behind a single
// rectangle. What grim captures inside that rectangle is therefore niri's
// blurred backdrop with no glass tint in front of it, which is the only way to
// compare it against a blur computed here from the same wallpaper frame.
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens.filter(s => s.name === "DP-3")

        PanelWindow {
            required property var modelData

            screen: modelData
            WlrLayershell.namespace: "blur-spike-kernel"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}

            BackgroundEffect.blurRegion: Region {
                x: 400
                y: 300
                width: 1200
                height: 800
            }
        }
    }
}
