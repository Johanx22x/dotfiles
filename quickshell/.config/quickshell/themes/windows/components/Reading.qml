// ONE FACT ABOUT A MONITOR: THE NAME AT THE LEFT, WHAT IT SAYS AT THE RIGHT.
//
// Read off settings-system-about.jpg, which is the one screen in Windows that
// is made of these: the expanded "Windows info" card holds Edition, Version,
// Installed on, OS build and Experience as a definition list. What the
// photograph settles, and the documentation does not mention at all:
//
//   THE NAME IS GREY AND THE VALUE IS WHITE. Not the other way round, and not
//   both the same. The eye runs down the grey column to find the row and then
//   right to read the answer, which is the whole reason the list is two
//   columns and not a sentence.
//   NEITHER COLUMN IS EMPHASISED BY WEIGHT. There is no bold anywhere in it.
//   THE ROWS HAVE NO SEPARATORS, no fill and no card of their own -- the card
//   is the thing they are inside.
//
// WHERE THIS DEPARTS FROM THE PHOTOGRAPH, AND IT IS ONE PLACE. Windows puts
// the value in a SECOND COLUMN at a fixed x, so five values start at the same
// place. That x is the widest name in the list plus a gap, which is a
// measurement across all the rows at once -- and a row here cannot see its
// siblings: it is handed a width and nothing else. The value is right-flushed
// instead, which needs no measurement anybody has, and which is the shape the
// facade's own header describes. It is also the alignment the controls on the
// rows below use, so the card still reads as two columns.
//
// ---------------------------------------------------------------------------
// RULE 7: THE CONTRACT HERE IS AN ABSENCE
// ---------------------------------------------------------------------------
//
// No MouseArea, no HoverHandler, no TapHandler, no cursorShape, and no colour
// that moves because a pointer is over it. This is InfoRow's promise one
// directory up and modules/settings/pages/display/Reading.qml carries it in
// its own header: a facade cannot require an absence -- there is no signal to
// leave unconnected and no property to leave unread -- so it is kept here or
// it is not kept at all. A reading with something to press is a different
// component, and components/ActionRow.qml is that component.
//
// `row.tone` IS A MEANING AND NOT A TOKEN. The card sets it to Theme.primary
// on the one monitor that has the keyboard and to Theme.textOnSurfaceVariant
// on the rows that are saying "no" -- ordinary or singled out, which only the
// card knows. It colours the VALUE, because the value is the half that carries
// the fact; the name stays grey whatever the row means. Rule 5 is intact: this
// is not a design token crossing the seam, and the theme reads every other
// colour on this row from Theme.
//
// The height is the line box plus Fluent.textLeading top and bottom, which
// lands a little over the facade's floor of 24 at the default font size and
// grows with it. Nine of these stack on a card, which is the whole reason the
// leading is the tight one -- see Fluent.textLeading.

import QtQuick
import qs
import qs.themes.windows
import qs.modules.settings.pages.display

Item {
    id: root

    required property Reading row

    implicitHeight: Math.round(Fluent.bodyLine) + 2 * Fluent.textLeading

    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // The left column starts where a card's content starts, so the names line
    // up with the labels of the rows under them. The readings are the one
    // thing on this card with no card of their own -- Windows' section header
    // sits flush with the card EDGE and the rows inside one sit at
    // cardPadding, and these read as content rather than as a heading.
    Text {
        id: name

        anchors.left: parent.left
        anchors.leftMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        // Never more than the left half: a long name may elide, but it may not
        // squeeze the answer off the row.
        width: Math.min(name.implicitWidth, Math.max(0, root.width / 2))

        text: root.row.label
        elide: Text.ElideRight

        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        color: Theme.textOnSurfaceVariant
    }

    Text {
        anchors.left: name.right
        anchors.leftMargin: Fluent.cardPadding
        anchors.right: parent.right
        anchors.rightMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.value
        horizontalAlignment: Text.AlignRight

        // IN THE MIDDLE AND NOT AT THE END, which is a fact about what is in
        // this row rather than a look: one of these carries the full EDID
        // string, whose two ends are the manufacturer and the serial and whose
        // middle is the part nobody matches on.
        elide: Text.ElideMiddle

        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        color: root.row.tone
    }
}
