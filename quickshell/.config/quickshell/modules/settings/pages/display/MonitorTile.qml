// One screen on the arrangement map: a rectangle the size the monitor takes up
// on the desktop, with its connector written on it. THIS IS THE HALF
// ArrangementSection SEES; the pixels are in
// themes/<theme>/components/MonitorTile.qml.
//
// ---------------------------------------------------------------------------
// THE MouseArea IS NOT IN HERE AND IT IS NOT IN THE THEME EITHER
// ---------------------------------------------------------------------------
//
// It stays where it was, written into the map's delegate in
// ArrangementSection.qml, as a child of the tile. Three reasons, and the first
// one is the one that would have cost a day:
//
// THE DRAG IS THE PART THAT MUST NOT MOVE. That file says in advance that there
// is NO `drag.target`, because handing the rectangle to the dragger assigns
// straight to `x` and `y` and DESTROYS the bindings that draw it from the
// draft. The pointer is followed by hand instead: pressed records the grab in
// MAP coordinates, positionChanged converts a delta back into logical pixels,
// snaps it against every other monitor's edges, and writes the answer into the
// draft -- so the tile is always drawn from the model. Every line of that reads
// `map`, `root.snapPosition`, `root.setArranged` and `root.normaliseArrangement`,
// which are the section's, not this file's and not a theme's.
//
// A COMPOSITOR IS WRITTEN TO AT THE END OF IT. Everything on this page that
// reaches a compositor stays host-side; a theme decides what a screen looks
// like on a map and never where the screen goes.
//
// AND A THEME MUST NOT TAKE INPUT HERE. That is rule 7 of
// themes/genesis/components/README.md and it is this component's version of it:
// no MouseArea, no TapHandler, no DragHandler, no cursorShape. The one this
// tile has is the section's, it covers the whole tile, and it is the only thing
// on this page that can move a screen.
//
// ---------------------------------------------------------------------------
// IT REPORTS NOTHING BACK, WHICH IS THE OTHER HALF OF THE SHAPE
// ---------------------------------------------------------------------------
//
// Rule 2 says a theme reports its `implicitHeight` and the facade floors it.
// This one does not, and it is the CornerWedge clause of README.md rather than
// an exception to rule 2: the box is the HOST's. `x`, `y`, `width` and `height`
// are computed by the map from the logical size, the zoom factor and the
// draft -- `Math.max(8, logical.w * map.factor)` and the two coordinate
// transforms -- and a theme that had a say in them could put a screen somewhere
// the arrangement does not think it is. A tile whose theme draws nothing at all
// is still exactly where the layout says, in the right size, and still drags.
//
// EVERY NUMBER BELOW IS A READING AND NONE OF THEM IS THE MODEL. The delegate
// hands over what it worked out; nothing here reaches into `modelData`, so a
// theme cannot read a monitor's mode, its saved override or its transform. What
// a screen looks like on the map is the four facts below and no others.

import QtQuick
import qs.modules

Item {
    id: root

    // The connector, as the compositor spells it: "DP-2", "HDMI-A-1". The one
    // string written on a tile.
    //
    // NOT `label`, WHICH WOULD BE A DIFFERENT THING ENTIRELY.
    // modules/settings/SettingsSearch.qml duck-types a row as anything with a
    // non-empty string `label` and indexes it, so calling this `label` would
    // put one search hit per monitor into an index of settings rows -- and
    // there is nothing here to open. See rule 3 in
    // themes/genesis/components/README.md.
    property string connector: ""

    // WHAT THE MONITOR TAKES UP ON THE DESKTOP, in logical pixels, and it is
    // not the mode: the mode divided by the scale, and turned on its side for
    // an odd transform. The map computes it -- see `logicalSize` in
    // ArrangementSection.qml, which has the account of why -- and hands the
    // answer over, because the number written on the tile has to be the number
    // the tile was drawn from.
    property real logicalWidth: 0
    property real logicalHeight: 0

    // This screen has the keyboard.
    property bool focused: false

    // It has been moved since the last apply, so it is part of what Apply is
    // about to send. Worked out by the delegate against the reading, not
    // against anything a theme could see.
    property bool moved: false

    // A PLAIN BOOL AND NOT THE MouseArea. The section's dragger is what knows
    // this; handing the object over instead would let a theme read `pressed`,
    // `mouseX` and `drag`, and would make the one thing this file is careful
    // about -- see the header -- reachable from a theme file.
    property bool dragging: false

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type. The theme's file
    // is under components/ even though this one is not, for the reason
    // Reading.qml gives beside its own Loader: that directory is the one
    // shell.qml imports for the file watcher.
    //
    // NOTHING READS THIS LOADER'S IMPLICIT SIZE, for the reason in the header.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/MonitorTile.qml")

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
