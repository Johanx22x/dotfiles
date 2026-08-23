// How genesis draws a search box. The public half -- `text`, `clear()`, and
// the long note on why the TextInput stayed on the host side -- is
// components/SearchField.qml.
//
// THIS FILE PLACES AN OBJECT IT DOES NOT OWN, which is the one thing no other
// implementation in this directory does. `inputArea` below has
// `data: [root.row.input]`, and appending the facade's TextInput to this
// item's own data list is what moves it here. The direction is the ordinary
// one -- this file writes to its own item and reads the facade -- and the
// input's anchors are bound to `parent`, so they re-evaluate against this slot
// the moment it arrives.
//
// A THEME THAT LEAVES THAT LINE OUT still loads, still draws a pill, and has
// its text lying across the whole width underneath the glyph. There is no
// property the facade could have made `required` to prevent that: the slot is
// an item, not a value, and nothing on this side is obliged to declare one. It
// is rule 7 again -- a promise about behaviour that only the implementation
// can keep.
//
// THE SLOT IS AS TALL AS THE PILL AND THE TEXT IS NOT. The input centres
// itself inside whatever it is given and keeps its own height, so anchoring
// this slot top-to-bottom is what puts the text on the line it sat on before
// the split. Giving the slot a height of its own is how a theme would move it.
//
// AND THE CLICK TARGET IS THE WHOLE PILL, not the text. A field where only the
// glyph-to-clear strip answers a click is a field you have to aim at, and the
// pill is drawn the size it is precisely so you do not have to.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `SearchField` here is the facade and
    // not this file.
    required property SearchField row

    // WHAT THE FACADE READS BACK. A field of this theme is one line tall,
    // always -- the facade floors at the same number, so this is what it was
    // before the split rather than a second opinion about it.
    implicitHeight: Theme.groupHeight - 4

    radius: height / 2

    color: root.row.focused ? Theme.surfaceContainerHigh
        : mouse.containsMouse ? Qt.alpha(Theme.surfaceContainerHigh, 0.6)
        : Qt.alpha(Theme.surfaceContainerHigh, 0.35)

    border.width: 1
    border.color: root.row.focused ? Theme.primary : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.animDuration }
    }

    // THE WHOLE PILL TAKES THE CLICK, and take() is how it says so. That
    // function had no caller at all before the split -- see the facade -- and
    // this is now the only way a theme can put the keyboard into an input it
    // does not own.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: root.row.take()
    }

    Text {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        text: Icons.search
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: root.row.focused ? Theme.primary : Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // ---------------- Where the text goes ----------------
    //
    // An empty Item whose only job is to have a position. The line that
    // matters is `data`, and the top of this file has the account of it.
    Item {
        id: inputArea

        anchors.left: glyph.right
        anchors.leftMargin: Theme.itemSpacing
        anchors.right: clearButton.left
        anchors.rightMargin: 4
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        data: [root.row.input]
    }

    // Only there when it has something to do. A permanent clear button on an
    // empty field is a control that is disabled nine tenths of the time.
    Item {
        id: clearButton

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: root.height - 8
        implicitHeight: root.height - 8
        visible: root.row.text !== ""

        Text {
            anchors.centerIn: parent
            text: Icons.close
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize - 2
            color: clearMouse.containsMouse ? Theme.textOnSurface : Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        MouseArea {
            id: clearMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // CLEARED AND THEN GIVEN THE KEYBOARD BACK, both through the
            // facade. Pressing clear is not a way of leaving the field: the
            // next thing anyone does is type the search they meant.
            onClicked: {
                root.row.clear();
                root.row.take();
            }
        }
    }
}
