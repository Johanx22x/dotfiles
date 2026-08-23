// ONE ROW OF A LIST OF THINGS: a device, a package, a network, a unit.
//
// A CARD, AND THE PHOTOGRAPH IS WHAT DECIDED THAT. It was drawn first as a
// bare ListViewItem backplate -- nothing at rest, a fill under the pointer --
// and photographed on a page whose section is a list. The rows floated: a
// column of naked text on the pane with no edge anywhere near it, which is
// something the Settings app never shows. EVERY list of things in Windows 11's
// Settings is housed, and housed the same way: installed apps, paired devices,
// sound outputs and Wi-Fi networks are each a card of their own, stacked four
// apart. So a list row here is a card too -- a short one, floored at
// ListViewItemMinHeight rather than at the 68 a setting gets.
//
// EXCEPT A COMPACT ONE, which stays the bare backplate. `compact` is the
// facade saying "half height, smaller type, a pill rather than a rounded
// rectangle" for a pack that can hold ninety rows, and ninety cards is a page
// nobody reaches the end of.
//
// Selection is the 3 by 16 accent bar at the left edge, exactly as in the
// navigation rail: the fill says "the pointer is here or this one is chosen"
// and the bar says which.
//
// `interactive: false` IS A PROMISE ONLY THIS HALF CAN KEEP. The hit target
// below goes `visible: false` when the row is not interactive, which takes it
// out of the scene's input entirely -- no hover, no backplate, and `chosen`
// never emitted. `enabled: false` on its own would not be enough: a disabled
// MouseArea still swallows the press. A facade has no way to require an
// absence, so it is written down here, next to the half that keeps it.
//
// THE GUTTER AT THE RIGHT END IS RESERVED OFF `marked` AND NOT OFF THE DRAWN
// WORD. The word comes and goes with the pointer, so a gutter measured from it
// would breathe under the pointer and take the label's eliding with it.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property ListRow row

    readonly property bool lit: root.row.interactive && pointer.containsMouse
    readonly property string markText: root.row.selected
        ? root.row.mark
        : (root.lit ? root.row.hoverMark : "")

    // A card, unless the list said it wanted the dense shape. See the header.
    readonly property bool housed: !root.row.compact
    readonly property int sidePadding: root.housed ? Fluent.cardPadding : Fluent.controlPaddingH

    implicitHeight: root.housed
        ? Math.max(Fluent.listRowHeight, body.implicitHeight + 2 * Fluent.controlPaddingH)
            + 2 * Fluent.cardGapInset
        : Math.max(26, body.implicitHeight + 8)

    Rectangle {
        id: plate

        anchors.fill: parent
        anchors.topMargin: root.housed ? Fluent.cardGapInset : 0
        anchors.bottomMargin: root.housed ? Fluent.cardGapInset : 0

        radius: Fluent.controlRadius
        opacity: root.row.enabled ? 1 : Fluent.disabledOpacity
        border.width: root.housed ? 1 : 0
        border.color: Qt.rgba(0, 0, 0, Fluent.cardStrokeAlpha)

        // One brush for hover and for selection, which is the rule the rail
        // keeps too. A housed row sits on the card's own fill when neither is
        // true; a compact one sits on nothing.
        color: {
            if (root.row.selected || root.lit)
                return root.housed ? Fluent.fillHover : Fluent.fillSubtleHover;
            return root.housed ? Fluent.fillRest : "transparent";
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.indicatorWidth
            height: Math.min(Fluent.indicatorHeight, parent.height - 8)
            radius: Fluent.indicatorRadius

            visible: root.row.selected
            color: Theme.primary
        }

        // ---------------- The mark on the left: a glyph, or a badge ----------
        Text {
            id: lead

            anchors.left: parent.left
            anchors.leftMargin: root.sidePadding
            anchors.verticalCenter: parent.verticalCenter

            // A GLYPH GETS A COLUMN AND A BADGE GETS ITS OWN WIDTH. The first
            // pass gave both the icon's 16 and the badge -- a WORD, "drift" or
            // "missing" -- ran straight under the label beside it. Photographed
            // before it was believed.
            //
            // The column a housed row uses is the CARD's, 20 wide with 20 to
            // the text, so that a list row and a settings card stacked in the
            // same section line their text up. A compact row keeps the tighter
            // one it has room for.
            width: {
                if (root.row.glyph !== "")
                    return root.housed ? Fluent.cardIconMax : Fluent.navIcon;
                if (root.row.badge !== "")
                    return lead.implicitWidth;
                return 0;
            }
            horizontalAlignment: root.housed ? Text.AlignHCenter : Text.AlignLeft

            visible: root.row.glyph !== "" || root.row.badge !== ""
            text: root.row.glyph !== "" ? root.row.glyph : root.row.badge
            font.family: Theme.fontFamily
            font.pointSize: {
                if (root.row.glyph === "")
                    return Fluent.captionSize;
                return root.housed ? Fluent.glyphSize : Fluent.glyphSmallSize;
            }
            color: root.row.glyph !== "" ? Theme.textOnSurface : root.row.badgeTone
        }

        Column {
            id: body

            anchors.left: lead.right
            anchors.leftMargin: lead.visible ? (root.housed ? Fluent.cardIconGap : 8) : 0
            anchors.right: mark.left
            anchors.rightMargin: root.row.marked ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter

            spacing: 0

            Text {
                width: parent.width

                text: root.row.rowLabel
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: root.row.compact ? Fluent.captionSize : Fluent.bodySize
                color: Theme.textOnSurface
            }

            // The second line is an explanation and it WRAPS: one cut off at
            // the width of a sidebar is one nobody finishes.
            Text {
                width: parent.width

                visible: root.row.detail !== ""
                text: root.row.detail
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }
        }

        // ---------------- The word at the right end ----------------
        Row {
            id: mark

            anchors.right: parent.right
            anchors.rightMargin: root.sidePadding
            anchors.verticalCenter: parent.verticalCenter

            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter

                visible: root.row.markGlyph !== "" && root.markText !== ""
                text: root.row.markGlyph
                font.family: Theme.fontFamily
                font.pointSize: Fluent.glyphSmallSize
                color: root.row.selected ? Theme.primary : Theme.textOnSurfaceVariant
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                visible: root.markText !== ""
                text: root.markText
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: root.row.selected ? Theme.primary : Theme.textOnSurfaceVariant
            }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: root.row.interactive

            // NOT `enabled: false` ALONE: a disabled MouseArea still takes the
            // press. A row that is not interactive has none of this at all --
            // `visible: false` on a MouseArea is what removes it from the
            // scene's input entirely.
            visible: root.row.interactive
            enabled: root.row.interactive

            onClicked: root.row.chosen()
        }
    }
}
