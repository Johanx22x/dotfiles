// The blur region of one CornerWedge.
//
// components/CornerWedge.qml draws a square with a quarter circle carved out of
// one corner, and that shape is what welds a panel to the bar. Whatever asks
// for blur behind it has to ask for the SAME shape: request the whole square
// and the transparent side of the curve gets blurred too.
//
// That is not a hypothetical. A niri layer-rule blurs the entire surface
// rectangle and niri has no ignore-alpha to trim it with, so matching the
// launcher's namespace lit up the whole strip the fillets live in -- two
// round-cornered bands, one down each side of the panel, appearing the moment
// the launcher opened. This component is what makes the question go away
// instead of being answered per compositor: the surface names the region it
// actually paints, and nothing outside it is touched.
//
// HOW THE SHAPE IS BUILT, and it is the same construction CornerWedge itself
// uses: the square, minus a CIRCLE centred on the corner DIAGONALLY OPPOSITE
// the one that stays filled. The circle's radius is the square's whole side, so
// the quarter of it that overlaps is precisely the bite the wedge takes.
//
// COORDINATES ARE SURFACE-LOCAL AND ABSOLUTE. A nested Region is NOT placed
// relative to the one containing it: x and y are measured from the top left of
// the window. Verified on screen rather than assumed -- two disjoint bands
// asked for at fixed coordinates came out at those coordinates, with the gap
// between them left sharp.
//
// WHICH IS WHY THE WEDGE HAS TO BE A DIRECT CHILD OF ITS WINDOW, so that its
// own x and y are already in that same origin. Every CornerWedge in this shell
// is (the bar's two, the launcher's two, a popout's two, the notification
// panel's one), and they have to be: they sit outside the panel they weld so
// the panel's own rounding does not clip them. mapToItem would not need the
// assumption and is not used, because it is a function call rather than a
// property -- the binding would never re-run when a popout animates its width
// and slides its fillets along with it.
//
// A WEDGE THAT IS NOT DRAWN CONTRIBUTES NOTHING. The launcher, the popouts and
// the notification panel all drop their fillets when there is no bar to weld to
// -- see barVisible in any of them -- and a region left behind by a shape
// nobody is painting is a lit square hanging in mid air.

import Quickshell
import QtQuick

Region {
    id: root

    // The CornerWedge this region belongs to. Its `radius` is the side of the
    // square and its `corner` says which corner stays filled, so the two
    // shapes cannot drift apart by being given the numbers twice.
    property CornerWedge wedge: null

    // Zero side, and therefore an empty region, when the wedge is not drawn.
    readonly property int side: (root.wedge?.visible ?? false) ? (root.wedge?.radius ?? 0) : 0

    // The filled corners, in the spelling CornerWedge uses. Read once here so
    // the two offsets below say what they mean rather than repeating a string
    // comparison each.
    readonly property bool filledLeft: (root.wedge?.corner ?? "") === "topLeft"
        || (root.wedge?.corner ?? "") === "bottomLeft"
    readonly property bool filledTop: (root.wedge?.corner ?? "") === "topLeft"
        || (root.wedge?.corner ?? "") === "topRight"

    x: root.wedge?.x ?? 0
    y: root.wedge?.y ?? 0
    width: root.side
    height: root.side

    intersection: Intersection.Combine

    // The bite. Nested inside this region rather than beside it, which is what
    // keeps it from reaching any further: a child's own children are resolved
    // first and only the result is combined into the parent, so this circle
    // cannot eat into the panel it is welding even where it overlaps it.
    // Checked on screen the same way as the coordinates above.
    Region {
        shape: RegionShape.Ellipse
        intersection: Intersection.Subtract

        // Centred on the corner diagonally opposite the filled one: the
        // bounding box starts at the wedge where that corner is the box's own
        // top left, and one side earlier where it is not.
        x: root.x - (root.filledLeft ? 0 : root.side)
        y: root.y - (root.filledTop ? 0 : root.side)

        width: root.side * 2
        height: root.side * 2
    }
}
