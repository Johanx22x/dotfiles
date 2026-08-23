// ONE ENTRY IN THE NAVIGATION RAIL.
//
// THE SELECTED PILL'S FILL IS IDENTICAL TO ITS HOVER FILL, and that one
// sentence is most of what makes this read as Windows. Selection is carried by
// the 3x16 accent bar at the left edge and by nothing else; a selected entry
// with a backplate of its own is a state Windows does not have. Read it off
// ref/settings-personalization-taskbar.jpg, which is a 1:1 shot: the pill under
// "Personalization" and the pill under the pointer are the same brush, and the
// only difference between them is three pixels of accent.
//
// NO MouseArea IN HERE. The host keeps one, because it needs `preventStealing`
// on it and that is a property of an object the facade cannot require of a
// theme -- modules/settings/SettingsNavItem.qml has the whole of that story.
// What crosses instead is `row.hovered`, which is why this file can draw three
// tones without owning the pointer.
//
// THE HEIGHT IS 38 AND THE PILL IS 36. Windows puts NavigationViewItems on a
// 40 pitch with a 36 pill, so there are four pixels between two pills; the rail
// the host builds is a Column at spacing 2, so this item gives up one pixel top
// and bottom and the pitch comes out at 40 with the four in the middle. The
// same arithmetic the cards do, for the same reason.

import QtQuick
import qs
import qs.modules.settings
import qs.themes.windows

Item {
    id: root

    required property SettingsNavItem row

    implicitHeight: Fluent.navItemHeight + 2 * Fluent.cardGapInset

    Rectangle {
        id: pill

        anchors.fill: parent
        anchors.topMargin: Fluent.cardGapInset
        anchors.bottomMargin: Fluent.cardGapInset

        radius: Fluent.controlRadius

        // Three tones and two brushes. No Behavior: Windows swaps this on a
        // discrete keyframe at time zero, and a fade here is the tell that
        // gives a recreation away faster than a wrong colour does.
        color: root.row.selected || root.row.hovered ? Fluent.fillSubtleHover : "transparent"

        // The indicator, flush with the pill's left edge and centred on it.
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.indicatorWidth
            height: Fluent.indicatorHeight
            radius: Fluent.indicatorRadius

            visible: root.row.selected
            color: Theme.primary
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: (Fluent.navIconColumn - Fluent.navIcon) / 2
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.navIcon
            horizontalAlignment: Text.AlignHCenter

            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSmallSize
            color: Theme.textOnSurface
        }

        // The label keeps its weight when the entry is selected. A
        // NavigationViewItem does not go semibold under selection -- checked
        // against both rail photographs, where the selected label and the ones
        // above it are the same face.
        Text {
            anchors.left: parent.left
            anchors.leftMargin: Fluent.navLabelLeft
            anchors.right: parent.right
            anchors.rightMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            text: root.row.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }
    }
}
