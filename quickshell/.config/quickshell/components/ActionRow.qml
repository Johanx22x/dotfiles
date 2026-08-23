// A row that explains something and offers to do it: the reading of an
// InfoRow with a button on the end. THIS IS THE HALF THE PAGES SEE; the pixels
// are in themes/<theme>/components/ActionRow.qml.
//
// WHY NOT JUST MAKE InfoRow CLICKABLE. Because then every reading in the
// window becomes a thing you have to test with the pointer to find out
// whether it does anything. InfoRow's whole contract is that it does not
// respond -- no hover, no cursor -- and the moment one of them does, that
// promise is gone for all of them. The button here is the target, and it
// looks like one. That is why this is a separate type rather than a property
// on that one, and it is the reason a theme must not blur the two: see rule 7
// in themes/genesis/components/README.md.
//
// `actionEnabled` IS NOT `enabled`, AND THE TWO ARE READ SEPARATELY. `enabled`
// is Qt's, it comes down the item tree, and it means the whole row is out of
// play. `actionEnabled` means the ROW IS LIVE AND THE BUTTON IS BUSY -- five of
// the eight call sites turn it off for the duration of the thing they started,
// so that a second click cannot start a second copy of it, while the label and
// the description beside it stay perfectly readable. A theme that folded one
// into the other would grey out a sentence somebody is in the middle of
// reading, or would leave a button live while its action runs.
//
// The action is a WORD and not a glyph. A pencil, a folder and an ellipsis
// all mean "choose a file" to somebody, and none of them means it to
// everybody; at the two or three of these a page carries, the width is
// affordable. `actionGlyph` is optional and goes BEFORE the word, never
// instead of it.
//
// The root was already an Item, so the question ToggleRow's header answers --
// whether a Rectangle root was API or drawing -- did not arise here. The check
// was run anyway over all 8 call sites: they set `glyph`, `label`,
// `description`, `actionText`, `actionGlyph`, `actionEnabled` and `visible`,
// and nothing else.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string description: ""

    property string actionText: ""
    property string actionGlyph: ""
    // Off while the action is running, so a second click cannot start a
    // second copy of it.
    property bool actionEnabled: true

    signal triggered

    // See the note in ToggleRow: the parent supplies the width, and binding
    // implicitWidth to it instead would be a loop.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320

    // THE THEME DRIVES THE HEIGHT, AND HERE IT ACTUALLY MOVES. Like InfoRow,
    // this row wraps a description rather than eliding it -- an explanation cut
    // off at the width of a sidebar is an explanation nobody finishes reading
    // -- and how many lines that takes is a text metric only the theme has. A
    // theme that reported a constant here would clip the long ones; the
    // UpdatesPage descriptions are already two lines at this width.
    //
    // The floor is what the row was before the split with the term that moved
    // taken out. See ToggleRow for the two ways a theme reports nothing and for
    // why this reads the Loader's implicit size rather than the loaded item's.
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/ActionRow.qml")

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
