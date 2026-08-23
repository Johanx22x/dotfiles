// Reading, as the probe draws it: one flat rectangle with the label and the
// value on it, in that order, and no attempt at two columns.
//
// Rule 7, and this is the second component in here whose entire contract is an
// ABSENCE: there is nothing to click and it must not look as though there is.
// No MouseArea, no HoverHandler, no TapHandler, no cursorShape, and no colour
// that changes because a pointer is over it.
//
// `tone` IS READ AND NOTHING ELSE ABOUT IT IS KEPT. It is the card saying that
// one of these readings is singled out -- the monitor with the keyboard, the
// screen the shell lives on -- and a theme that ignored it would draw six
// identical lines where the card meant to point at one. This one paints the
// text in whatever colour arrives, which is the ugliest possible way of
// honouring it and still honours it.

import QtQuick
import qs
import qs.modules.settings.pages.display

Rectangle {
    id: root

    required property Reading row

    implicitHeight: 24
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"

    Text {
        anchors.fill: parent
        anchors.margins: 4
        verticalAlignment: Text.AlignVCenter

        text: `${root.row.label}: ${root.row.value}`
        color: root.row.tone
        font.family: Theme.fontFamily
        elide: Text.ElideMiddle
    }
}
