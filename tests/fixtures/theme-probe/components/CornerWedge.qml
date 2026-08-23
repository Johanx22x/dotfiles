// CornerWedge, as the probe draws it: NOT AT ALL, and that is the point of
// this file rather than an omission.
//
// The probe has square screen corners and a bar that meets the screen edge at
// ninety degrees, so there is no concave fillet to carve out of anything. The
// section "WHEN THE RIGHT IMPLEMENTATION IS EMPTY" in
// themes/genesis/components/README.md is written about exactly this case, and
// this is the first caller it has ever had.
//
// IT STILL DECLARES `row`, WHICH IS THE WHOLE REASON THE FIXTURE SHIPS THIS
// FILE. The facade hands the theme its `row` as an initial property of
// setSource, so an item that does not declare one is an assignment with no
// target: a bare `Item {}` here loads, lays out, draws nothing -- and logs
// `Cannot assign to non-existent property "row"` once per wedge in the tree,
// fifteen times per startup on the measurement in that README. That string is
// not one tests/shell-load.sh matches, so the only thing standing between the
// corrected form and the old one is that this file is loaded by a check at
// all.
//
// Nothing crosses the seam upwards from here and nothing has to: the wedge's
// box is `radius` square and is declared on the FACADE, so a theme that draws
// no wedge moves none of the eleven things anchored against one.

import QtQuick
import qs.components

Item {
    required property CornerWedge row
}
