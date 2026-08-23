// A SETTINGS CARD THAT DOES SOMETHING WHEN YOU ASK IT TO.
//
// TWO SHAPES, AND THE PHOTOGRAPH IS WHAT SPLITS THEM. Windows draws this row
// two ways and the difference is whether there is a word for the action:
//
//   with one    a Button at the right end -- 32 tall, radius 4, padding 11
//               each side, over ControlFillColorDefault with the elevation
//               border on it. "Reset" in ref/settings-system-sound-volume
//               mixer.jpg and the two "Copy" buttons in
//               ref/settings-system-about.jpg are this.
//   without     no button at all: the whole card is the target and a glyph
//               sits where the button would be -- the open-in-new on "HDR
//               Display Calibration" in ref/settings-system-display-hdr.jpg,
//               and the chevron on "System components" in
//               ref/settings-flyout-menu.jpg.
//
// THE LIT BORDER, AND WHAT PRESSING IT DOES TO IT. A Windows button is not a
// flat rectangle with a stroke: ControlElevationBorderBrush is a gradient over
// three pixels, and in the dark dictionary it is flipped, so the BOTTOM edge
// is the bright one -- #18FFFFFF under, #12FFFFFF over. It is drawn here as a
// rectangle carrying that gradient with the fill inset one pixel inside it,
// because a Rectangle's border cannot hold a gradient. Pressing drops it to
// the flat stroke, which is the state's whole visual difference besides the
// dimmer fill.
//
// THE CARD IS CLICKABLE EITHER WAY and both paths call the same signal, so a
// pointer that lands beside the button still does what the row is for.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property ActionRow row

    readonly property bool worded: root.row.actionText !== ""

    implicitHeight: Math.max(Fluent.cardMinHeight, body.implicitHeight + 2 * Fluent.cardPadding)
        + 2 * Fluent.cardGapInset

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.topMargin: Fluent.cardGapInset
        anchors.bottomMargin: Fluent.cardGapInset

        radius: Fluent.controlRadius
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, Fluent.cardStrokeAlpha)
        opacity: root.row.enabled ? 1 : Fluent.disabledOpacity

        color: {
            if (pointer.pressed)
                return Fluent.fillPress;
            if (pointer.containsMouse)
                return Fluent.fillHover;
            return Fluent.fillRest;
        }

        Behavior on color {
            ColorAnimation { duration: Fluent.fasterMs }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            enabled: root.row.actionEnabled
            onClicked: root.row.triggered()
        }

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
            anchors.right: root.worded ? button.left : mark.left
            anchors.rightMargin: Fluent.cardActionGutter
            anchors.verticalCenter: parent.verticalCenter

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

        // ---------------- Without a word: the glyph on its own ----------------
        Text {
            id: mark

            anchors.right: parent.right
            anchors.rightMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            visible: !root.worded
            text: root.row.actionGlyph !== "" ? root.row.actionGlyph : Icons.chevronRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSmallSize
            color: Theme.textOnSurfaceVariant
        }

        // ---------------- With a word: the button ----------------
        Rectangle {
            id: button

            anchors.right: parent.right
            anchors.rightMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            visible: root.worded
            width: face.implicitWidth + 2 * Fluent.controlPaddingH + 2
            height: Fluent.controlHeight
            radius: Fluent.controlRadius
            opacity: root.row.actionEnabled ? 1 : Fluent.disabledOpacity

            // THE BORDER, WHICH IS THIS RECTANGLE. The fill is the child below
            // it, inset by one; what shows around it is the gradient, or the
            // flat stroke once the button is held.
            //
            // Two stops rather than the XAML's three: the real brush is
            // absolute over three pixels with its bright stop at 0.33 of them,
            // which on a 32-pixel button is a hairline nobody can see. What
            // survives the translation is the direction -- dim at the top,
            // bright at the bottom -- and the press, where both stops go to
            // the dim value and the gradient becomes the flat stroke.
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, Fluent.elevationRest)
                }
                GradientStop {
                    position: 1
                    color: press.pressed
                        ? Qt.rgba(1, 1, 1, Fluent.elevationRest)
                        : Qt.rgba(1, 1, 1, Fluent.elevationTop)
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1

                radius: Fluent.controlRadius - 1
                color: {
                    if (press.pressed)
                        return Fluent.fillPress;
                    if (press.containsMouse)
                        return Theme.surfaceContainerHigh;
                    return Theme.surfaceContainerHighest;
                }

                Row {
                    id: face

                    anchors.centerIn: parent

                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        visible: root.row.actionGlyph !== ""
                        text: root.row.actionGlyph
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.glyphSmallSize
                        color: Theme.textOnSurface
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        text: root.row.actionText
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodySize
                        color: Theme.textOnSurface
                    }
                }
            }

            MouseArea {
                id: press

                anchors.fill: parent
                hoverEnabled: true

                enabled: root.row.actionEnabled
                onClicked: root.row.triggered()
            }
        }
    }
}
