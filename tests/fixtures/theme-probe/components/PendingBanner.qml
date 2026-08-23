// PendingBanner, as the probe draws it: the question with the seconds in it,
// and two boxes -- keep it, or put it back now.
//
// BOTH WAYS OUT ARE PRESENT, which is the one thing this component cannot be
// drawn without. The countdown reverts on its own, so a theme that drew only
// the question would still be safe; a theme that drew no "Keep" would make a
// change that CANNOT be kept, and one that drew no "Revert now" would make
// somebody sit out ten seconds they can already see are wrong.
//
// IT COUNTS NOTHING. `row.seconds` is a reading and the clock behind it is
// DisplayDraft's, deliberately outside the theme: a Timer in here would stop
// existing the moment somebody swapped the theme mid-countdown, on a screen
// that may be showing nothing at all.

import QtQuick
import qs
import qs.modules.settings.pages.display

Rectangle {
    id: root

    required property PendingBanner row

    implicitHeight: 24
    color: "#ffff00"
    border.width: 2
    border.color: "#000000"

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: keep.left
        anchors.verticalCenter: parent.verticalCenter

        text: `${root.row.question} Reverting in ${root.row.seconds}s`
        color: "#000000"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    Rectangle {
        id: keep

        anchors.right: revert.left
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter

        width: 36
        height: 18
        color: "#00ff00"

        MouseArea {
            anchors.fill: parent
            onClicked: root.row.kept()
        }
    }

    Rectangle {
        id: revert

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        width: 36
        height: 18
        color: "#ff0000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.row.reverted()
        }
    }
}
