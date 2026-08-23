// WINDOWS ROUNDS WINDOWS, NOT THE SCREEN, SO THERE IS NOTHING HERE TO DRAW.
// The public half -- the three properties, and why the BOX is the host's while
// the curve is not -- is components/CornerWedge.qml.
//
// THIS FILE IS NOT UNFINISHED. It is the answer, and it is the one component in
// the interface for which an empty implementation is explicitly legitimate --
// see WHEN THE RIGHT IMPLEMENTATION IS EMPTY in
// themes/genesis/components/README.md, which this component is the reason for.
// Do not "fix" it by drawing something.
//
// WHY IT IS EMPTY HERE AND NOT MERELY UNUSED. This theme's theme.json says
//
//     "_corners": "0 because Windows rounds WINDOWS, not the screen."
//     "screenCornerRadius": 0
//
// and Theme.qml:542 makes the bar's fillets the same number:
//
//     readonly property int barCornerRadius: root.screenCornerRadius
//
// So every one of the eleven wedges in this shell -- the bar's two, the
// launcher's two, the popout's two, the notification panel's one and the four
// screen corners -- is handed `radius: 0` under this theme. A concave fillet of
// zero radius has no area. There is no shape here that a curve could be drawn
// into, and a bar that meets the screen edge at ninety degrees is what Windows
// looks like: the taskbar is a full-width strip and its corners are square.
//
// WHY IT IS SAFE TO REPORT NOTHING, WHICH IS THE PART THAT IS NOT SAFE BY
// DEFAULT. An empty Item reports an implicit size of 0, and eleven wedges are
// placed by ANCHORS against their box. The box is not this file's:
//
//     // See the header: the host's, and never read back off the Loader.
//     implicitWidth: root.radius
//     implicitHeight: root.radius
//         -- components/CornerWedge.qml:47-49
//
// and that facade's Loader is never read for a size -- it is named only inside
// build(). Grepping every facade under components/ and modules/settings/ for
// `drawing.implicit` returns thirty-odd hits and this component is not among
// them; MonitorTile is the only other one missing, and its header says so for
// its own reasons. Checked rather than assumed. So a wedge is
// `radius` square whatever this file does, the anchors against it land where
// they always did, and nothing downstream moves.
//
// AND IT STILL DECLARES `row`. That is rule 1 and it has no exception for the
// empty case: the facade hands its `row` over as an initial property of
// setSource, so an Item that does not declare one is an assignment with no
// target. Measured on the real shell under headless labwc, a bare `Item {}`
// here loads, lays out and logs
//
//     Cannot assign to non-existent property "row"
//
// fifteen times per startup, once per wedge in the tree. These five lines take
// that to zero and move nothing else.
//
// AND IT IS NOT THE SAME AS SHIPPING NO FILE AT ALL. There is no per-file
// fallback under components/, so a theme missing this file gets a Loader in
// Loader.Error and one Quickshell warning per wedge naming the path -- the same
// pixels, and a log that says somebody made a mistake. An Item that declares
// `row` and draws nothing is how a theme says it meant it.

import QtQuick
import qs.components

Item {
    required property CornerWedge row
}
