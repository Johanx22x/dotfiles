// One line of the cheatsheet: the chord on the left, what it does on the
// right.
//
// A file of its own because the alternative was a Repeater inside a Repeater
// inside a Repeater inside a Column -- the row is the innermost of four nested
// models, and written inline it sat at a depth where the indentation carried
// more meaning than the code did.
//
// THE CHORD IS FLUSH WITH THE RIGHT EDGE OF THE GUTTER
// So the KEY is always the chip nearest its own description and the modifiers
// trail off to the left. Two things fall out of that: every description in a
// column starts at the same x whatever the chord is, and the eye finds "S" at
// the same place in "SUPER S" and in "SUPER CTRL S".
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
// The key chip is the accent one and the modifiers are muted, for the same
// reason -- the modifier is the part you already know.

import QtQuick
import "root:/"

Item {
    id: root

    // The chord, modifiers first and the key LAST, as Cheatsheet.qml builds
    // it: ["SUPER", "SHIFT", "S"].
    required property var keys
    required property string label

    // How much room the chord gets. Set by the caller so every row in the
    // sheet agrees, see Cheatsheet.keyGutter.
    required property int gutterWidth

    // The chip geometry, from the sheet. See Cheatsheet.chipPadding for why
    // these arrive from the call site rather than being written here: the
    // gutter is computed by adding exactly these two numbers up, so the chip
    // that is drawn and the chip that is measured have to be the same chip.
    required property int chipPadding
    required property int chipSpacing

    // The space between the chord and its description. From the sheet, like
    // the chip geometry above and for the same reason: the sheet adds this to
    // the gutter and to the longest description to decide how wide a column
    // has to be, so it has to be the same number the row leaves.
    required property int gap

    implicitHeight: 30

    Row {
        id: chipRow

        // The right edge of the chord sits on the right edge of the gutter,
        // and the chord runs left from there. With the row sized to its own
        // content the layout direction stops mattering, so the chord is drawn
        // in the order it arrives -- modifiers first, key last -- and there is
        // no reversed copy of the array to keep in step with an `index === 0`.
        x: root.gutterWidth - chipRow.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.chipSpacing

        Repeater {
            model: root.keys

            Rectangle {
                id: chip

                required property int index
                required property string modelData

                readonly property bool isKey: chip.index === root.keys.length - 1

                implicitWidth: text.implicitWidth + root.chipPadding
                implicitHeight: 22
                // Pill, the same shape language the bar's groups use.
                radius: height / 2

                color: chip.isKey ? Theme.primaryContainer : Theme.surfaceContainerHighest

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }

                Text {
                    id: text

                    anchors.centerIn: parent
                    text: chip.modelData
                    font.family: Theme.fontFamily
                    // Under the body text: a chip is a label on a key, not a
                    // sentence, and at the same size the chords compete with
                    // the descriptions instead of introducing them.
                    font.pointSize: Theme.fontSize - 1.5
                    font.weight: Theme.fontWeight
                    color: chip.isKey ? Theme.textOnPrimaryContainer : Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.gutterWidth + root.gap
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        text: root.label
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
