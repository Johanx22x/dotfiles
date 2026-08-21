// One fact: what it is on the left, what it says on the right.
//
// It is not a row in the ToggleRow sense and deliberately not built like one:
// nothing here is clickable, there is no hover, and the whole point is that it
// reads as a fact rather than as a control somebody forgot to wire up. The
// monitor cards stack nine of these above the line that separates what IS from
// what WOULD BE.

import QtQuick
import "root:/"

Item {
    id: root

    property string label: ""
    property string value: ""
    // Defaults to the ordinary text colour; the focused row uses the
    // accent so the one monitor that has the keyboard can be found without
    // reading all six lines.
    property color tone: Theme.textOnSurface

    width: parent ? parent.width : 320
    implicitHeight: 24

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        text: root.label
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        color: Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        // Half the row at most, so a long description elides instead of
        // sliding under its own label.
        width: Math.min(implicitWidth, root.width * 0.62)
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle

        text: root.value
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        font.weight: Theme.fontWeight
        color: root.tone

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }
}
