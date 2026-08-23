// A TITLED GROUP OF SETTINGS ROWS -- AND UNDER THIS THEME, NO CARD.
//
// THAT IS THE WHOLE OF WHAT THE PHOTOGRAPH CHANGED HERE. Genesis draws a
// heading and then one card holding every row in the section. Windows draws a
// heading and then a STACK OF CARDS, one per row, four pixels apart and each
// one fully rounded -- ref/settings-touchpad-mica.png has six of them under
// "Gestures & interaction" and they do not join. So the card moved down a
// level: every row in this theme draws its own, and what is left up here is
// the heading, the optional action beside it, and the slot the rows go in.
//
// The heading is Body Strong -- 14 semibold -- with 30 above it and 6 under,
// which is the margin the toolkit's own sample page puts on it. It aligns with
// the LEFT EDGE OF THE CARDS and not with their padding: measured in the
// touchpad shot, the heading's ink starts two pixels left of the card edge,
// which is a text bearing rather than an indent.
//
// THE SLOT IS THE ONE LINE THIS FILE CANNOT LEAVE OUT. `row.rows` is the
// Column the pages' rows are parented into; it lives on the facade because a
// default-property alias cannot be resolved through a Loader. Placing it is
// `data: [root.row.rows]` and nothing else -- the Column's own anchors are
// bound to `parent`, so they re-evaluate against this slot when it becomes
// one. Leave the line out and every row lands at full width with no card,
// silently: the facade's height floor reads the same either way and nothing in
// tests/ can see it.

import QtQuick
import qs
import qs.components
import qs.modules.settings
import qs.themes.windows

Item {
    id: root

    required property SettingsSection row

    // A section with nothing to say for itself draws no heading and takes no
    // space for one -- the display page builds a few of those.
    readonly property bool titled: root.row.title !== ""
    readonly property bool acting: root.row.actionText !== "" || root.row.actionGlyph !== ""

    readonly property int headingHeight: root.titled
        ? Fluent.sectionHeaderTop + Math.max(Fluent.bodyLine, Fluent.chipHeight) + Fluent.sectionHeaderBottom
        : 0

    implicitHeight: root.headingHeight + (root.row.rows ? root.row.rows.implicitHeight : 0)

    Item {
        id: heading

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Fluent.sectionHeaderTop

        height: root.titled ? Math.max(Fluent.bodyLine, Fluent.chipHeight) : 0
        visible: root.titled

        Text {
            anchors.left: parent.left
            anchors.right: action.left
            anchors.rightMargin: Fluent.cardIconGap
            anchors.verticalCenter: parent.verticalCenter

            text: root.row.title
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.strongWeight
            color: Theme.textOnSurface
        }

        // The section's own action, up here rather than as a row of its own:
        // a section-wide action put inside the stack becomes a card that looks
        // like a setting and is not one.
        Chip {
            id: action

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: root.acting
            label: root.row.actionText
            glyph: root.row.actionGlyph

            onActivated: root.row.actionTriggered()
        }
    }

    // ---------------- The slot ----------------
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.headingHeight
        anchors.bottom: parent.bottom

        data: [root.row.rows]
    }
}
