// One line of the cheatsheet: the chord on the left, what it does on the
// right. THIS IS THE HALF THE SHEET SEES; the chips and the type are in
// themes/<theme>/components/BindRow.qml.
//
// A file of its own because the alternative was a Repeater inside a Repeater
// inside a Repeater inside a Column -- the row is the innermost of four nested
// models, and written inline it sat at a depth where the indentation carried
// more meaning than the code did.
//
// EVERY PROPERTY BELOW IS `required`, ALL SEVEN, and that is not a house
// style. modules/settings/pages/KeybindsPage.qml:178-185 measured what the
// alternative costs on the page that draws the same chords: an inline
// component does NOT reliably see the ids of the document it is declared in,
// so a value read out of the enclosing scope resolves while the rows are built
// from inside that one file and raises "ReferenceError: root is not defined"
// the moment one is built from anywhere else -- at runtime, as a warning. A
// required property is checked when the document is compiled, so a call site
// that forgets one cannot be shipped. This file is now reached through a
// Loader and a theme, which is exactly the "anywhere else" that argument is
// about.
//
// WHAT CROSSES THE SEAM DOWNWARDS AND WHY, because five of the seven are
// numbers a theme would normally choose for itself. The sheet sizes its key
// gutter by ADDING CHIPS UP -- `chipSpacing * (n - 1)` plus, per key,
// `FontMetrics.advanceWidth(key) + chipPadding` -- so a chip drawn with any
// other padding or any other face puts the chords back over the edge of the
// card, silently: nothing fails to load, nothing fails a test and nothing
// reaches a log. components/Chip.qml carries the whole of that argument; these
// properties are how the sheet's arithmetic reaches the pill it is arithmetic
// about. `gutterWidth` and `gap` are the same kind of number one level up: the
// sheet adds them to the longest description to decide how wide a column has
// to be, so the row has to leave exactly them.
//
// THE CHORD IS FLUSH WITH THE RIGHT EDGE OF THE GUTTER
// So the KEY is always the chip nearest its own description and the modifiers
// trail off to the left. Two things fall out of that: every description in a
// column starts at the same x whatever the chord is, and the eye finds "S" at
// the same place in "SUPER S" and in "SUPER CTRL S". That is a promise about
// shape and it lives in the theme file, which is the only place that can keep
// it.

import QtQuick
import qs.modules

Item {
    id: root

    // The chord, modifiers first and the key LAST, as Cheatsheet.qml builds
    // it: ["SUPER", "SHIFT", "S"].
    required property var keys
    required property string label

    // How much room the chord gets. Set by the caller so every row in the
    // sheet agrees, see Cheatsheet.keyGutter.
    required property int gutterWidth

    // The chip geometry, from the sheet. See the header, and Cheatsheet's own
    // chipPadding, for why these arrive from the call site rather than being
    // written in the theme: the gutter is computed by adding exactly these
    // numbers up, so the chip that is drawn and the chip that is measured have
    // to be the same chip.
    required property int chipPadding
    required property int chipSpacing

    // THE FACE THE GUTTER WAS MEASURED IN, and the one property this row did
    // not have before the split. It did not need one: the chip's Text was in
    // this file, and it spelled out `Theme.fontSize - 1.5` a few lines under a
    // FontMetrics in Cheatsheet.qml that spelled out the same thing -- two
    // files kept in step by hand, which Cheatsheet.qml said out loud and could
    // do nothing about. With the pill behind a theme there is no hand left to
    // do it with, so the sheet hands over the FontMetrics' OWN font and the
    // chip is drawn in it. Measured and drawn are then one value rather than
    // two spellings that agree today. This is components/Chip.qml's `labelFont`
    // and it means what that file says it means.
    required property var chipFont

    // The space between the chord and its description. From the sheet, like
    // the chip geometry above and for the same reason: the sheet adds this to
    // the gutter and to the longest description to decide how wide a column
    // has to be, so it has to be the same number the row leaves.
    required property int gap

    // THE CHORD WITH THE ANSWER TO "IS THIS THE KEY" ALREADY IN IT, decided
    // here and not in the delegate that draws the chips.
    //
    // Two reasons and they point the same way. It is a fact about a CHORD --
    // the last chip is the key and everything before it is a modifier, which
    // is the order Cheatsheet.qml builds the array in -- and a fact about a
    // chord is not a look. And rule 1 in themes/genesis/components/README.md
    // measured that a delegate reading `row.keys.length` gets no checking of
    // any kind, so a theme that worked it out for itself would be working it
    // out in the one place nothing can check it.
    readonly property var caps: root.keys.map((key, i) => ({
        text: key,
        isKey: i === root.keys.length - 1
    }))

    // NO WIDTH RULE HERE, unlike ToggleRow: the sheet gives every row its
    // column's width outright, so there is nothing to derive and nothing that
    // could loop. The theme is filled to whatever it was given.

    // THE THEME DRIVES THE HEIGHT, WITH A FLOOR UNDER IT. 30 is what this row
    // has always been and it is a floor rather than the answer -- a theme with
    // taller chips reports more and gets it. It is here for the second reason
    // ToggleRow gives: a root Item whose author forgot `implicitHeight`
    // reports 0, nothing warns, and a sheet of zero-height rows draws every
    // bind on top of the last one.
    implicitHeight: Math.max(30, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/BindRow.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()

        // See ToggleRow for why there is no status handler here either.
    }
}
