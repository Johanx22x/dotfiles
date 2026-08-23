// How Windows draws one line of the cheatsheet. The public half -- the seven
// required properties, why every one of them is required, and why five numbers
// the theme would normally choose come DOWN across the seam instead -- is
// components/BindRow.qml.
//
// THE CHORD IS FLUSH WITH THE RIGHT EDGE OF THE GUTTER, which is the promise the
// facade cannot require and this file keeps. So the KEY is always the chip
// nearest its own description and the modifiers trail off to the left. Two
// things fall out of that: every description in a column starts at the same x
// whatever the chord is, and the eye finds "S" at the same place in "SUPER S"
// and in "SUPER CTRL S".
//
// PLACED AT THAT EDGE RATHER THAN LAID OUT BACKWARDS FROM IT, which is a change
// of mechanism and not of appearance. Written as a Row laid out RightToLeft
// inside a width of exactly the gutter, the chips do not move when the gutter
// does: a positioner re-lays-out when its CONTENT changes, not when its own
// width does -- measured, a RightToLeft Row taken from 150 wide to 227 leaves
// every chip precisely where it was, on that turn and the next. An `x` bound to
// the gutter is re-evaluated whichever of the two changes.
//
// THE PILL IS components/Chip.qml AND THIS FILE DOES NOT DRAW A KEY CAP. What is
// here is where the chips sit; what a cap looks like is one file for both places
// that draw one. `role: "key"` is the job.
//
// THE KEY CHIP IS THE ACCENT ONE AND THE MODIFIERS ARE MUTED -- `filled` says
// which -- for the same reason the chord is laid out this way round: the
// modifier is the part you already know. Under this theme the filled cap is
// Theme.primary with BLACK ink, because dark mode's accent is the light shade of
// the ramp; that is the Chip's business and not this file's.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in genesis's ToggleRow.qml on why it is `required`, why it is typed rather
    // than `var`, and why `BindRow` here is the facade and not this file.
    required property BindRow row

    // HOISTED, both of them, because the Repeater below is a delegate and rule
    // 1's checking stops at its edge: `row.chipPadding` read from inside the
    // delegate would be exactly as unchecked as `property var row` would have
    // made the whole file. Read once here, where the type is real, and let the
    // delegate bind to the local name. This is the obvious case in the whole
    // directory and it is the one this rule was found on twice.
    //
    // These two are the pair components/Chip.qml calls `padding` and
    // `labelFont`: the total width added to the cap's label, and the face the
    // sheet measured its gutter in. Handed straight through, UNALTERED -- a
    // theme that adjusted either of them here would be putting the chords back
    // over the edge of the card, which is the bug the whole arrangement exists
    // to prevent, and it would do it silently.
    readonly property int chipPadding: root.row.chipPadding
    readonly property var chipFont: root.row.chipFont

    // The third of the three that has to be hoisted, and it is a plain number
    // rather than a chip metric: the chord's x is computed from it and so is the
    // description's left margin, so it is read twice at the top level rather
    // than once here and once inside the Row.
    readonly property int gutterWidth: root.row.gutterWidth

    // WHAT THE FACADE READS BACK. One cap tall plus room to breathe. The
    // facade's floor is 30 and a Windows cap is 22, so this is the row and not
    // the floor: eight pixels of air is OURS -- there is no published cheatsheet
    // in Windows to take a number from.
    implicitHeight: 30

    Row {
        id: chipRow

        // The right edge of the chord sits on the right edge of the gutter, and
        // the chord runs left from there. With the row sized to its own content
        // the layout direction stops mattering, so the chord is drawn in the
        // order it arrives -- modifiers first, key last -- and there is no
        // reversed copy of the array to keep in step with an `index === 0`.
        x: root.gutterWidth - chipRow.width
        anchors.verticalCenter: parent.verticalCenter

        // THE THIRD NUMBER IN THE SHEET'S SUM, and it belongs to this Row rather
        // than to any one chip: `padding` and the face describe ONE cap, and the
        // spacing is the gap BETWEEN caps. The chip never sees it.
        spacing: root.row.chipSpacing

        Repeater {
            // Already carrying `isKey` per cap. Which chip is the key is the
            // facade's answer -- a fact about a chord, not about a look -- and it
            // is decided there for the second reason too: a delegate working it
            // out from `row.keys.length` would be working it out in the one place
            // nothing checks.
            model: root.row.caps

            Chip {
                id: cap

                required property var modelData

                role: "key"

                // `name` and not `label`, which is what keeps a sheet's worth of
                // key caps out of the settings search -- roughly two hundred of
                // them. See components/Chip.qml, and rule 3 in README.md.
                name: cap.modelData.text

                filled: cap.modelData.isKey

                padding: root.chipPadding
                labelFont: root.chipFont
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.gutterWidth + root.row.gap
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        elide: Text.ElideRight
        font.family: Theme.fontFamily

        // Body at normal weight. What a bind DOES is running text, and Windows
        // 11 keeps Semibold for emphasis; genesis set Theme.fontWeight here,
        // which under this theme is 600, and a sheet of sixty semibold lines has
        // no emphasis left in it.
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        color: Theme.textOnSurface
    }
}
