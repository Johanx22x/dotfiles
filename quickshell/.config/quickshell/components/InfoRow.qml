// A row that says something instead of doing something: a fact, a limit, or
// a place to go and do the thing this window will not. THIS IS THE HALF THE
// PAGES SEE; the pixels are in themes/<theme>/components/InfoRow.qml.
//
// IT LOOKS LIKE A ROW AND IT IS NOT ONE, which is the whole difficulty. The
// cheapest way to tell a reading from a control is that a control lights up
// under the pointer and this does not -- no hover, no cursor change, nothing
// to click. Anything that reads like a switch and answers to nothing is worse
// than plain text.
//
// AND THAT IS NOW A RULE THIS FILE CANNOT ENFORCE. The contract of this
// component is the ABSENCE of behaviour, and absence is the one thing a facade
// has no way to require: it declares no signal, so a theme that adds a
// MouseArea has broken nothing that would fail to compile, fail to load, or
// fail a test. It is written down instead -- rule 7 of
// themes/genesis/components/README.md, and again at the top of this theme's own
// implementation -- because a rule kept only by whoever remembers it is a rule
// with one reader.
//
// The second line is optional and muted. When it is there the row grows to
// fit it rather than eliding: an explanation cut off at the width of a
// sidebar is an explanation nobody finishes reading. Growing is the theme's
// job now, and it reaches the layout through implicitHeight below.
//
// The root was already an Item, so the question ToggleRow's header answers --
// whether a Rectangle root was API or drawing -- did not arise here. The check
// was run anyway over all 13 call sites: they set `glyph`, `label`,
// `description` and `visible`, and nothing else.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string description: ""

    // See the note in ToggleRow: the parent supplies the width, and binding
    // implicitWidth to it instead would be a loop.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320

    // THE THEME DRIVES THE HEIGHT, AND HERE IT ACTUALLY MOVES. This row is the
    // reason the facade reads a height back at all: `description` wraps, so
    // how tall the row is depends on a text metric only the theme has. The
    // floor is what the row was before the split, and it is the same floor
    // ToggleRow uses -- see that file for the two ways a theme reports nothing
    // and for why this reads the Loader's implicit size rather than the loaded
    // item's.
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/InfoRow.qml")

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
