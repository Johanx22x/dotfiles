// How genesis carves a corner. The public half -- the three properties, and
// why the BOX is the host's while the curve is not -- is components/CornerWedge.qml.
//
// WHY IT IS A MASKED RECTANGLE AND NOT A Shape
// The obvious implementation is QtQuick.Shapes: two lines and an arc. It was
// written that way first, and the arc came out visibly jagged. Measured, the
// Shape's edge averaged 0.94 intermediate pixels per row against 5.25 for a
// Rectangle's rounded corner -- five times worse. Neither `layer.samples`
// (4x multisampling) nor a 4x supersampled layer texture fixed it; the second
// made it worse.
//
// So the curve is not drawn as a path at all. It is a plain square with a
// CIRCLE punched out of it, and that circle is a Rectangle with
// `radius: width / 2` -- exactly the case Qt's documentation says gets
// antialiased without multisampling. The subtraction is an inverted opacity
// mask.
//
// The geometry is written once for the top-left orientation and rotated into
// the other three. THE ROTATION IS ON THIS SIDE AND NOT ON THE FACADE, which
// is a fact about how this file happens to write its geometry rather than
// anything a caller asked for: a theme that drew all four orientations out
// longhand would need no rotation at all. It is equivalent here because the
// facade's box is square -- `radius` by `radius` -- and this item fills it, so
// rotating the inner item about its centre covers exactly what rotating the
// outer one did before the split.
//
// AND THIS IS THE ONE FILE IN THIS DIRECTORY THAT MAY BE EMPTY. A theme with
// square screen corners and no fillets implements it as `Item {}` and draws
// nothing: no floor is missed, no height is lost and no layout moves, because
// the facade keeps the box. See the null-implementation rule in README.md,
// which this component is the reason for.

import QtQuick
import QtQuick.Effects
import qs.components

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `CornerWedge` here is the facade and
    // not this file.
    required property CornerWedge row

    rotation: switch (root.row.corner) {
    case "topLeft":
        0;
        break;
    case "topRight":
        90;
        break;
    case "bottomRight":
        180;
        break;
    default:
        270;
    }

    // What we keep: the whole square.
    Rectangle {
        id: square

        anchors.fill: parent
        color: root.row.fillColor

        // Rendered into a texture for the effect below, never drawn directly.
        visible: false
        layer.enabled: true
    }

    // What we remove: a circle centred on the INNER corner of the square, so
    // the quarter of it that overlaps is the bite taken out of the shape.
    Item {
        id: hole

        anchors.fill: parent

        visible: false
        layer.enabled: true

        Rectangle {
            x: 0
            y: 0
            width: root.row.radius * 2
            height: root.row.radius * 2
            radius: width / 2

            // This is the antialiasing the whole component exists for.
            antialiasing: true

            // Only the alpha matters: the mask is read as coverage.
            color: "black"
        }
    }

    MultiEffect {
        anchors.fill: parent

        source: square
        maskEnabled: true
        maskSource: hole
        // Keep the source where the mask is EMPTY, i.e. everywhere the circle
        // is not.
        maskInverted: true

        // WITHOUT THESE THE MASK IS A HARD THRESHOLD.
        // MultiEffect defaults to cutting the mask at a single value with no
        // spread, which throws away the very thing the circle was drawn for:
        // its antialiased edge. Measured, the thresholded version had ZERO
        // intermediate pixels along the curve -- worse than the Shape it
        // replaced. A threshold at the midpoint with full spread passes the
        // circle's own coverage through instead of rounding it to on/off.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
