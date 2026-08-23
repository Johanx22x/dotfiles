// How the windows theme draws a reading: a SettingsCard with nothing in its
// content slot. The public half -- what the pages write, and why this looks
// like a row and is not one -- is components/InfoRow.qml.
//
// THIS FILE HAS ONE RULE AND IT IS AN ABSENCE: no MouseArea, no HoverHandler,
// no TapHandler, no cursorShape, and no colour that changes because a pointer
// is over it. The facade cannot enforce that -- there is no signal to leave
// unconnected and no property to leave unread -- so it is enforced by being
// written here, and in themes/genesis/components/README.md, and nowhere else.
// See components/ActionRow.qml for what a reading WITH something to press
// looks like; it is a different type on purpose.
//
// AND WINDOWS AGREES, WHICH IS THE HAPPY PART OF THIS FILE. The absence is not
// a house rule that Fluent has to be bent around: in SettingsCard.cs the
// PointerEntered/PointerExited handlers are subscribed by
// EnableButtonInteraction(), which runs only when IsClickEnabled is true, and
// OnPointerPressed is gated on the same flag. A settings card with nothing to
// click does not light up in Windows either. So this card has one fill --
// CardBackgroundFillColorDefault -- and no states at all, which is both the
// interface's rule and Microsoft's.
//
// The second line is optional and muted, and the row grows to fit it rather
// than eliding -- an explanation cut off at the width of a sidebar is an
// explanation nobody finishes reading. That growth is what implicitHeight
// below reports back to the facade.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `InfoRow` here is the facade and not
    // this file.
    required property InfoRow row

    // WHAT THE FACADE READS BACK. This is the component the facade reads a
    // height for at all: `header` is as tall as the description wraps to and
    // nothing on the host side can know that. SettingsCardMinHeight is 68 and
    // the padding is 16 top and bottom, so a one-line reading is 68 and a
    // wrapped one is however tall its words came out plus 32.
    implicitHeight: Math.max(Fluent.cardMinHeight, header.implicitHeight + Fluent.cardPadding * 2)

    radius: Fluent.controlRadius
    color: Fluent.fillRest

    border.width: 1
    border.color: Theme.outlineVariant

    // NO Behavior ON THAT COLOUR EITHER, and for once that is not the hover
    // rule: this fill has nothing to cross to. SettingsCard's 83ms
    // BrushTransition exists for a card that changes state, and a card that
    // cannot be hovered or pressed never does.

    // The dim is drawing and it lives here; `enabled` itself arrives down the
    // item tree with nothing forwarded by hand. There is no MouseArea to
    // forward it to -- see the header.
    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // SettingsCardHeaderIconMargin is "2,0,20,0" -- a 20-wide icon column and a
    // 20 gap to the words. See ToggleRow.qml in this directory on why the 20 is
    // honoured as a box and the 2 is not carried.
    Item {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        visible: root.row.glyph !== ""
        width: root.row.glyph !== "" ? Fluent.cardIconMax : 0
        height: Fluent.cardIconMax

        Text {
            anchors.centerIn: parent

            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            // TextFillColorPrimary: SettingsCard's own Foreground, which the
            // header icon inherits. Genesis mutes this glyph; Windows does not.
            color: Theme.textOnSurface
        }
    }

    // THE TWO LINES STACK WITH NO GAP AT ALL, which is the detail a
    // reimplementation invents a number for. SettingsCard's HeaderPanel is a
    // StackPanel with no Spacing set: the header sits directly on the
    // description and the only air between them is the two line boxes.
    Column {
        id: header

        anchors.left: mark.right
        anchors.leftMargin: root.row.glyph !== "" ? Fluent.cardIconGap : 0
        anchors.right: parent.right
        // HeaderPanel's Margin is "0,0,24,0" and the card's own padding is 16.
        // With no content presenter to leave room for, the reading still keeps
        // the gutter: it is the column's right margin, not the control's left.
        anchors.rightMargin: Fluent.cardPadding + Fluent.cardActionGutter
        anchors.verticalCenter: parent.verticalCenter

        spacing: 0

        Text {
            width: parent.width
            visible: root.row.label !== ""
            text: root.row.label
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            // Normal, not Theme.fontWeight: SettingsCard sets FontWeight Normal
            // outright and Windows keeps Semibold for emphasis.
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }

        // SettingsCardDescriptionFontSize is 12 and the brush is
        // TextFillColorSecondary, both set on PART_DescriptionPresenter
        // directly rather than inherited.
        Text {
            width: parent.width
            visible: root.row.description !== ""
            text: root.row.description
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurfaceVariant
        }
    }
}
