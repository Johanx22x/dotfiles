// A button for the action you should not be able to take by accident.
//
// TWO STEPS IN ONE CONTROL, not a modal dialog. A dialog for a single
// irreversible click is a lot of machinery -- a surface, a focus grab, a way
// out of it -- to ask a question that fits on the button itself. The button
// arms on the first click and does the thing on the second, and it says so
// while armed.
//
// IT DISARMS ITSELF after a few seconds. An armed button left sitting there
// is a landmine: you click "Reset", get called away, come back and click what
// you now read as the same button you clicked before. The countdown makes the
// armed state a moment rather than a mode.
//
// Colour carries the state, and it is the shell's existing vocabulary for it:
// Theme.critical, the same red the power button uses on hover, and for the
// same reason -- every other button on screen promises "this opens
// something", and this one has to promise something else before it is
// pressed.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property string text: ""
    property string confirmText: ""
    property string glyph: ""

    // How long the armed state lasts. Long enough to move the pointer and
    // read the new label, short enough not to outlive the intent.
    property int armedFor: 4000

    readonly property bool armed: disarmTimer.running

    signal confirmed

    implicitWidth: label.implicitWidth + Theme.groupPadding * 2 + (glyphText.visible ? glyphText.implicitWidth + Theme.itemSpacing : 0)
    implicitHeight: Theme.groupHeight - 6
    radius: height / 2

    color: root.armed ? Qt.alpha(Theme.critical, mouse.containsMouse ? 0.28 : 0.18)
        : mouse.containsMouse ? Theme.surfaceContainerHigh
        : "transparent"

    border.width: 1
    border.color: root.armed ? Theme.critical : Theme.outlineVariant

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.itemSpacing

        Text {
            id: glyphText

            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.armed ? Theme.critical : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            text: root.armed ? root.confirmText : root.text
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            font.weight: root.armed ? Font.Bold : Theme.fontWeight
            color: root.armed ? Theme.critical : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    // The countdown, drawn as the border draining away rather than as a
    // number: what matters is that the armed state is temporary, not how many
    // milliseconds are left.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: -1
        height: 2
        radius: 1
        width: root.armed ? 0 : parent.width
        visible: root.armed
        color: Theme.critical

        Behavior on width {
            enabled: root.armed
            NumberAnimation { duration: root.armedFor; easing.type: Easing.Linear }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (root.armed) {
                disarmTimer.stop();
                root.confirmed();
            } else {
                disarmTimer.restart();
            }
        }
    }

    Timer {
        id: disarmTimer
        interval: root.armedFor
    }
}
