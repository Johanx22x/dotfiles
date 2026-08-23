// A VALUE STEPPED THROUGH A LIST, IN THE SHAPE OF A SETTINGS CARD.
//
// Read off settings-system-display-hdr.jpg and settings-home-navpane.png. What
// a card row is in Windows, and every clause of it is in both photographs:
//
//   ONE ROW IS ONE CARD. Cards stack with a gap between them and stay fully
//   rounded; they do not join into a list. The top-rounds/middle-squares rule
//   belongs to SettingsExpander and nothing else.
//   THE GLYPH IS A COLUMN, not an inline character -- a fixed box at the left
//   with the text starting past it, so that the labels of a stack of cards
//   line up whether or not each one has an icon.
//   THE CONTROL IS AT THE RIGHT, and its VALUE READS TO THE LEFT OF IT. The
//   HDR page writes "On" and "Off" beside the switch rather than inside it,
//   which is the same arrangement this row needs for its number.
//   NOTHING ANIMATES ON HOVER. The fill is swapped at time zero.
//
// AND THE CARD IS NOT A CONTROL, which is the trap this row would fall into
// most easily. There is no hover fill on the card itself and no pointer cursor
// over it, because the row takes no clicks: what is pressable is the two
// buttons and nothing else. components/ListRow.qml's header is where that was
// decided for this component and modules/settings/pages/display/CycleRow.qml
// repeats it.
//
// `row.stepped(delta)` IS A DIRECTION AND NOT A VALUE. -1 and 1, and the card
// owns the list, wraps at both ends and reads nothing back. This file never
// computes a next mode or a next scale, and it must not: it cannot see the
// list.
//
// THE BUTTONS ARE components/StepperButton.qml AND ARE DRAWN BY THIS THEME'S
// OWN FILE FOR IT. The 400ms-then-60ms repeat behind them is the facade's and
// stays there; this row says `symbol`, `enabled` and `onTriggered` and knows
// nothing about the hold. Same four bindings the pre-split row used.

import QtQuick
import qs
import qs.themes.windows
import qs.components
import qs.modules.settings.pages.display

Rectangle {
    id: root

    required property CycleRow row

    // SettingsCard: ControlCornerRadius, not the 8 a window gets, and a
    // one-pixel stroke that is the only thing separating the card from the
    // page behind it.
    radius: Fluent.controlRadius
    color: Fluent.fillRest
    border.width: 1
    border.color: Theme.outlineVariant

    implicitHeight: Math.max(Fluent.cardMinHeight, label.implicitHeight + 2 * Fluent.cardPadding)

    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    Text {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.cardIconMax
        horizontalAlignment: Text.AlignHCenter

        text: root.row.glyph
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: Theme.textOnSurface
    }

    Text {
        id: label

        anchors.left: icon.right
        anchors.leftMargin: Fluent.cardIconGap
        anchors.right: steppers.left
        anchors.rightMargin: Fluent.cardActionGutter
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        elide: Text.ElideRight

        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        color: Theme.textOnSurface
    }

    // SettingsCardContentMinWidth is what makes a stack of cards line its
    // controls up down the right-hand edge instead of each one ending where
    // its own content happens to. The value is pinned between the two buttons
    // rather than sized to itself for the same reason one level down: "1.75"
    // and "2.00" are different widths, and a number whose buttons move when it
    // changes is a control that will not stay still under a held finger.
    Item {
        id: steppers

        anchors.right: parent.right
        anchors.rightMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.cardContentMinWidth
        height: Math.max(down.implicitHeight, up.implicitHeight)

        StepperButton {
            id: down

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            symbol: Icons.chevronLeft
            enabled: root.enabled

            onTriggered: root.row.stepped(-1)
        }

        Text {
            anchors.left: down.right
            anchors.right: up.left
            anchors.verticalCenter: parent.verticalCenter

            text: root.row.value
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurfaceVariant
        }

        StepperButton {
            id: up

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            symbol: Icons.chevronRight
            enabled: root.enabled

            onTriggered: root.row.stepped(1)
        }
    }
}
