// A SETTINGS CARD THAT SAYS SOMETHING AND TAKES NO INPUT.
//
// AND THEREFORE IT HAS NO MouseArea AT ALL, which is rule 7 in
// themes/genesis/components/README.md said from the theme's side -- and it is
// also what the control does. In CommunityToolkit's SettingsCard.cs the
// pointer handlers are subscribed only when IsClickEnabled is true, so a card
// with nothing to click does not merely ignore the click: it never lights up
// under the pointer either. A reading that highlights is a reading pretending
// to be a button, and it is the first thing that makes a recreation feel
// wrong to somebody who uses the real one.
//
// Everything else is the shared card: 68 tall at rest, 16 of padding, radius
// 4, a one-pixel black stroke, a 20 glyph with 20 to the text, and the header
// over a Caption description in the muted role. The description WRAPS rather
// than eliding, which is what the cards in ref/settings-system-display-hdr.jpg
// do -- two of them run to three lines and the card grows.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property InfoRow row

    implicitHeight: Math.max(Fluent.cardMinHeight, body.implicitHeight + 2 * Fluent.cardPadding)
        + 2 * Fluent.cardGapInset

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Fluent.cardGapInset
        anchors.bottomMargin: Fluent.cardGapInset

        radius: Fluent.controlRadius
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, Fluent.cardStrokeAlpha)

        // ONE FILL AND NO STATES. See the header.
        color: Fluent.fillRest
        opacity: root.row.enabled ? 1 : Fluent.disabledOpacity

        Text {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.cardIconMax
            horizontalAlignment: Text.AlignHCenter

            visible: root.row.glyph !== ""
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSize
            color: Theme.textOnSurface
        }

        Column {
            id: body

            anchors.left: parent.left
            anchors.leftMargin: Fluent.cardPadding + (root.row.glyph !== "" ? Fluent.cardIconMax + Fluent.cardIconGap : 0)
            anchors.right: parent.right
            anchors.rightMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            // Zero, and not a gap: Windows stacks the header straight onto its
            // description and lets the two line heights do the spacing.
            spacing: 0

            Text {
                width: parent.width

                text: root.row.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.textOnSurface
            }

            Text {
                width: parent.width

                visible: root.row.description !== ""
                text: root.row.description
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }
        }
    }
}
