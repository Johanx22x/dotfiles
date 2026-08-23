// BindRow, as the probe draws it: the chord as one line of text in the gutter
// the sheet measured, and the description after it.
//
// `caps` is hoisted to the top level rather than read inside a delegate. Rule
// 1's delegate limit: inside a Repeater, `row.anything` is exactly as unchecked
// as `property var row` would have made the whole file.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property BindRow row

    readonly property string chord: root.row.caps.map(cap => cap.text).join(" ")

    implicitHeight: 22
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"

    Text {
        id: chordText

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        width: root.row.gutterWidth
        text: root.chord
        color: "#00ffff"
        font: root.row.chipFont
    }

    Text {
        anchors.left: chordText.right
        anchors.leftMargin: root.row.gap
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        color: "#ffff00"
        font.family: Theme.fontFamily
    }
}
