// ONE APPLICATION ON THE TASKBAR.
//
// THE INDICATOR IS THE WHOLE POINT OF THIS FILE, and it was got wrong once by
// reasoning about it instead of looking. It has exactly two shapes:
//
//   running, not focused   a small DIM DOT, about four pixels wide
//   focused                a WIDE ACCENT BAR, about sixteen, and the button
//                          also takes a lighter rounded backplate
//
// There is no third shape. Three Explorer windows look exactly like one -- the
// host groups by application because "combine taskbar buttons" ships set to
// Always, and the indicator says nothing about how many. Both facts were read
// off a close-up photograph of a real taskbar, not off a design document, and
// the first attempt at this file drew a six-pixel grey PILL for the running
// state because a third-party theme's source said so. Every published width
// for this indicator comes from a mod that redesigns it.
//
// The numbers here are OURS in the sense that Microsoft publishes none of
// them: the taskbar is shell chrome and has no public design documentation at
// all. They are measured off the photograph.

import QtQuick
import qs
import qs.themes.windows

Item {
    id: root

    // The grouped entry the host publishes: appId, title, activated,
    // minimized, screens, toplevels.
    required property var app

    readonly property bool focused: root.app?.activated === true
    readonly property bool hovered: pointer.containsMouse
    readonly property bool held: pointer.pressed

    implicitWidth: Fluent.taskButton
    implicitHeight: Fluent.taskButton

    // THE BACKPLATE, AND IT IS NOT ONLY A HOVER STATE. A focused application
    // keeps it whether the pointer is there or not -- that is half of how the
    // taskbar says which window you are in, the accent bar being the other
    // half. Hover brightens it, press dims it, and none of it animates:
    // Windows swaps the brush on a discrete keyframe at time zero.
    Rectangle {
        anchors.fill: parent
        radius: Fluent.controlRadius + 1
        color: {
            if (root.held)
                return Theme.surface;
            if (root.hovered)
                return Theme.surfaceContainerHigh;
            if (root.focused)
                return Theme.surfaceContainer;
            return "transparent";
        }
    }

    // The application's own icon, at the size Windows draws them. A real
    // bitmap and not a glyph: a taskbar of monochrome symbols is the single
    // clearest way to look like something other than Windows.
    Image {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Fluent.indicatorBottomGap
        width: Fluent.taskIcon
        height: Fluent.taskIcon
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        source: Icons.resolve(root.app?.appId ?? "")
        visible: status === Image.Ready
    }

    // The fallback when a desktop file has no icon, which is common enough for
    // a terminal application that it cannot be left as an empty square.
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Fluent.indicatorBottomGap
        visible: !Icons.resolve(root.app?.appId ?? "")
        text: (root.app?.appId ?? "?").charAt(0).toUpperCase()
        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.strongWeight
        color: Theme.textOnSurface
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Fluent.indicatorBottomGap

        width: root.focused ? Fluent.indicatorFocusedWidth : Fluent.indicatorRunningWidth
        height: Fluent.indicatorThickness
        radius: height / 2
        color: root.focused ? Theme.primary : Theme.outline

        // THE ONE THING ON THIS BUTTON THAT MOVES. Windows animates the
        // indicator between its two widths and animates nothing else here --
        // no fade on the backplate, no scale on press. Keeping the exception
        // narrow is what makes it read as Windows rather than as a theme that
        // animates.
        Behavior on width {
            NumberAnimation {
                duration: Fluent.fastMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Fluent.easeOut
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        // NO cursorShape. Windows' taskbar keeps the arrow over its buttons;
        // a pointing hand there is a web habit and it is one of those small
        // wrong details that adds up.

        onClicked: mouse => {
            const tls = root.app?.toplevels ?? [];
            if (tls.length === 0)
                return;

            if (mouse.button === Qt.MiddleButton) {
                // Middle-click closes, which Windows does too.
                tls[0].close();
                return;
            }

            // Clicking the focused application minimises it, and clicking any
            // other raises it. That is Windows' behaviour and it is the reason
            // a minimised window keeps its button at all.
            if (root.focused)
                tls[0].minimized = true;
            else
                tls[0].activate();
        }
    }
}
