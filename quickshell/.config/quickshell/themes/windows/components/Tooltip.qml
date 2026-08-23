// How genesis draws a hover note: an opaque rounded box with one wrapped
// sentence in it. The public half -- where the note goes, when it flips above
// the row instead of below it, and what a flipped one does to the stacking of
// everything between it and the viewport -- is components/Tooltip.qml, and
// none of that is drawing.
//
// OPAQUE, UNLIKE ALMOST EVERYTHING ELSE THIS SHELL DRAWS, and that is the
// promise this file inherited. A translucent note over a translucent window
// over a wallpaper is three layers of image behind two lines of small text,
// and the point of the thing is that it can be read at a glance. A theme that
// gives this a `Theme.glass(...)` colour has broken it in the exact way the
// component exists to prevent.
//
// THE WIDTH IS DECIDED HERE AND THE FACADE READS IT BACK, which is the one
// place this component departs from rule 2 of the README in this directory.
// The facade's header says why: a note is placed by x and y in its parent's
// coordinates rather than laid out by a Column, so it has nowhere to get a
// width from except the text -- and the flip arithmetic on the other side
// reads the height this file reports. Report both, and never derive either
// from this item's own `width` or `height`, which the Loader assigns from the
// facade and which would close the loop.
//
// AND `maxWidth` IS THE CALLER'S, not this file's. Wide enough for a sentence
// over two or three lines; wider and the eye has to travel back across the row
// it is explaining.

import QtQuick
import qs
// Tooltip in the declaration below is components/Tooltip.qml -- the facade --
// and not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property Tooltip row

    implicitWidth: Math.min(label.implicitWidth + Theme.groupPadding * 2, root.row.maxWidth)
    implicitHeight: label.implicitHeight + Theme.groupPadding

    radius: 10
    color: Theme.surfaceContainerHighest
    border.width: 1
    border.color: Theme.outlineVariant

    Behavior on color {
        ColorAnimation { duration: Theme.recolorDuration }
    }

    // NO MouseArea, NO HoverHandler, NO cursorShape. A note appears because
    // something else is being hovered and goes away when it stops; it is not a
    // thing you point at. One that took the pointer would take it away from
    // the row underneath, which is the row whose hover is holding the note up.
    Text {
        id: label

        anchors.centerIn: parent
        width: Math.min(label.implicitWidth, root.row.maxWidth - Theme.groupPadding * 2)

        wrapMode: Text.WordWrap
        text: root.row.text
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        color: Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }
}
