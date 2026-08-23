// The launcher, as the probe draws it: one flat rectangle over the whole screen
// with a word on it, shown while LauncherState.isOpen and gone otherwise.
//
// The KEYBOARD GRAB is declarative and belongs to the surface, not to a
// FocusGrab: shell.qml puts this one on `Screens.grabScreens` precisely
// because it takes an exclusive grab and two of them would be two surfaces
// fighting over the keyboard.
//
// THE SIZE COMES FROM modelData AND NOT FROM `anchors.fill: parent`. A
// PanelWindow's contentItem never reports the layer surface's size, so a child
// filling it collapses to 0x0. The `?.` and `??` are not decoration either:
// modelData is briefly undefined and a bare modelData.width is a TypeError in
// the log, which is one of the six strings tests/shell-load.sh fails on.

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.launcher

PanelWindow {
    id: root

    // The ShellScreen this surface belongs to, from Variants in shell.qml.
    required property var modelData

    screen: root.modelData

    anchors.top: true
    anchors.left: true

    implicitWidth: root.modelData?.width ?? 0
    implicitHeight: root.modelData?.height ?? 0

    visible: LauncherState.isOpen
    color: "#ff00ff"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Item {
        width: root.modelData?.width ?? 0
        height: root.modelData?.height ?? 0

        focus: true
        Keys.onEscapePressed: LauncherState.close()

        Text {
            anchors.centerIn: parent
            text: "PROBE LAUNCHER"
            color: "#ffff00"
            font.family: Theme.fontFamily
            font.pixelSize: 48
        }

        MouseArea {
            anchors.fill: parent
            onClicked: LauncherState.close()
        }
    }

    // THE PICKER HANDSHAKE IS THE HOST'S AND HAS TO BE ANSWERED. LauncherState
    // hands the surface a picker name in `pendingPicker` and expects whoever
    // drew it to TAKE it -- genesis reads it into a local and blanks it in the
    // same turn. A theme that never clears it leaves the next plain open
    // showing the last picker instead. This theme has no pickers, so it clears
    // the request rather than pretending to honour it.
    Connections {
        target: LauncherState

        function onIsOpenChanged(): void {
            if (LauncherState.isOpen)
                LauncherState.pendingPicker = "";
        }
    }

    // THE LINE tests/shell-load.sh WATCHES FOR, and the only reason this
    // fixture prints anything at all. A theme swap rebuilds the surfaces
    // inside a running engine: nothing is written, nothing exits, and
    // "Configuration Loaded" is not printed a second time -- so from outside
    // the process there is no evidence it happened. Seven of these are.
    Component.onCompleted: console.log("theme-probe drew launcher/Launcher.qml")
}
