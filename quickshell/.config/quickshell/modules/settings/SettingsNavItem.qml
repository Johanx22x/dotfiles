// One entry in the settings window's navigation rail. THIS IS THE HALF THE
// WINDOW SEES; the pill, the glyph and the label are in
// themes/<theme>/components/SettingsNavItem.qml.
//
// ---------------------------------------------------------------------------
// THE MOUSEAREA DID NOT MOVE, AND IT IS THE ONE THING IN HERE THAT COULD NOT
// ---------------------------------------------------------------------------
//
// Every other split in this shell hands the theme the hit target along with
// the drawing, because a theme that draws its own shape is the only thing that
// knows where the shape is. This one keeps it, for the twenty-five lines of
// reason written over `preventStealing` below: that flag is the whole of a bug
// that was reported as "Updates does not open", it applies to exactly the two
// entries below the fold, and a theme that wrote its own MouseArea and left it
// out would bring the bug back on a window that looks perfect. It is not
// something a facade can require -- `preventStealing` is a property of an
// object the theme would own -- so the object stays here.
//
// WHAT THE THEME GETS INSTEAD IS `hovered`. The pill has three tones and one
// of them is "the pointer is over this", so the theme has to be able to ask.
// It is `readonly` because there is exactly one writer and it is the MouseArea
// below.
//
// The rail gives the width; see the note at the top of ToggleRow. The height
// is floored at Theme.groupHeight -- what an entry was before the split -- and
// read off the Loader rather than off `Loader.item`, for the reason in
// ToggleRow's header. tests/wheel-and-click.py depends on that floor: it
// builds fourteen of these and asserts the rail is 530 tall.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    // `label` and `glyph` STAY ON THIS SIDE. modules/settings/SettingsSearch.qml
    // duck-types on both names by walking the live object tree, and although
    // its walk starts inside the pages and never reaches the rail, the names
    // are the interface's and a theme must not mirror them. See rule 3 in
    // themes/genesis/components/README.md.
    property string glyph: ""
    property string label: ""
    property bool selected: false

    signal clicked

    // Whether the pointer is over this entry, for the theme to draw with. The
    // MouseArea below is the only writer.
    readonly property bool hovered: mouse.containsMouse

    // The rail gives the width; see the note at the top of ToggleRow.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 150
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/SettingsNavItem.qml")

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

    // DECLARED AFTER THE LOADER, which is where it was before the split: the
    // drawing came first and this was the last child of the file. A MouseArea
    // paints nothing, so the order is about which item is asked first and not
    // about what is on top -- and the theme draws no hit target of its own, so
    // there is nothing above this to reach past.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true

        // THE RAIL IS INSIDE A LIST THAT CAN BE DRAGGED, and a Flickable that
        // is moving takes the next press away from whatever is under it, so
        // that the press carries on the gesture instead of landing on the row
        // that happened to slide there. That is right for a finger. Here it
        // means the first click after dragging the rail is thrown away, and
        // the only two entries anybody drags to are the two below the fold --
        // which is how a scrolling problem got reported as "Updates does not
        // open".
        //
        // preventStealing is the documented way to refuse that: it holds
        // keepMouseGrab from the moment it is set, and QQuickFlickable's
        // filter checks that flag before it ever consults its own moving
        // state. Measured on the rail at 0, 100, 300 and 600 ms after a drag
        // and after a flick: the click lands at all four, where before it
        // landed only at 600.
        //
        // WHAT IT COSTS is dragging the rail. A row that keeps its own grab
        // never hands it to the Flickable, so pulling the list by an entry no
        // longer scrolls it -- the wheel and the scrollbar beside it still
        // do, which is every way a mouse actually moves this list. NOT
        // `interactive: false` on the list itself, which looks like the same
        // trade and is not: that switch also turns off the Flickable's own
        // wheel handling, which is the net under ScrollList's handler, and
        // taking it away stopped the whole settings window scrolling.
        //
        // AND IT IS WHY THIS OBJECT IS ON THIS SIDE OF THE SEAM. See the
        // header.
        preventStealing: true

        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
