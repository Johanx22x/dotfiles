// One fact: what it is on the left, what it says on the right. THIS IS THE
// HALF THE CARDS SEE; the pixels are in themes/<theme>/components/Reading.qml.
//
// It is not a row in the ToggleRow sense and deliberately not built like one:
// nothing here is clickable, there is no hover, and the whole point is that it
// reads as a fact rather than as a control somebody forgot to wire up. The
// monitor cards stack nine of these above the line that separates what IS from
// what WOULD BE.
//
// AND THAT SENTENCE IS NOW A PROMISE ONLY THE THEME CAN KEEP, which is the one
// thing the split changed about this component. The contract is an ABSENCE --
// no MouseArea, no HoverHandler, no cursorShape, no colour that moves because
// a pointer is over it -- and a facade cannot require an absence: there is no
// signal to leave unconnected and no property to leave unread. It is rule 7 of
// themes/genesis/components/README.md, and components/InfoRow.qml is the same
// contract one directory up with the longer account of why.
//
// THE FACADE STAYED HERE AND DID NOT MOVE TO components/, which is the same
// answer CycleRow's header gives beside it: nine of these are stacked on a
// monitor card and nothing else in the shell stacks any. components/InfoRow.qml
// is the shell's reading -- a glyph, a label and a muted second LINE -- and this
// is a definition list, two columns with the value right-aligned and elided in
// the MIDDLE so that a long EDID string keeps both of its ends. A component in
// components/ is a claim that the next page will want it too, and no page does.
// themes/genesis/components/README.md is explicit that the seam does not care
// where a facade lives; modules/settings/SettingsSection.qml is the other one
// that stays outside components/ and its Loader says the same thing.
//
// `label` STAYS ON THIS SIDE, and not merely because the cards set it.
// modules/settings/SettingsSearch.qml builds its index by walking the live
// object tree and duck-types a row as anything with a non-empty string `label`
// -- and the walk recurses through the Loader below into the theme's items, so
// a theme that re-declared the name would put every reading in the index twice.
// See rule 3 in themes/genesis/components/README.md.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property string label: ""
    property string value: ""
    // Defaults to the ordinary text colour; the focused row uses the
    // accent so the one monitor that has the keyboard can be found without
    // reading all six lines.
    //
    // A COLOUR ACROSS THE SEAM, WHICH IS NOT THE THEME'S TOKEN BEING OVERRIDDEN.
    // Rule 5 says design tokens are the host's and reach a theme through
    // `import qs`; this is not one. It is the card saying WHICH OF TWO
    // MEANINGS this reading has -- ordinary or singled out -- and the card is
    // the only thing that knows. It is spelled as a colour rather than as a
    // bool because it was spelled as a colour before the split and rewriting
    // the API is not what a split is for; a theme that wants its own accent
    // for this reads Theme.primary the way the card did.
    property color tone: Theme.textOnSurface

    // The parent supplies the width. See the note at the top of
    // components/ToggleRow.qml: binding implicitWidth to the parent's width
    // instead is a loop, because a Column sizes itself to its widest child.
    //
    // 320 AND NOT `implicitWidth` IN THE FALLBACK, which is what this file said
    // before the split and is kept exactly: a Reading with no parent is 320
    // wide, and an implicitWidth this file no longer declares would be 0.
    width: parent ? parent.width : 320

    // THE THEME DRIVES THE HEIGHT, WITH A FLOOR UNDER IT. Twenty-four is what
    // this row was outright before the split -- a single muted line, tighter
    // than Theme.groupHeight because nine of them stack on one card -- so the
    // floor and the number the Loader reports agree today. A theme that wrapped
    // the value under the label instead reports a bigger one and the card grows
    // to fit. See components/ToggleRow.qml for the two ways a theme reports
    // nothing, and for why this reads the Loader's implicit size rather than
    // the loaded item's.
    implicitHeight: Math.max(24, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    //
    // THE THEME'S FILE IS UNDER components/ EVEN THOUGH THIS ONE IS NOT, for
    // the reason modules/settings/SettingsSection.qml gives beside its own
    // Loader: shell.qml carries one import per theme directory purely so the
    // file watcher follows it, and `themes/<theme>/components` is one of the
    // nine it names. A `display/` directory beside it would be invisible to the
    // watcher until somebody added a tenth.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/Reading.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()
    }
}
