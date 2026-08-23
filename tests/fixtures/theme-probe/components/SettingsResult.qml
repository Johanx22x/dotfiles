// SettingsResult, as the probe draws it: the row's name on a magenta card with
// the trail that places it underneath, in a smaller ink.
//
// Rule 7: THE WHOLE CARD IS THE TARGET. A result you have to hit on the words
// is a result you have to aim at, and picking one is the only thing anybody
// does in this list.
//
// Rule 3: `label` and `glyph` are read off the facade and never mirrored. The
// settings search's walk cannot reach this pane -- it starts inside the pages
// and the results are a sibling of them -- so a mirrored name here would
// double nothing today. It is spelled the interface's way anyway, because the
// day somebody points a walk at this pane is not the day to find out that this
// one file was the exception.

import QtQuick
import qs
import qs.modules.settings

Rectangle {
    id: root

    required property SettingsResult row

    implicitHeight: 28
    color: "#ff00ff"

    Text {
        id: name

        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.top: parent.top

        text: `${root.row.glyph} ${root.row.label}`
        color: "#ffff00"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.top: name.bottom

        text: root.row.section !== "" && root.row.section !== root.row.pageTitle
            ? `${root.row.pageTitle} > ${root.row.section}`
            : root.row.pageTitle
        color: "#00ffff"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    // Rule 4: ask, never act. The window answers this by highlighting a row on
    // a page it is about to select, and this file does not know that.
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.row.clicked()
    }
}
