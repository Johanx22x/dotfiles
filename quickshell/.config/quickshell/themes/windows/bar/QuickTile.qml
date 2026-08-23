// ONE QUICK SETTINGS TILE.
//
// A WIDE RECTANGLE WITH ITS LABEL OUTSIDE IT, which is the shape a table of
// numbers will never tell you and a photograph tells you immediately. Not a
// square with the word inside: the tile is about 140 by 48 with the glyph
// centred, and the caption sits underneath, centred, in Caption size.
//
// SPLIT TILES ARE A REAL VARIANT, not two buttons side by side. Wi-Fi and
// Bluetooth are one tile divided by a hairline: the left part toggles, and the
// right-hand segment with a chevron opens a picker. That is why the caption
// under those two reads as the network's name rather than the word "Wi-Fi".
//
// ON IS ACCENT WITH A BLACK GLYPH. Dark mode's accent is the LIGHT shade of
// the ramp, so the ink on it is TextOnAccentFillColorPrimary, which is black.
// It looks wrong until you see it beside the real thing.

import QtQuick
import qs
import qs.themes.windows

Item {
    id: root

    property real cellWidth: 0
    property string tileGlyph: ""
    property string caption: ""
    property bool on: false
    property bool split: false

    signal toggled
    signal picked

    width: root.cellWidth
    height: Fluent.quickTileHeight + Fluent.quickTileLabelGap + captionText.implicitHeight

    Rectangle {
        id: tile

        width: parent.width
        height: Fluent.quickTileHeight
        radius: Fluent.controlRadius

        color: {
            if (root.on) {
                if (mainPointer.pressed)
                    return Qt.alpha(Theme.primary, 0.8);
                if (mainPointer.containsMouse)
                    return Qt.alpha(Theme.primary, 0.9);
                return Theme.primary;
            }
            if (mainPointer.pressed)
                return Theme.surface;
            if (mainPointer.containsMouse)
                return Theme.surfaceContainerHigh;
            return Theme.surfaceContainerHighest;
        }

        border.width: root.on ? 0 : 1
        border.color: Theme.outlineVariant

        // The toggle half. On a split tile it stops at the divider; on a plain
        // one it is the whole tile.
        MouseArea {
            id: mainPointer

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: root.split ? divider.left : parent.right

            hoverEnabled: true
            onClicked: root.toggled()
        }

        Text {
            anchors.centerIn: mainPointer
            text: root.tileGlyph
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            // Black on the accent fill, white otherwise.
            color: root.on ? Theme.textOnPrimary : Theme.textOnSurface
        }

        Rectangle {
            id: divider

            anchors.right: chevronArea.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 1
            anchors.bottomMargin: 1

            visible: root.split
            width: 1
            color: root.on ? Qt.alpha(Theme.textOnPrimary, 0.25) : Theme.outlineVariant
        }

        MouseArea {
            id: chevronArea

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            visible: root.split
            width: root.split ? Fluent.quickTileChevron : 0
            hoverEnabled: true
            onClicked: root.picked()

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Fluent.controlRadius
                visible: chevronArea.containsMouse
                color: root.on
                    ? Qt.alpha(Theme.textOnPrimary, 0.12)
                    : Theme.surfaceContainerHigh
            }

            Text {
                anchors.centerIn: parent
                text: Icons.chevronRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: root.on ? Theme.textOnPrimary : Theme.textOnSurface
            }
        }
    }

    Text {
        id: captionText

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tile.bottom
        anchors.topMargin: Fluent.quickTileLabelGap

        text: root.caption
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.family: Theme.fontFamily
        font.pointSize: Fluent.captionSize
        color: Theme.textOnSurface
    }
}
