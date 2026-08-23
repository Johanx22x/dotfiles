// How genesis draws one search result in the settings window: a card with the
// row's own name over the trail that places it, and the row's glyph beside
// them when it has one. The public half is
// modules/settings/SettingsResult.qml.
//
// THE WHOLE CARD IS THE TARGET. A result you have to hit on the words is a
// result you have to aim at, and the list is a list of answers -- picking one
// is the only thing anybody does here.
//
// THE TRAIL IS WHAT PLACES A ROW WITH A GENERIC NAME: "Default timeout" alone
// could be three things. It is dropped when the section repeats the page's own
// title, because "Notifications › Notifications" says the same word twice and
// places nothing.
//
// THE GLYPH IS OPTIONAL AND ITS SPACE GOES WITH IT. A row that has none starts
// its text where the glyph would have started, rather than leaving a column of
// air down the left of the list -- most rows in this shell have no glyph, so
// the empty column would be the usual case.

import QtQuick
import qs
// SettingsResult is modules/settings/SettingsResult.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property SettingsResult row

    // WHAT THE FACADE READS BACK. A result of this theme is one row plus eight
    // -- the facade floors at the same number, so this is what it was before
    // the split rather than a second opinion about it.
    implicitHeight: Theme.groupHeight + 8

    radius: Theme.cardRadius

    color: resultMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Text {
        id: resultGlyph

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.glyph
        visible: text !== ""
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: Theme.textOnSurfaceVariant
    }

    Column {
        anchors.left: resultGlyph.visible ? resultGlyph.right : parent.left
        anchors.leftMargin: resultGlyph.visible ? Theme.itemSpacing : Theme.groupPadding
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.row.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: Theme.textOnSurface
        }

        // The trail, so a row with a generic name is placed: "Default timeout"
        // alone could be three things.
        Text {
            width: parent.width
            text: root.row.section !== "" && root.row.section !== root.row.pageTitle
                ? `${root.row.pageTitle} › ${root.row.section}`
                : root.row.pageTitle
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 3
            color: Theme.textOnSurfaceVariant
        }
    }

    // The card asks the facade; it does not act. Rule 4: a theme reads `row`
    // and emits through it, and has no idea that the window answers this by
    // highlighting a row on a page it is about to select.
    MouseArea {
        id: resultMouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.row.clicked()
    }
}
