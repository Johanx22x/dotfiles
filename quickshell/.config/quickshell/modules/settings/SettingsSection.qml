// A titled group of settings rows: a heading, then a card holding the rows.
//
// The heading sits OUTSIDE the card rather than inside it. Inside, it would
// be the first row of a list of rows and would have to be styled hard enough
// not to be read as one; outside, the indent alone does the work and the card
// stays a list of like things.

import QtQuick
import "root:/"

Column {
    id: root

    property string glyph: ""
    property string title: ""

    // Rows written between this component's braces land in the card below,
    // not next to the heading.
    default property alias content: rows.data

    // An optional action for the whole section, shown as a small chip at the
    // right end of the heading.
    //
    // IT IS THE HEADING'S AND NOT A ROW OF ITS OWN, which is the point. A
    // section-wide action put inside the card becomes a row that looks like a
    // setting and is not one, and two of those stacked above a grid is what
    // made the wallpaper page read as heavy: three horizontal bands of
    // furniture before any content. Up here it costs no vertical space at
    // all -- the heading line was already there with nothing on its right.
    property string actionText: ""
    property string actionGlyph: ""

    signal actionTriggered

    spacing: Theme.itemSpacing

    Item {
        width: root.width
        implicitHeight: Math.max(heading.implicitHeight, action.implicitHeight)

    Row {
        id: heading

        x: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            // The accent is the heading's, and it is the only place it is
            // spoken for in this window: the rows below stay neutral so the
            // eye finds the section breaks first.
            color: Theme.primary

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: Theme.primary

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    Rectangle {
        id: action

        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        visible: root.actionText !== "" || root.actionGlyph !== ""
        implicitWidth: actionRow.implicitWidth + Theme.groupPadding * 1.6
        implicitHeight: Theme.groupHeight - 12
        radius: height / 2

        color: actionMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
        border.width: 1
        border.color: Theme.outlineVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Row {
            id: actionRow

            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.actionGlyph !== ""
                text: root.actionGlyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize - 2
                color: actionMouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.actionText !== ""
                text: root.actionText
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 2
                font.weight: Theme.fontWeight
                color: actionMouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }
        }

        MouseArea {
            id: actionMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.actionTriggered()
        }
    }

    }

    Rectangle {
        width: root.width
        implicitHeight: rows.implicitHeight + Theme.itemSpacing * 2

        radius: Theme.cardRadius
        color: Theme.surfaceContainer

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        Column {
            id: rows

            // An explicit width, because the rows inside take theirs from
            // this column -- see the note at the top of ToggleRow.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // Enough to keep the pill of a hovered row off the rounded corner
            // of the card behind it.
            anchors.margins: 4
            spacing: 2

            // The same descending order SettingsPage puts on the sections, and
            // for the same reason: a tooltip hangs downwards out of its row
            // and has to cover the rows below it, which it cannot do from
            // inside one of them. See the long note in SettingsPage.qml.
            //
            // It matters more here than there, because rows arrive from
            // Repeaters as well as from the file -- which is why this is
            // hooked to the signal and not only to completion.
            onChildrenChanged: rows.restack()
            Component.onCompleted: rows.restack()

            function restack(): void {
                for (let i = 0; i < children.length; i++)
                    children[i].z = children.length - i;
            }
        }
    }
}
