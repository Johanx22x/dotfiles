// A square with a quarter circle carved out of one of its corners. THIS IS THE
// HALF THE SHELL SEES; the curve is in themes/<theme>/components/CornerWedge.qml.
//
// This is the shape behind every concave edge in the shell:
//
//   - where the bar meets the sides of the screen, so it flows into them
//     instead of ending in a hard 90 degree step;
//   - where a popout or the notification panel hangs off the bar;
//   - and, on its own, the rounded corners of the screen itself.
//
// THERE IS ALMOST NOTHING LEFT ON THIS SIDE, and what is left is the BOX. The
// three properties below say which corner is filled, how big the wedge is and
// what colour it is; the curve, the mask and the antialiasing the component
// exists for are the theme's. A caller places a wedge; it does not draw one.
//
// THE IMPLICIT SIZE IS THE HOST'S AND DOES NOT COME BACK ACROSS THE SEAM,
// which is the opposite of what rule 2 in themes/genesis/components/README.md
// asks for everywhere else. The reason is this component's null case.
//
// A square-cornered theme draws NOTHING here -- its CornerWedge is `Item {}`,
// which is a legitimate implementation and the only one in the tree for which
// that is true. An empty Item reports an implicit size of 0. If this facade
// took its size from the theme, every fillet in the shell would collapse to a
// point the moment a theme declined to draw one: the bar's strip, the popout's
// two, the launcher's two and the notification panel's one are all placed by
// ANCHORS against a box this size, and a box of zero moves whatever is anchored
// to it. So the box is `radius` square and is decided here; what a theme
// chooses is whether anything is painted inside it.
//
// That is also what keeps the call sites' arithmetic readable: three of them
// name this item and read `radius`, `corner` and `visible` back off it rather
// than being told those numbers a second time.

import QtQuick
import qs.modules

Item {
    id: root

    // Which corner of the square stays filled:
    // "topLeft" | "topRight" | "bottomRight" | "bottomLeft"
    property string corner: "topLeft"
    property int radius: 16
    property color fillColor: "black"

    // See the header: the host's, and never read back off the Loader.
    implicitWidth: root.radius
    implicitHeight: root.radius

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/CornerWedge.qml")

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
