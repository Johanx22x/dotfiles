// The one button shape this page uses, for the segmented rotation control
// and for every action. Filled means "this is the one" -- the selected
// segment, or the action that carries the page's intent.
//
// UNDER pages/display/ AND NOT IN components/, for the same reason. This is the
// display page's button, shaped by what this page needed -- a segmented control
// that needs a filled state, and an action row that needs the unfilled one --
// and every other page in this window uses ActionRow, ConfirmButton or a bare
// MouseArea instead. Moving it up a level would be saying it is the shell's
// button, which is a bigger claim than the one file that uses it can support.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property string label: ""
    property string glyph: ""
    property bool filled: false
    property color accent: Theme.primary
    // Set alongside `accent` whenever it is not the primary, because M3
    // guarantees contrast per PAIR and the pairs are the whole reason the
    // palette can follow the wallpaper. warning and critical pair with
    // textOnCritical, which is the same dark ink.
    property color accentText: Theme.textOnPrimary

    signal activated

    implicitWidth: chipRow.implicitWidth + Theme.groupPadding * 2
    implicitHeight: 28
    radius: height / 2

    color: root.filled
        ? (chipMouse.containsMouse ? Qt.lighter(root.accent, 1.15) : root.accent)
        : (chipMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")

    border.width: root.filled ? 0 : 1
    border.color: Theme.outlineVariant

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.animDuration }
    }

    // Dimmed rather than hidden: an action that vanishes takes the ones
    // beside it sideways, and the row would rearrange itself every time a
    // draft became clean.
    opacity: root.enabled ? 1 : 0.35

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDuration }
    }

    Row {
        id: chipRow

        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize - 1
            color: root.filled ? root.accentText : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            font.weight: root.filled ? Font.Bold : Theme.fontWeight
            color: root.filled ? root.accentText : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    MouseArea {
        id: chipMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.activated()
    }
}
