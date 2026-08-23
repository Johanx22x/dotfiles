// THE START BUTTON.
//
// Four rounded squares in the accent colour, which is the Windows 11 logo's
// shape. It is drawn rather than fetched: the icon font has no Windows logo in
// it -- Segoe Fluent Icons is a UI symbol set, not a brand sheet -- and a
// bitmap would be a trademark shipped in a dotfiles repository.
//
// IT SITS WITH THE TASK BUTTONS AND NOT IN THE CORNER, which is the one place
// this theme and genesis disagree about the same object for a reason neither
// is wrong about. Genesis argues the corner is the one target a pointer cannot
// overshoot and that a launcher deserves it. True, and Windows 11 gives the
// corner up anyway: Start is the first thing in the centred group, and the
// group is what moves when applications open and close.

import QtQuick
import qs
import qs.modules.launcher
import qs.themes.windows

Item {
    id: root

    readonly property bool hovered: pointer.containsMouse
    readonly property bool held: pointer.pressed

    implicitWidth: Fluent.taskButton
    implicitHeight: Fluent.taskButton

    Rectangle {
        anchors.fill: parent
        radius: Fluent.controlRadius + 1
        color: {
            if (root.held)
                return Theme.surface;
            if (root.hovered)
                return Theme.surfaceContainerHigh;
            if (LauncherState.isOpen)
                return Theme.surfaceContainer;
            return "transparent";
        }
    }

    // The mark. Four panes, a one-pixel gutter between them, and the whole
    // thing slightly narrower than it is tall -- which is what the real logo
    // does and what stops it reading as a plain grid icon.
    Item {
        id: mark

        anchors.centerIn: parent
        width: Fluent.startMark
        height: Fluent.startMark

        readonly property real pane: (width - Fluent.startGutter) / 2
        readonly property real step: mark.pane + Fluent.startGutter

        // FOUR RECTANGLES AND NOT A REPEATER OF FOUR, on purpose. Inside a
        // delegate `mark.pane` is out of scope as far as qmllint is concerned
        // -- it resolves at runtime and is checked by nothing -- and a
        // Repeater buys nothing at four. Written out, every read here is
        // checked.
        Rectangle {
            x: 0
            y: 0
            width: mark.pane; height: mark.pane; radius: 1; color: Theme.primary
        }
        Rectangle {
            x: mark.step
            y: 0
            width: mark.pane; height: mark.pane; radius: 1; color: Theme.primary
        }
        Rectangle {
            x: 0
            y: mark.step
            width: mark.pane; height: mark.pane; radius: 1; color: Theme.primary
        }
        Rectangle {
            x: mark.step
            y: mark.step
            width: mark.pane; height: mark.pane; radius: 1; color: Theme.primary
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true

        onClicked: LauncherState.toggle()
    }
}
