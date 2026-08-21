// A value picked by stepping through a list, in the shape of a settings
// row. StepperRow itself does not fit: it holds an int over a numeric
// range, and these are strings out of a list the compositor supplies.
// Its buttons do fit, so those are reused rather than redrawn.
//
// Its own file rather than a promotion into components/: the only thing that
// steps through a list of strings on this desk is a monitor's mode and its
// scale, and a component in components/ is a claim that the next page will
// want it too.

import QtQuick
import "root:/"
import "root:/components"

Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property string value: ""

    signal stepped(int delta)

    width: parent ? parent.width : implicitWidth
    implicitWidth: 320
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius
    color: cycleMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    opacity: root.enabled ? 1 : 0.4

    // Hover on the whole row, like StepperRow: the row is one object and
    // lights up as one. It takes no clicks -- there is no obvious single
    // action for "clicked the label", and inventing one (step forward?)
    // would be a control nobody asked for.
    MouseArea {
        id: cycleMouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding - 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StepperButton {
            anchors.verticalCenter: parent.verticalCenter
            symbol: Glyphs.chevronLeft
            enabled: root.enabled
            onTriggered: root.stepped(-1)
        }

        // FIXED WIDTH, for the reason StepperRow's number is: the buttons
        // sit either side of it, and without this they would jump every
        // time the text went from "800 × 600 · 60 Hz" to
        // "2560 × 1440 · 165 Hz".
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 168
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight

            text: root.value
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            font.weight: Font.Bold
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        StepperButton {
            anchors.verticalCenter: parent.verticalCenter
            symbol: Icons.chevronRight
            enabled: root.enabled
            onTriggered: root.stepped(1)
        }
    }
}
