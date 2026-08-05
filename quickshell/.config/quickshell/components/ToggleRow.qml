// A settings row that is on or off: glyph, label, switch.
//
// THE WHOLE ROW IS THE TARGET, not just the switch. A 42x22 pill is a small
// thing to hit for a decision this cheap, and every other row in this shell
// -- MenuRow, the quick toggles on the dashboard -- already answers to a
// click anywhere on it. The switch is feedback, not the button.
//
// It knows nothing about Config: it takes a value and emits a request to
// change it. That keeps the row reusable and, more to the point, keeps the
// binding one-directional -- `checked` follows the config, and the click asks
// the config to move. A row that wrote to Config itself would be a second
// writer to a value it also displays.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property bool checked: false

    signal toggled(bool value)

    // IT TAKES ITS WIDTH FROM ITS PARENT, which therefore has to have one of
    // its own -- SettingsSection gives its column an explicit width for
    // exactly this. Binding implicitWidth to the parent instead would be a
    // loop: a Column sizes itself to its widest child, and the child would be
    // sizing itself to the Column.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius
    color: mouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    opacity: root.enabled ? 1 : 0.4

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

    // ---------------- The switch ----------------
    //
    // Hand-built rather than QtQuick.Controls' Switch: nothing else in this
    // shell imports Controls, and a Controls widget would arrive with its own
    // style, its own metrics and its own idea of the palette, none of which
    // are Theme's. Twenty lines is cheaper than reconciling that.
    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        width: 42
        height: 22
        radius: height / 2

        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest

        // The off state needs an edge: over the section's own surface an
        // unfilled track of nearly the same tone reads as empty space rather
        // than as a control that is switched off.
        border.width: root.checked ? 0 : 1
        border.color: Theme.outlineVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Rectangle {
            id: knob

            width: 16
            height: 16
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter

            x: root.checked ? track.width - width - 3 : 3
            color: root.checked ? Theme.textOnPrimary : Theme.textOnSurfaceVariant

            Behavior on x {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.toggled(!root.checked)
    }
}
