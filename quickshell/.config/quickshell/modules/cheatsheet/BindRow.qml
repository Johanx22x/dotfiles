// One line of the cheatsheet: the chord on the left, what it does on the
// right.
//
// A file of its own because the alternative was a Repeater inside a Repeater
// inside a Repeater inside a Column -- the row is the innermost of four nested
// models, and written inline it sat at a depth where the indentation carried
// more meaning than the code did.
//
// THE CHORD READS RIGHT TO LEFT
// The chips are laid out inside a fixed-width gutter with the row's direction
// reversed, so the KEY is always the chip nearest its own description and the
// modifiers trail off to the left. Two things fall out of that: every
// description in a column starts at the same x whatever the chord is, and the
// eye finds "S" at the same place in "SUPER S" and in "SUPER CTRL S".
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

    // How much room this row would need for its own chips. Reported back so the
    // sheet can size the gutter to the widest chord it is actually showing
    // rather than to a number written down when only one compositor existed --
    // niri binds four-chip chords and the old fixed 150 pushed them off the
    // card. Reading the Row's implicit width and not its width, which is the
    // gutter it has been told to fit into.
    readonly property int naturalWidth: chipRow.implicitWidth

    readonly property int gap: 12

    implicitHeight: 30

    Row {
        id: chipRow

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        // Right to left, so the first item laid out ends up rightmost. The
        // model is reversed to match: index 0 after the reverse is the key.
        layoutDirection: Qt.RightToLeft
        width: root.gutterWidth
        spacing: 5

        Repeater {
            model: root.keys.slice().reverse()

            Rectangle {
                id: chip

                required property int index
                required property string modelData

                readonly property bool isKey: chip.index === 0

                implicitWidth: text.implicitWidth + 14
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
