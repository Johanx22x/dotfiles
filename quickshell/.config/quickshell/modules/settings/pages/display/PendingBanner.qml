// The countdown that replaces the actions row while a change is waiting to be
// confirmed: a question, the seconds left, and the two ways out. THIS IS THE
// HALF THE CARD SEES; the pixels are in
// themes/<theme>/components/PendingBanner.qml.
//
// WHY NOT ConfirmButton. That one arms on the first click and acts on the
// second, so the dangerous thing happens only if you confirm it -- which is the
// right shape for Reset and the wrong shape here. The dangerous thing has
// ALREADY happened by the time this appears: the mode is live, and what the
// click buys is permission to keep it -- and, since keep() writes, permission
// to write it down. Silence has to undo, not do nothing. Its countdown is also
// a border draining away with no number on it, and the number is the one thing
// worth reading when you are waiting to find out whether the screen comes back.
//
// ---------------------------------------------------------------------------
// THE TIMER IS NOT IN HERE AND IT IS NOT IN THE THEME
// ---------------------------------------------------------------------------
//
// `seconds` below is a reading. What counts it down lives in DisplayDraft.qml,
// bound to the pending state and NOT to anything's `visible`, with nineteen
// lines saying why: the whole point of a revert is that it fires whether or not
// anybody is still looking at this page, and the case it exists for is the one
// where the screen went black and the page cannot be looked at.
//
// A Timer inside a theme file is a Timer that stops existing when the theme is
// swapped. tests/shell-load.sh rewrites `theme` under a running shell and the
// surfaces are rebuilt in place; do that mid-countdown with the clock behind
// the seam and the ten seconds simply never end -- on a screen that may be
// showing nothing. So this component draws a number somebody else is counting,
// and both of its signals are requests.
//
// ---------------------------------------------------------------------------
// IT IS USED ONCE AND THE SECOND SITE IS FLAGGED RATHER THAN CONVERTED
// ---------------------------------------------------------------------------
//
// ArrangementSection.qml has the same banner written a second time, in the same
// grammar, down to the glyph and the two chips. It is NOT built from this
// component and the difference is the container, not the contents:
//
//   MonitorCard      a framed amber rectangle of its own, Theme.groupHeight
//                    tall, inset four pixels from the card's edge, shown
//                    INSTEAD of the actions row -- two sibling items, one
//                    visible at a time.
//   ArrangementSection   no frame and no fill at all. One 44-pixel Item holds
//                    both states at once: the countdown's Row and the actions'
//                    Row are children of the same box, each with its own
//                    `visible`, and the Keep/Revert chips share a Row with
//                    Reset and Apply.
//
// Folding the second one in would either put an amber frame around the
// arrangement's countdown or take the frame off the card's, and give one of the
// two a different height -- genesis pixels, on a page whose split is supposed
// to move none. That is a design decision and it is Johan's, not a refactor's.
// It is written down here, and again in ArrangementSection.qml over the row it
// is about, so that whoever wants one banner knows what it costs before they
// start.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    // The sentence, up to and including its question mark. The countdown is
    // added after it by the theme, because "Reverting in 7s" is the same
    // sentence at both call sites and only the question changes.
    //
    // NOT `label`: modules/settings/SettingsSearch.qml duck-types a row as
    // anything with a non-empty string `label` and would index this banner as
    // a setting. See rule 3 in themes/genesis/components/README.md.
    property string question: ""

    // How many are left, counted by whoever owns the revert. See the header.
    property int seconds: 0

    signal kept
    signal reverted

    // See the note in ToggleRow: the parent supplies the width, and binding
    // implicitWidth to it instead would be a loop.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320

    // THE THEME DRIVES THE HEIGHT, WITH A FLOOR UNDER IT, and the floor is what
    // this banner was before the split. A theme that wrapped the question above
    // the chips reports a bigger one and the card grows to fit. See
    // components/ToggleRow.qml for the two ways a theme reports nothing.
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // THE INSET IS THE THEME'S. This item spans the card, and the four pixels
    // the amber frame is pulled in by are drawn by the theme rather than taken
    // out of this width -- the same move SettingsSection makes with the margin
    // around its slot, and for the same reason: a theme with a different corner
    // radius needs a different inset, and there is nothing else here that
    // wants to know about it.
    //
    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md. The theme's file is under
    // components/ even though this one is not, for the reason Reading.qml gives
    // beside its own Loader.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/PendingBanner.qml")

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
