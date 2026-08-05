// A search box: a glyph, a text input, and a clear button once there is
// something to clear.
//
// TextInput and not TextField: TextField is QtQuick.Controls, which nothing
// in this shell imports, and it would arrive with its own background, its own
// padding and its own idea of the palette. The pill below is drawn the same
// way every other pill here is.
//
// The launcher has its own input rather than this one, and that is not an
// oversight: the launcher's field is the whole interface, sized and animated
// with the sheet it lives in. This is a control that sits in a corner of a
// window. Merging them would mean one component with two layouts.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: "Search"

    // Focus lands here without a click, for the window that opens ready to be
    // typed into. Off by default: a field that steals focus is wrong far more
    // often than it is right.
    property alias focused: input.activeFocus

    signal accepted
    signal escaped

    implicitHeight: Theme.groupHeight - 4
    radius: height / 2

    color: input.activeFocus ? Theme.surfaceContainerHigh
        : mouse.containsMouse ? Qt.alpha(Theme.surfaceContainerHigh, 0.6)
        : Qt.alpha(Theme.surfaceContainerHigh, 0.35)

    border.width: 1
    border.color: input.activeFocus ? Theme.primary : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.animDuration }
    }

    function clear(): void {
        input.text = "";
    }

    function take(): void {
        input.forceActiveFocus();
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }

    Text {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        text: Icons.search
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: input.activeFocus ? Theme.primary : Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    TextInput {
        id: input

        anchors.left: glyph.right
        anchors.leftMargin: Theme.itemSpacing
        anchors.right: clearButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.textOnSurface
        selectionColor: Theme.primaryContainer
        selectedTextColor: Theme.textOnPrimaryContainer
        clip: true

        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escaped()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: root.placeholder
            font: input.font
            color: Theme.outline
        }
    }

    // Only there when it has something to do. A permanent clear button on an
    // empty field is a control that is disabled nine tenths of the time.
    Item {
        id: clearButton

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: root.height - 8
        implicitHeight: root.height - 8
        visible: input.text !== ""

        Text {
            anchors.centerIn: parent
            text: Icons.close
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize - 2
            color: clearMouse.containsMouse ? Theme.textOnSurface : Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        MouseArea {
            id: clearMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.clear();
                input.forceActiveFocus();
            }
        }
    }
}
