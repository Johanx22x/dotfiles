// ONE LINE OF THE CHEATSHEET: THE CHORD IN A GUTTER, THEN WHAT IT DOES.
//
// NO PHOTOGRAPH, AND THERE CANNOT BE ONE. Windows has no cheatsheet; the
// nearest thing it ships is the keyboard-shortcut list in its own help pages,
// which is a web page. So this row is drawn in the Settings grammar the
// photographs do settle -- key caps as pills at the control radius, body text
// for the sentence, no separators between rows -- and the ARITHMETIC below is
// not a look at all and is not this file's to choose.
//
// ---------------------------------------------------------------------------
// FIVE OF THE SEVEN PROPERTIES ARE NUMBERS A THEME WOULD NORMALLY OWN
// ---------------------------------------------------------------------------
//
// The sheet sizes its key gutter by ADDING CHIPS UP: `chipSpacing * (n - 1)`
// plus, per key, `FontMetrics.advanceWidth(key) + chipPadding`. So a chip
// drawn with any other padding, any other spacing or any other face puts the
// chords back over the edge of the card -- and it does it SILENTLY: nothing
// fails to load, nothing fails a test, nothing reaches a log.
// modules/settings/pages/KeybindsPage.qml, which computes the same gutter for
// the same chords, says in its own words that a model which does not add up
// the same numbers the chip is drawn with "drifts silently".
//
// Those three therefore pass through this file UNALTERED, into
// components/Chip.qml's `padding`, its `labelFont` and the Row's `spacing`.
// Not scaled, not rounded, not floored, not replaced with a Fluent constant
// that happens to agree today. The chip that is measured and the chip that is
// drawn have to be the same chip.
//
// THE CHORD IS FLUSH WITH THE RIGHT EDGE OF THE GUTTER, which is a promise the
// facade's header makes and only this file can keep: the KEY is then always
// the chip nearest its own description, the modifiers trail off to the left,
// every description in a column starts at the same x whatever the chord is,
// and the eye finds "S" in the same place in "SUPER S" and in "SUPER CTRL S".
//
// ---------------------------------------------------------------------------
// WHAT IS HOISTED, AND WHY ALL OF IT IS
// ---------------------------------------------------------------------------
//
// Inside a Repeater delegate `row.anything` is exactly as unchecked as
// `property var row` would have made the whole file -- measured both ways in
// themes/genesis/components/LevelMeter.qml, where a misspelling at the top
// level is a named `[missing-property]` and the same misspelling in the
// delegate is nothing at all. So every value the delegate needs is read once
// up here, into a typed readonly property, and the delegate binds to the local
// name. The read that crosses the seam is then a checked one and the delegate
// never touches `row`.
//
// `caps` COMES FROM THE FACADE ALREADY ANSWERED. It is the chord with "is this
// the key" already in it -- the last chip is the key, the rest are modifiers,
// which is the order Cheatsheet.qml builds the array in. This file does not
// recompute it from `keys` and must not: that is a fact about a chord rather
// than a look, and working it out in a delegate would be working it out in the
// one place nothing can check.
//
// `name:` AND NOT `label:` ON THE CHIP, which is rule 3 arriving from an
// unexpected direction. SettingsSearch indexes anything carrying a non-empty
// string `label`, and a sheet of chords is roughly two hundred key caps; one
// shared `label` would have put every one of them into an index of settings.
// components/Chip.qml is where the split between the two names is written down
// and the key role is the side of it that is not a setting.

import QtQuick
import qs
import qs.themes.windows
import qs.components

Item {
    id: root

    required property BindRow row

    // Hoisted for the delegate. See the header.
    readonly property var caps: root.row.caps
    readonly property int chipPadding: root.row.chipPadding
    readonly property int chipSpacing: root.row.chipSpacing
    readonly property var chipFont: root.row.chipFont

    implicitHeight: Math.max(chips.implicitHeight, description.implicitHeight) + 2 * Fluent.textLeading

    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // THE GUTTER IS A BOX AND THE CHORD IS RIGHT-FLUSHED INSIDE IT. The box
    // rather than the Row carries the width, and the Row is anchored to its
    // right edge: a Row lays out from its own left edge and reversing its
    // layoutDirection mirrors it about its CONTENT rather than about the width
    // it was given, which is not the same thing and is not the promise the
    // facade made.
    Item {
        id: gutter

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: root.row.gutterWidth

        Row {
            id: chips

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            spacing: root.chipSpacing

            Repeater {
                model: root.caps

                Chip {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter

                    role: "key"
                    name: modelData.text
                    filled: modelData.isKey

                    padding: root.chipPadding
                    labelFont: root.chipFont
                }
            }
        }
    }

    Text {
        id: description

        anchors.left: gutter.right
        anchors.leftMargin: root.row.gap
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        elide: Text.ElideRight

        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        color: Theme.textOnSurface
    }
}
