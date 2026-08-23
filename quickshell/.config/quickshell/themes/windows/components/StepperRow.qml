// A SETTINGS CARD WHOSE ANSWER IS A NUMBER YOU STEP THROUGH.
//
// THE CONTROL IS A NumberBox WITH ITS SPIN BUTTONS INLINE: a field 32 tall at
// radius 4 with the elevation border on it, never narrower than the 120
// NumberBoxMinWidth ships, holding the number between the two buttons that
// move it. There is no photograph of a NumberBox among the references and this
// file says so rather than pretending otherwise -- what IS read off a
// photograph is the frame it borrows, which is the same field the combo boxes
// in ref/settings-personalization-taskbar.jpg sit in: 32 tall, radius 4, a
// step lighter than the card, 11 of padding at each end.
//
// THE ARROWS POINT SIDEWAYS AND WINDOWS' POINT UP AND DOWN. A NumberBox stacks
// its chevrons; this row is a horizontal group with the number in the middle,
// which is the shape every stepper in this shell has had, and the icon set
// this theme ships has no chevron-up in it at all -- see Icons.qml, where the
// missing one is called out by name. Left and right is the honest answer to
// both of those rather than a vertical pair drawn with the wrong glyph.
//
// nudge() IS THE FACADE'S AND THE BUTTONS CALL NOTHING ELSE. It clamps at both
// ends and stays silent there -- no signal, no wrap -- so a theme that did its
// own arithmetic would be re-deciding what a range means.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property StepperRow row

    readonly property string readingText: root.row.display !== ""
        ? root.row.display
        : `${root.row.value}${root.row.suffix}`

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

        color: pointer.containsMouse ? Fluent.fillHover : Fluent.fillRest

        Behavior on color {
            ColorAnimation { duration: Fluent.fasterMs }
        }

        // Hover only: the row's answer comes from the two buttons.
        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
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
            anchors.right: field.left
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

                visible: root.row.hint !== ""
                text: root.row.hint
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }
        }

        // ---------------- The field ----------------
        Rectangle {
            id: field

            anchors.right: parent.right
            anchors.rightMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            width: Math.max(Fluent.numberBoxMinWidth, 2 * Fluent.controlHeight + reading.implicitWidth + 2 * Fluent.controlPaddingH) + 2
            height: Fluent.controlHeight + 2
            radius: Fluent.controlRadius

            // The elevation border, drawn as a rectangle with the fill inset
            // inside it -- see ActionRow's header for why it cannot be a
            // Rectangle border and why the bright stop is at the bottom.
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, Fluent.elevationRest)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(1, 1, 1, Fluent.elevationTop)
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1

                radius: Fluent.controlRadius - 1
                color: Theme.surfaceContainerHighest

                StepperButton {
                    id: down

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    symbol: Icons.chevronLeft
                    enabled: root.row.value > root.row.from

                    onTriggered: root.row.nudge(-root.row.step)
                }

                StepperButton {
                    id: up

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    symbol: Icons.chevronRight
                    enabled: root.row.value < root.row.to

                    onTriggered: root.row.nudge(root.row.step)
                }

                Text {
                    id: reading

                    anchors.left: down.right
                    anchors.right: up.left
                    anchors.verticalCenter: parent.verticalCenter

                    horizontalAlignment: Text.AlignHCenter
                    text: root.readingText
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    color: Theme.textOnSurface
                }
            }
        }
    }
}
