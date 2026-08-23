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
// THE RAIL'S TWO NUMBERS ARE PUBLISHED HERE AND COME FROM THE THEME'S TOKENS
// ---------------------------------------------------------------------------
//
// `railWidth` and `railPadding` were literals in Settings.qml, then literals
// here, and are now `Theme.railWidth` and `Theme.railPadding` -- two more of
// the design tokens in themes/<theme>/theme.json, with genesis's 210 and 10 as
// the fallbacks written at the site in Theme.qml. What did NOT change is which
// file the window reads them off: they are still declared on this facade, still
// readonly, and every reader in Settings.qml still says `chrome.railWidth`.
// Only where the number comes from moved.
//
// THAT IS DELIBERATE AND IT IS THE WHOLE SHAPE OF THE CHANGE. Six things in
// Settings.qml are anchored against these -- the rail's own width, the user
// block, the search field, the rail list, the channel the rail's scrollbar
// lives in, and the left edge of both content panes. Pointing all six at
// `Theme.railWidth` directly would scatter one dependency across six files and
// would leave nothing at all in front of it; the facade is where the window
// asks what its own rail is, and it stays that.
//
// THIS HEADER USED TO CLAIM THE OPPOSITE -- "SO A THEME CANNOT WIDEN THE RAIL
// TODAY, and that is a trade and not an oversight" -- and the claim is kept
// because the argument under it was good and the facts moved. It said the two
// numbers were on THIS side rather than read back off the Loader, which is the
// opposite of what rule 2 in themes/genesis/components/README.md does with a
// height, for the reason CornerWedge gives for its box:
//
//   - a theme that reported nothing would collapse all six anchors;
//   - the three pixels between the rail's entries and its scrollbar are a bug
//     that was fixed once already -- at padding 10 and a bar 4 wide the entries
//     stop at x=199 and the bar answers from 200, which is what
//     tests/scrollbar-target.py asserts -- and a theme that could move the
//     padding could put the bar's press target back over the entries;
//   - SettingsNavItem elides its label against the width that comes down from
//     here, so the rail's proportions are not a thing one file can change
//     alone.
//
// EVERY ONE OF THOSE THREE IS STILL TRUE, and none of them was ever an argument
// against a token. They are an argument against READING THE NUMBER BACK OFF THE
// DRAWING, which is what "a theme that reported nothing" means: a facade sized
// by whatever the theme's Item happened to measure. A token is the other
// direction entirely -- the theme states a number up front, in JSON, before
// anything is built, and a theme that states nothing gets 210 and 10 rather
// than zero. The collapse the old header was avoiding cannot happen through
// this channel.
//
// WHAT MOVED THE FACTS was a second theme. Windows 11 ships `NavigationView`
// with `OpenPaneLength = 320.0` and its Settings app does not override it, so a
// 210px rail is the single most visible deviation a Windows theme has -- and it
// is not one drawing can close, because the label column, the icon gutter and
// the selection-pill inset all derive from that number. The old header said the
// day one needs to widen the rail these become "a floored read off the Loader";
// that day came and the answer is better than the one it predicted, because a
// token needs no floor.
//
// WHAT THE OLD HEADER DEFERRED IS STILL DEFERRED: the scrollbar's own bench.
// tests/scrollbar-target.py builds its rail from its own literals -- 210 wide,
// entries 10 to 199, bar at 203 -- so it asserts the three pixels at genesis's
// numbers and only there. A theme that sets railPadding below the bar's four
// pixels has no channel left and nothing in this repository would say so. That
// is the work still outstanding, and it is now reachable rather than
// hypothetical.

import QtQuick
// For Theme, which is where the two numbers below now come from. `qs.modules`
// is still here for Themes, which the Loader at the bottom uses.
import qs
import qs.modules

Item {
    id: root

    // How wide the navigation rail is, and how much padding it insets its
    // contents by. Read by the window to lay itself out and by the theme to
    // draw the tint over the same rectangle -- and read BY THIS FACADE off the
    // theme's tokens, which is the header's subject.
    readonly property int railWidth: Theme.railWidth
    readonly property int railPadding: Theme.railPadding

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
