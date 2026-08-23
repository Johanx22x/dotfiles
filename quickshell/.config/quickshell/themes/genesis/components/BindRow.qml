// How genesis draws one line of the cheatsheet. The public half -- the seven
// required properties, why every one of them is required, and why five numbers
// the theme would normally choose come DOWN across the seam instead -- is
// components/BindRow.qml.
//
// THE CHORD IS FLUSH WITH THE RIGHT EDGE OF THE GUTTER, which is the promise
// the facade cannot require and this file keeps. So the KEY is always the chip
// nearest its own description and the modifiers trail off to the left. Two
// things fall out of that: every description in a column starts at the same x
// whatever the chord is, and the eye finds "S" at the same place in "SUPER S"
// and in "SUPER CTRL S".
//
// PLACED AT THAT EDGE RATHER THAN LAID OUT BACKWARDS FROM IT, which is a
// change of mechanism and not of appearance. This was a Row of its own laid
// out RightToLeft inside a width of exactly the gutter, and a positioner
// re-lays-out when its CONTENT changes, not when its own width does --
// measured: a RightToLeft Row taken from 150 wide to 227 leaves every chip
// precisely where it was, on that turn and the next. That never showed here
// because the gutter only ever moved as a consequence of the chips moving,
// which is an invariant nobody wrote down and nothing enforced. An `x` bound
// to the gutter is re-evaluated whichever of the two changes.
//
// THE PILL IS components/Chip.qml NOW, AND IT WAS THE SAME PILL BEFORE.
// This file used to carry thirty-seven lines of Rectangle, radius, two-tone
// colour and Text that were a byte-for-byte duplicate of the key cap the
// keybinds settings page drew, which is the duplication Chip was written to
// absorb -- three shapes in three files that were one pill with three jobs.
// `role: "key"` is that job. What this file still decides is where the chips
// sit; what a cap looks like is one file for both places that draw one.
//
// The key chip is the accent one and the modifiers are muted -- `filled` says
// which -- for the same reason the chord is laid out this way round: the
// modifier is the part you already know.

import QtQuick
import qs
import qs.components

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `BindRow` here is the facade and not
    // this file.
    required property BindRow row

    // HOISTED, both of them, because the Repeater below is a delegate and rule
    // 1's checking stops at its edge: `row.chipPadding` read from inside the
    // delegate would be exactly as unchecked as `property var row` would have
    // made the whole file. Read once here, where the type is real, and let the
    // delegate bind to the local name. LevelMeter.qml in this directory does
    // the same and says so where it does it.
    //
    // These two are the pair components/Chip.qml calls `padding` and
    // `labelFont`: the total width added to the cap's label, and the face the
    // sheet measured its gutter in. Handed straight through, unaltered -- a
    // theme that adjusted either of them here would be putting the chords back
    // over the edge of the card, which is the bug the whole arrangement
    // exists to prevent.
    readonly property int chipPadding: root.row.chipPadding
    readonly property var chipFont: root.row.chipFont

    implicitHeight: 30

    Row {
        id: chipRow

        // The right edge of the chord sits on the right edge of the gutter,
        // and the chord runs left from there. With the row sized to its own
        // content the layout direction stops mattering, so the chord is drawn
        // in the order it arrives -- modifiers first, key last -- and there is
        // no reversed copy of the array to keep in step with an `index === 0`.
        x: root.row.gutterWidth - chipRow.width
        anchors.verticalCenter: parent.verticalCenter

        // THE THIRD NUMBER IN THE SHEET'S SUM, and it belongs to this Row
        // rather than to any one chip: `padding` and the face describe ONE cap,
        // and the spacing is the gap BETWEEN caps. The chip never sees it.
        spacing: root.row.chipSpacing

        Repeater {
            // Already carrying `isKey` per cap. Which chip is the key is the
            // facade's answer -- a fact about a chord, not about a look -- and
            // it is decided there for the second reason too: a delegate working
            // it out from `row.keys.length` would be working it out in the one
            // place nothing checks.
            model: root.row.caps

            Chip {
                id: chip

                required property var modelData

                role: "key"

                // `name` and not `label`, which is what keeps a sheet's worth
                // of key caps out of the settings search. See
                // components/Chip.qml, and rule 3 in README.md.
                name: chip.modelData.text

                filled: chip.modelData.isKey

                padding: root.chipPadding
                labelFont: root.chipFont
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.row.gutterWidth + root.row.gap
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Theme.fontWeight
        color: Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }
}
