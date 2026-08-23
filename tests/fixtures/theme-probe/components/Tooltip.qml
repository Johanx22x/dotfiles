// Tooltip, as the probe draws it: yellow text on black, clamped to the width
// the facade allows.
//
// It reports both dimensions and neither is floored by the facade, so a theme
// that reported nothing here would give a note of zero size. Rule 2's loop
// cannot form: a note has no column above it taking its size from this.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property Tooltip row

    implicitWidth: label.width + 8
    implicitHeight: label.implicitHeight + 8
    color: "#000000"
    border.width: 2
    border.color: "#00ffff"

    Text {
        id: label

        x: 4
        y: 4

        // Against the Text's OWN implicit width, which for a wrapping Text is
        // its unwrapped natural width and does not depend on the width it is
        // given. Reading root.width here instead would be the loop.
        width: Math.min(label.implicitWidth, root.row.maxWidth - 8)

        text: root.row.text
        color: "#ffff00"
        font.family: Theme.fontFamily
        wrapMode: Text.Wrap
    }
}
