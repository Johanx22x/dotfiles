// ONE SCREEN ON THE ARRANGEMENT MAP.
//
// NO PHOTOGRAPH. The reference set has seven Settings shots and none of them
// is System > Display -- settings-system-display-hdr.jpg is the HDR sub-page,
// which the set's own index calls "the closest the set gets". So this is the
// one component in this share drawn without a picture of the thing it is, and
// it says so rather than quoting a metric that would sound measured. What it
// is built from instead is the grammar every Settings photograph agrees on:
// the control radius, a one-pixel stroke, a fill a shade lighter than what is
// behind it, and STATE CARRIED IN THE BRUSH RATHER THAN IN THE GEOMETRY --
// nothing in the set changes a border's width to say something, and several
// things change its colour.
//
// ---------------------------------------------------------------------------
// IT TAKES NO INPUT, AND THAT IS THE WHOLE OF RULE 7 HERE
// ---------------------------------------------------------------------------
//
// No MouseArea, no TapHandler, no DragHandler, no cursorShape. The drag that
// moves a screen belongs to the section: it follows the pointer BY HAND,
// because handing the rectangle to a dragger assigns straight to x and y and
// destroys the bindings that draw the tile from the draft. `row.dragging` is a
// plain bool for the same reason -- the section's MouseArea is deliberately
// not reachable from here. modules/settings/pages/display/MonitorTile.qml sets
// all of that out at length and this file is the half that has to keep it.
//
// IT REPORTS NOTHING BACK EITHER. No implicitWidth, no implicitHeight, no
// width, no height: x, y, width and height are a coordinate transform the map
// computes from the logical size, the zoom factor and the draft, and a theme
// with a say in them could put a screen where the arrangement does not think
// it is. This is the CornerWedge clause of themes/genesis/components/README.md
// rather than an exception to rule 2, and the facade's header is where it was
// decided.
//
// `connector` AND DELIBERATELY NOT `label`. SettingsSearch duck-types a row as
// anything carrying a non-empty string `label` and walks straight through the
// facade's Loader into this file, so a monitor named `label` anywhere in here
// would be one search hit per screen in an index of settings rows -- with
// nothing to open at the end of it. Rule 3.
//
// WHAT THE STATES LOOK LIKE, AND WHY EACH IS THAT WAY:
//
//   focused    the accent, on the stroke. It is the same thing the navigation
//              rail and the search list say with an accent bar: this is the
//              one you are on.
//   moved      Theme.warning, on the same stroke, and it WINS over focused
//              because it is the more perishable of the two. Amber is this
//              page's word for provisional -- the countdown banner is amber,
//              the overlap note is amber -- and a tile that has moved is
//              exactly part of what Apply is about to send.
//   dragging   the fill DIMS. Hover brightens and press dims in Windows, a
//              drag is a press that has not been let go of, and dimming is
//              what says the tile is in hand. There is no hover state at all
//              here, because there is no pointer for this file to ask.

import QtQuick
import qs
import qs.themes.windows
import qs.modules.settings.pages.display

Rectangle {
    id: root

    required property MonitorTile row

    radius: Fluent.controlRadius
    color: root.row.dragging ? Fluent.fillPress : Theme.surfaceContainerHighest

    border.width: 1
    border.color: root.row.moved
        ? Theme.warning
        : root.row.focused ? Theme.primary : Theme.outlineVariant

    // No Behavior on either. Windows swaps a brush on a discrete keyframe at
    // time zero, and a tile that faded while it was being dragged would be
    // lagging the pointer by however long the fade was.

    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    Column {
        anchors.centerIn: parent

        width: parent.width - 2 * Fluent.textLeading
        spacing: 0

        // A MAP TILE CAN BE EIGHT PIXELS. The section floors both of its
        // dimensions there, which is smaller than one line of text, so both
        // lines ask whether they fit before they draw. A clipped glyph across
        // the middle of a tile reads as damage; nothing reads as a small
        // screen, which is what it is.
        //
        // AGAINST Fluent.captionLine AND NOT AGAINST THE COLUMN'S OWN HEIGHT,
        // which is the shape that closes a loop: a Column sizes itself to the
        // children that are visible, so a child whose `visible` reads the
        // Column is deciding its own input.
        Text {
            width: parent.width
            visible: root.height >= Fluent.captionLine + 2 * Fluent.textLeading

            text: root.row.connector
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.strongWeight
            color: root.row.focused ? Theme.primary : Theme.textOnSurface
        }

        // The size it takes up on the desktop, in logical pixels, which is the
        // number the tile itself was drawn from -- not the mode. Rounded
        // because a scaled monitor's logical width is rarely an integer and a
        // map tile is not the place to read four decimal places.
        Text {
            width: parent.width
            visible: root.height >= 2 * Fluent.captionLine + 2 * Fluent.textLeading

            text: `${Math.round(root.row.logicalWidth)} × ${Math.round(root.row.logicalHeight)}`
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurfaceVariant
        }
    }
}
