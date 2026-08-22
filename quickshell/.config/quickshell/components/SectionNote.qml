// A sentence the window says to you, printed under the rows it is about.
//
// Every settings page has these: a line explaining what a switch will cost,
// why a list is empty, or which key still works after the button that did the
// same job has been hidden. They are not rows -- there is nothing to click and
// nothing to hover -- so they carry no card, no hover tint and no glyph, only
// the section's own left inset so that the sentence lines up with the labels
// above it.
//
// IT IS A Text AND NOT A WRAPPER AROUND ONE, which is the whole reason this
// component is worth having. Every knob a call site turns is already a
// property of Text: the words, whether it is shown at all, the point size, the
// colour, and the space above and below. An Item holding a Text would have to
// re-declare and forward each of those, and the first note that needed a sixth
// would be the one that had to stay inline. Deriving means a note overrides
// exactly what it needs and says nothing about the rest.
//
// THE COLOUR IS A DEFAULT AND NOT A RULE. Most of these are quiet remarks and
// take the muted tone; the ones reporting something actually wrong -- a
// blocked adapter, a screen that is not connected, two monitors drawn on top
// of each other -- set Theme.warning themselves, and two set an expression
// because whether they are a warning depends on what they ended up saying.
//
// THE POINT SIZE IS A DEFAULT AND NOT A RULE EITHER, and this one is less
// comfortable. Twenty-five of the thirty-five notes drawn through here are one
// step under the body size and ten are two, and the split does not follow the
// meaning: the bar page writes its notes at -2 and the bluetooth page writes
// the same kind of note at -1. That is worth settling one day. It is not worth
// settling silently inside a refactor, so every note keeps the size it had.

import QtQuick
import "root:/"

Text {
    id: root

    // Inset to the same padding the rows use, so the sentence starts under
    // the label above it rather than under the card's edge. Like the rows,
    // it takes its width from the parent -- see the note in ToggleRow.
    //
    // ALIGNED WITH THE ROW AND NOT WITH THE ROW'S LABEL, which is the thing
    // this would rather be. A label sits behind a glyph whose width is a font
    // measurement, and StepperRow's tooltip documents at length why measuring
    // that with mapToItem does not work: it is a function evaluated once,
    // before anything has been laid out, and it reads 0. The section's own
    // padding is close enough and is never wrong.
    x: Theme.groupPadding
    width: parent ? parent.width - Theme.groupPadding * 2 : implicitWidth

    // The gap that keeps the sentence off whatever row comes next: twenty-eight
    // of the thirty-five want exactly this, six want four and one wants none.
    //
    // There is no matching default above, because eighteen want none: a note
    // usually hangs directly off the row it is about and wants to be near it.
    // The ones following a control whose own bottom edge is tight -- a
    // ChoiceRow's segment track, say -- ask for a topPadding themselves.
    bottomPadding: 6

    wrapMode: Text.WordWrap
    font.family: Theme.fontFamily
    font.pointSize: Theme.fontSize - 1
    color: Theme.textOnSurfaceVariant

    Behavior on color {
        ColorAnimation { duration: Theme.recolorDuration }
    }
}
