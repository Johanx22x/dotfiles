// ScrollBar, as the probe draws it: a cyan block on a black track.
//
// Rule 7, and it is an absence again: THERE IS NO MouseArea IN HERE. The
// press target is the facade's -- it is widened past the pixels the bar is
// drawn as, and twice that widening came out of something that wanted the
// press. A second grab in the theme half would be a second answer to the same
// click.
//
// implicitWidth is the width of the bar and implicitHeight is the SHORTEST the
// thumb may be: the facade reads it back as `thumbFloor` and computes
// `thumbHeight` from it. Both are constants for that reason -- deriving either
// from row.thumbHeight would close the loop.

import QtQuick
import qs.components

Rectangle {
    id: root

    required property ScrollBar row

    implicitWidth: 6
    implicitHeight: 16
    color: "#000000"

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right

        y: root.row.thumbY
        height: root.row.thumbHeight
        color: root.row.inUse ? "#00ff00" : "#00ffff"
    }
}
