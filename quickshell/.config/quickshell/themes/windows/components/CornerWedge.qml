// EMPTY, ON PURPOSE, AND FINISHED.
//
// A wedge is the concave fillet that fills the outside of a rounded corner
// where a panel meets a screen edge -- the little piece that makes the corner
// read as carved out of the surface rather than as a rectangle with its
// corners cut off. This theme has none of them to draw, and that is not a gap
// in it.
//
// WINDOWS ROUNDS WINDOWS, NOT THE SCREEN. `theme.json` sets
// `screenCornerRadius` to 0 and says so in as many words, `Theme.barCornerRadius`
// follows it, and the taskbar runs edge to edge and meets the bottom of the
// screen at ninety degrees. There is no arc anywhere for a fillet to sit
// outside of, so there is nothing here to paint. Drawing one would invent a
// corner Windows does not have.
//
// This is the component themes/genesis/components/README.md names under WHEN
// THE RIGHT IMPLEMENTATION IS EMPTY, and it passes both of that section's
// clauses: nothing has to come back across the seam, because
// components/CornerWedge.qml declares its own box (`radius` square) and never
// reads this Loader -- not the width and not the height either -- so the
// eleven wedges anchored against that box do not move; and everything the
// empty case still has to keep is the host's, because the four ScreenCorner
// windows go on being Top-layer surfaces with `ExclusionMode.Ignore` and an
// empty mask whatever their wedge draws.
//
// SO IT REPORTS NO SIZE AT ALL. Not `implicitWidth: 0` either -- there is
// nothing to say, and a zero written down looks like a measurement somebody
// took.
//
// AND IT STILL DECLARES `row`, WHICH IS THE PART THAT LOOKS LIKE A FORMALITY
// AND IS NOT. The facade hands the theme its `row` as an initial property of
// `setSource`, so an item that does not declare one is an assignment with no
// target: a bare `Item {}` here loads, lays out and draws the same nothing --
// and logs `Cannot assign to non-existent property "row"` fifteen times on
// every startup, once per wedge in the tree. Declaring it takes that to zero.

import QtQuick
import qs.components

Item {
    required property CornerWedge row
}
