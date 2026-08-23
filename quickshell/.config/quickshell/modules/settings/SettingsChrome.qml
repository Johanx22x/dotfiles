// The settings window's own two surfaces: the glass the whole window sits on,
// and the tint down the navigation rail. THIS IS THE HALF THE WINDOW SEES;
// both rectangles are in themes/<theme>/components/SettingsChrome.qml.
//
// IT IS THE FIRST CHILD OF THE WINDOW AND IT DRAWS NOTHING ELSE. Everything
// the window puts on top of it -- the user block, the search field, the rail,
// the header, the pages -- is still Settings.qml's, in the order that file
// declares them. The two rectangles this replaces were the first thing painted
// and the first child of the rail respectively, which are the first two things
// painted in the whole window, so drawing them here in that order leaves the
// paint sequence exactly where it was.
//
// ---------------------------------------------------------------------------
// THE RAIL'S TWO NUMBERS ARE DECLARED HERE AND THE THEME ONLY READS THEM
// ---------------------------------------------------------------------------
//
// `railWidth` and `railPadding` were literals in Settings.qml. They are here
// because the theme needs the first of them to know how wide to draw the tint,
// and putting the number in two files is how the tint and the rail stop
// agreeing. They are on THIS side rather than read back off the Loader, which
// is the opposite of what rule 2 in themes/genesis/components/README.md does
// with a height, and the reason is the one CornerWedge gives for its box:
//
//   - Six things in Settings.qml are anchored against them -- the rail's own
//     width, the user block, the search field, the rail list, the channel the
//     rail's scrollbar lives in, and the left edge of both content panes. A
//     theme that reported nothing would collapse all six.
//   - The three pixels between the rail's entries and its scrollbar are the
//     whole of a bug that was fixed once already: at padding 10 and a bar 4
//     wide the entries stop at x=199 and the bar answers from 200, which is
//     what tests/scrollbar-target.py asserts. A theme that could move the
//     padding could put the bar's press target back over the entries.
//   - SettingsNavItem elides its label against the width that comes down from
//     here, so the rail's proportions are not a thing one file can change
//     alone.
//
// SO A THEME CANNOT WIDEN THE RAIL TODAY, and that is a trade and not an
// oversight. The day one needs to, these become a floored read off the Loader
// the way a row's height already is -- and that day the scrollbar's own bench
// needs a second set of numbers, which is the work this defers rather than
// avoids.

import QtQuick
import qs.modules

Item {
    id: root

    // How wide the navigation rail is, and how much padding it insets its
    // contents by. Read by the window to lay itself out and by the theme to
    // draw the tint over the same rectangle.
    readonly property int railWidth: 210
    readonly property int railPadding: 10

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    //
    // NOTHING IS READ BACK OFF IT. This item is anchors.fill'ed by the window,
    // so it has no size of its own to report and no height for the window to
    // floor -- see the header for the rest of that.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/SettingsChrome.qml")

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
