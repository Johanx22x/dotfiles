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
// AND THE CURVE STOPS ONE PIXEL SHORT OF THE PAINTED ONE, ON PURPOSE. This is
// the paragraph the three panels point at, because the reason is the protocol's
// and applies to every curved blur boundary in the shell, not only to a fillet.
//
// A wl_region is a list of RECTANGLES. wl_region_add takes x, y, width and
// height and there is nothing else to give it: no alpha, no coverage, no
// antialiasing. So a curve handed to ext-background-effect is rasterised to
// whole pixels BY CONSTRUCTION, while the pixel painted over it is antialiased.
// Where the two disagree the compositor blurs a pixel the paint only half
// covers, and the half the paint did not cover shows the blurred backdrop at
// full strength -- a bright spike, on a curve, between pixels that are not
// spikes. That is the sawtooth, and it is not a rounding error to be tuned
// away: nothing in the protocol can express half a pixel.
//
// MEASURED, because the remedy depends on the size of the step. A probe with
// its own entry point declared this exact geometry over a flat magenta patch on
// DP-3 under niri 26.04, and grim captured it twice, with the region and
// without, so the difference between the frames is the blurred area to the
// pixel. With the fillet painted at 90% like the real one, the green channel at
// the antialiased pixel of each row down the curve read
//
//     flush      148 133 103 104  85 138  83 123 143 154
//     one in       1   6  20  20  28   6  30  12   5   1
//
// against 56 inside the fillet and 0 outside it. Flush, EVERY value on the
// boundary is brighter than the fillet's own interior, the worst by 98 levels
// out of 255. One pixel in, they are the monotone ramp an antialiased edge is
// supposed to be. The step is one pixel, which is what the protocol predicts;
// had it come out coarser the cause would have been Quickshell's rasteriser or
// the compositor's blur resolution and the answer would have been a different
// one.
//
// ONE PIXEL AND NOT TWO. Qt's antialiasing spans about a pixel, so one is
// already enough to put the whole region under paint that is opaque. On a
// 800x420 panel at cardRadius the leak over the four corners fell from 30.9
// pixels' worth to 0.20, and the worst single pixel from 83% uncovered to 6%.
// Two takes that remainder to zero and doubles what it costs, and it does cost:
// a pixel of the border stops being blurred, and these panels are glass, so it
// shows. Worst case, against the same magenta, that is 24 levels on a one pixel
// line lying against the panel's own edge -- a quarter of the spike it replaces,
// and in the same place, which is why the trade is worth making once and not
// twice.
//
// INWARD, NEVER OUTWARD, and for the fillet inward means GROWING THE CIRCLE,
// not shrinking the square: the transparent side of this shape is the inside of
// the bite. A region that grew instead would light up the empty side of the
// curve, which is the bug this whole component exists to prevent.
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

    // How far the blur retreats under the paint, in pixels. See the long note
    // above for the measurement that picked it; the same number is written at
    // the three panels that round their own corners, which have the same
    // problem for the same reason and no shared component to keep it in.
    readonly property int inset: 1

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
        //
        // GROWN BY THE INSET AROUND THAT SAME CENTRE -- the box loses the inset
        // at its top left and gains twice it in each dimension, so the centre
        // does not move and only the radius changes. That walks the curve a
        // pixel further into the fillet, which is the whole fix; the square's
        // own two straight edges are left alone because they are not where the
        // problem is. One of them abuts the panel or the bar and is interior to
        // the union, the other lies on a whole pixel, and a straight edge on a
        // whole pixel is rasterised exactly.
        x: root.x - (root.filledLeft ? 0 : root.side) - root.inset
        y: root.y - (root.filledTop ? 0 : root.side) - root.inset

        // Still shy of the filled corner, which sits side * sqrt(2) away: a
        // radius of side + 1 reaches it only once the side is down to about
        // 2.4px, and the smallest fillet in the shell is barCornerRadius.
        width: root.side * 2 + root.inset * 2
        height: root.side * 2 + root.inset * 2
    }
}
