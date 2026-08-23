// How genesis draws one entry in the settings window's navigation rail. The
// public half -- and the long note on why the MouseArea did NOT come down here
// with the drawing -- is modules/settings/SettingsNavItem.qml.
//
// THERE IS NO MOUSEAREA IN THIS FILE AND THERE MUST NOT BE ONE. The facade
// keeps the hit target, because its `preventStealing: true` is the whole of a
// bug reported as "Updates does not open" and a theme that drew its own target
// would have to remember to set a flag it has no reason to know about. So this
// file draws the three tones and asks the facade which one to use: `hovered`
// is a property on the other side, written by the one MouseArea there is.
//
// SELECTED STATE IS A FILLED PILL, not an accent bar or bold text: the rail
// sits on the same glass as the content beside it, and a mark that only colours
// the label is easy to lose over a wallpaper. The pill also matches what the
// rest of this shell already does to say "this one" -- the active workspace on
// the bar is the same shape.
//
// SELECTED AND HOVERED ARE DELIBERATELY DIFFERENT TONES rather than different
// intensities of one, so that hovering a selected entry does not read as having
// deselected it.
//
// THE LABEL ELIDES, and it elides against the rail's width rather than being
// allowed to push the glyph out of the pill: the rail has a fixed width, and a
// section added later should not be able to change the window's proportions.
// The width that arrives here comes down from SettingsChrome's `railWidth`
// through the rail, the list and the facade, so there is one number and this
// file is not one of the places it is written.

import QtQuick
import qs
// SettingsNavItem is modules/settings/SettingsNavItem.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property SettingsNavItem row

    // WHAT THE FACADE READS BACK. An entry of this theme is one row tall --
    // the facade floors at the same number, so this is what it was before the
    // split rather than a second opinion about it.
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius

    color: root.row.selected ? Theme.primaryContainer
        : root.row.hovered ? Theme.surfaceContainerHigh
        : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.row.selected ? Theme.textOnPrimaryContainer : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.row.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            // Elide rather than let a long name push the glyph out of the
            // pill; see the header for why the rail's width is not this file's
            // to argue with.
            width: parent.width - parent.spacing - Theme.iconSize * 1.6
            elide: Text.ElideRight
            color: root.row.selected ? Theme.textOnPrimaryContainer : Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }
}
