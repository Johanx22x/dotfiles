// How the windows theme draws a settings section: a heading line, and under it
// the rows. The public half -- the forty-nine call sites, the default property,
// and the long note on why the column of rows stayed on the host side -- is
// modules/settings/SettingsSection.qml.
//
// THIS FILE PLACES AN OBJECT IT DOES NOT OWN. `slot` below has
// `data: [root.row.rows]`, and appending the facade's Column to this item's own
// data list is what moves it under the heading. The direction is the ordinary
// one -- this file writes to its own item and reads the facade -- and the
// column's anchors are bound to `parent`, so they re-evaluate against the slot
// the moment it arrives. components/SearchField.qml in this directory does the
// same thing with a TextInput.
//
// A THEME THAT LEAVES THAT LINE OUT still loads and still draws a heading, and
// the rows stay anchored to the facade's own item at full width. There is no
// property the facade could have made `required` to prevent it: the slot is an
// item, not a value.
//
// AND THE NUMBER THE SEAM CARRIES DOES NOT MOVE. Measured rather than argued:
// one of these built in a bare QQuickView at 620 wide, holding three 36-pixel
// rows, with the line below present and then deleted and nothing else changed.
//
//     with the data: line          without it
//     section.implicitHeight 180   section.implicitHeight 180
//     rows.implicitHeight    112   rows.implicitHeight    112
//     rows.y                   0   rows.y                  34
//     rows reparented       true   rows reparented      false
//
// IDENTICAL TO THE PIXEL where the seam can see, and wrong everywhere it
// cannot. The facade's floor is `Math.max(rows.implicitHeight,
// drawing.implicitHeight)` and both terms are unchanged -- the slot below keeps
// its height because its binding reads `row.rows.implicitHeight` whether or not
// the Column was ever moved into it. So the section is 180 tall either way, the
// page around it lays out to the same pixel, and what has actually happened is
// that the rows are sitting at y=34 ON TOP OF THE HEADING with 112 pixels of
// empty slot underneath them.
//
// So there is nothing to assert against. A bench that read implicit heights
// would pass over this, and so would every check in tests/: the only way to see
// it is to look at the thing, or to read the visual parent, which is not a
// number the facade publishes. That is the sharpest available statement of what
// "the slot is the one thing a facade cannot require" costs.
//
// ---------------------------------------------------------------------------
// THERE IS NO CARD AROUND THE ROWS, AND THAT IS THE WHOLE OF THE REDRAW
// ---------------------------------------------------------------------------
//
// genesis draws one rounded card and lays every row inside it. Windows 11 does
// not have that shape anywhere: in the Settings app EVERY ROW IS ITS OWN CARD
// -- a SettingsCard, `CardBackgroundFillColorDefault`, its own 4px radius on
// all four corners -- and a section is a heading with a STACK of them under it,
// separated by a gap.
//
// CARDS DO NOT JOIN. The top-rounds/middle-squares arrangement that a
// recreation reaches for exists only INSIDE a SettingsExpander, where the
// expanded children are part of one control. A list of independent settings is
// not that, and drawing it that way is the commonest way a Fluent settings page
// comes out looking like Android.
//
// So the card moved DOWN, into the row implementations beside this file, and
// what is left here is the heading and the slot. A row that draws no background
// of its own will look like a row on the page's ground -- which is legible, and
// is what this section would have looked like anyway before there were cards.
//
// THE GAP IS 2 AND MICROSOFT'S IS 4, and that is the one number in this file
// nobody here can move. `SettingsCardSpacing` is 4 in the Community Toolkit
// sample the official docs call "the correct Windows 11 design specifications";
// the facade's Column is `spacing: 2` and its header says in as many words that
// a theme cannot pick another one. Two pixels against four, on a boundary the
// eye reads as "these are separate things", which it still does. It is written
// down rather than absorbed silently because the next person to measure this
// against a screenshot will find it.
//
// THE HEADING'S MARGINS ARE VERBATIM. `Margin="1,30,0,6"` on a
// BodyStrongTextBlockStyle is what the sample writes above every group: one
// pixel of left indent so the words clear the cards' left edge without leaving
// it, thirty above so the previous group has ended, six below so the heading
// belongs to what follows it rather than floating between the two.
//
// THE HEADING SITS OUTSIDE THE ROWS, which is the promise this file inherited
// from the component it was split out of and which Windows keeps for the same
// reason: inside, it would be the first row of a list of rows and would have to
// be styled hard enough not to be read as one.

import QtQuick
import qs
// SettingsSection is modules/settings/SettingsSection.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins.
import qs.modules.settings
// Fluent lives one directory up. Without this line every `Fluent.` below is a
// ReferenceError at runtime, once per read; tests/qml-rules.sh checks the pair.
import qs.themes.windows

Column {
    id: root

    // The facade, handed in by its Loader as an initial property. Typed and
    // `required` for the reason rule 1 of README.md sets out: `property var
    // row` would make every read below unchecked.
    required property SettingsSection row

    // NOTHING BETWEEN THE HEADING AND THE ROWS, because the heading carries its
    // own margins. A Column spacing here would be a second gap on top of the
    // six the sample specifies, and the two would have to be kept in agreement
    // by hand for ever.
    spacing: 0

    // ---------------- The heading line ----------------
    Item {
        width: root.width

        // 30 above and 6 below, from the sample. The line itself is as tall as
        // the taller of the words and the action -- and the action's height is
        // read even when it is not shown, deliberately: a section that grows an
        // action must not grow a heading line as well, or a page twitches
        // vertically as its actions come and go.
        implicitHeight: 30 + line.implicitHeight + 6

        Item {
            id: line

            x: 1
            y: 30
            width: parent.width - 1
            implicitHeight: Math.max(heading.implicitHeight, action.implicitHeight)

            Row {
                id: heading

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.itemSpacing

                // WINDOWS' SECTION HEADINGS CARRY NO ICON, and this one is
                // drawn anyway. The glyph is what a call site said -- forty-nine
                // of them set it -- and dropping content because this theme
                // would not have asked for it is a different decision from
                // drawing it in this theme's ink. So it is here, at the
                // heading's own size and colour rather than in the accent
                // genesis gives it, which is as close to absent as it gets
                // without throwing the caller's word away.
                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    visible: root.row.glyph !== ""
                    text: root.row.glyph
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    color: Theme.textOnSurface
                }

                // BodyStrong: 14 at Semibold, in TextFillColorPrimary. Windows
                // 11's typography rule is Semibold for emphasis and never Bold,
                // which is what Fluent.strongWeight carries.
                //
                // NO EXPLICIT LINE HEIGHT, although Body's is published as 20
                // and WinUI sets none. Fluent.bodyLine is derived from
                // Theme.fontSize, which this shell hands to Text as a POINT
                // size, and lineHeight in FixedHeight mode is in PIXELS -- so
                // the constant comes out at roughly the em box on this machine
                // and would crowd rather than space. A heading is one line
                // anyway; the face's own metrics are what Windows uses.
                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text: root.row.title
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    font.weight: Fluent.strongWeight
                    color: Theme.textOnSurface
                }
            }

            // ---------------- The section's action ----------------
            //
            // A HyperlinkButton, which is what the Settings app puts at the
            // right of a group heading: accent text on nothing, with a subtle
            // backplate that appears under the pointer. Not a filled button --
            // an accent fill up here would outrank every control in the section
            // it introduces.
            //
            // THE HOVER DOES NOT ANIMATE. Windows swaps the brush on a
            // DiscreteObjectKeyFrame at time zero, and Fluent.hoverMs is 0 to
            // say so; there is no Behavior on any of the three colours below,
            // in this file or in any other in this directory. A fade here is the
            // single fastest way to give a Fluent recreation away.
            //
            // AND HOVER BRIGHTENS WHILE PRESS DIMS. #15FFFFFF over #08FFFFFF:
            // the pressed fill is DARKER than the resting one, which is the
            // opposite of what most toolkits do and the second-best tell after
            // animating the hover.
            Rectangle {
                id: action

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                visible: root.row.actionText !== "" || root.row.actionGlyph !== ""
                implicitWidth: actionRow.implicitWidth + Fluent.controlPaddingH * 2
                implicitHeight: Fluent.controlHeight
                radius: Fluent.controlRadius

                color: actionMouse.pressed ? Fluent.fillPress
                    : actionMouse.containsMouse ? Fluent.fillSubtleHover
                    : "transparent"

                Row {
                    id: actionRow

                    anchors.centerIn: parent
                    spacing: Theme.itemSpacing

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        visible: root.row.actionGlyph !== ""
                        text: root.row.actionGlyph
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.captionSize
                        color: Theme.primary
                    }

                    // Body and not BodyStrong. A hyperlink is distinguished by
                    // its colour, and adding weight to it as well says it is
                    // two things at once.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        visible: root.row.actionText !== ""
                        text: root.row.actionText
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodySize
                        font.weight: Fluent.normalWeight
                        color: Theme.primary
                    }
                }

                // The button asks the facade; it does not act. Rule 4: a theme
                // reads `row` and emits through it, and has no idea what the
                // page wired this to.
                MouseArea {
                    id: actionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.row.actionTriggered()
                }
            }
        }
    }

    // ---------------- Where the rows go ----------------
    //
    // An empty item whose only job is to have a position and a height; the line
    // that matters is `data`, and the top of this file has the account of it.
    //
    // NO INSET, which is the difference a missing card makes. genesis holds the
    // column four pixels off its card's rounded corner; there is no corner here
    // to hold it off, and Windows lines the cards up with the heading's own
    // column -- the single pixel of indent in `Margin="1,30,0,6"` is the
    // heading's, not the cards'.
    //
    // The height is the column's, read straight off it. A slot with no height
    // of its own is an item of zero height in a Column, and the rows would draw
    // over whatever came next.
    Item {
        id: slot

        width: root.width
        implicitHeight: root.row.rows.implicitHeight

        data: [root.row.rows]
    }
}
