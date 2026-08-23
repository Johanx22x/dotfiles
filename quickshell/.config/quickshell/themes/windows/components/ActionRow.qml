// How genesis draws a reading with something to press. The public half -- what
// the pages write, why this is not a clickable InfoRow, and why `actionEnabled`
// is a second property rather than a use of `enabled` -- is
// components/ActionRow.qml, and this file is everything that was below those
// comments before the split, moved unchanged.
//
// THE BUTTON IS THE TARGET AND IT LOOKS LIKE ONE, which is the promise this
// file keeps and the facade cannot require. There is exactly one MouseArea in
// here and it is inside the pill on the right; nothing else in the row hovers,
// changes colour or takes a cursor. Put a MouseArea across the row and this
// becomes an InfoRow that answers to a click, which is precisely the thing
// components/InfoRow.qml exists to promise never happens. See rule 7 in
// README.md.
//
// AND THE WORD IS THE BUTTON. `row.actionText` is always drawn;
// `row.actionGlyph` is optional and goes before it. A theme that dropped the
// word when a glyph was set would be inventing an icon language the call sites
// never agreed to -- the facade's header says why a pencil, a folder and an
// ellipsis are not one.
//
// TWO SWITCHES, READ IN TWO PLACES, WHICH IS THE FIDDLY PART OF THIS FILE.
// `root.enabled` is Qt's effective-enabled coming down the tree from the page,
// and it means the whole row is out of play. `row.actionEnabled` is the
// facade's own property and it means the action is busy: it dims and deadens
// THE PILL ONLY, so the label and the description stay at full contrast while
// something runs. They are deliberately not multiplied together anywhere -- the
// opacity below is the pill's alone, and the MouseArea takes `actionEnabled`
// because a MouseArea does not follow the tree while event delivery to a
// disabled ancestor's children stops anyway. Rule 6 in README.md is where that
// was measured.
//
// The description wraps rather than eliding, and the row grows to fit it. That
// growth is what implicitHeight below reports back to the facade.

import QtQuick
import qs
import qs.components

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `ActionRow` here is the facade and not
    // this file.
    required property ActionRow row

    // WHAT THE FACADE READS BACK, and like InfoRow's it is not a constant:
    // `column` is as tall as the description wraps to and nothing on the host
    // side can know that. The facade floors this at Theme.groupHeight, which is
    // the same floor the Math.max here applies -- stated twice because the two
    // are answering different questions. Here it is "a reading is at least as
    // tall as a row"; there it is "a theme that reported nothing does not
    // collapse the page".
    implicitHeight: Math.max(Theme.groupHeight, column.implicitHeight + 14)

    Text {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.top: column.top
        anchors.topMargin: 1

        visible: root.row.glyph !== ""
        text: root.row.glyph
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    Column {
        id: column

        anchors.left: mark.right
        anchors.leftMargin: Theme.itemSpacing
        anchors.right: action.left
        anchors.rightMargin: Theme.itemSpacing
        anchors.verticalCenter: parent.verticalCenter

        spacing: 3

        Text {
            width: parent.width
            visible: root.row.label !== ""
            text: root.row.label
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            width: parent.width
            visible: root.row.description !== ""
            text: root.row.description
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

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

        implicitWidth: actionRow.implicitWidth + Theme.groupPadding * 2
        implicitHeight: Theme.groupHeight - 8
        radius: height / 2

        color: !root.row.actionEnabled ? "transparent"
            : actionMouse.containsMouse ? Theme.surfaceContainerHigh
            : "transparent"

        border.width: 1
        border.color: Theme.outlineVariant

        // The pill's own dim, and only the pill's. See the header: this is
        // `actionEnabled` and not `enabled`, and the sentence beside it must
        // stay readable while whatever it started is running.
        opacity: root.row.actionEnabled ? 1 : 0.4

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Row {
            id: actionRow

            anchors.centerIn: parent
            spacing: Theme.itemSpacing - 3

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.row.actionGlyph !== ""
                text: root.row.actionGlyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize - 1
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.row.actionText
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                font.weight: Theme.fontWeight
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        // THE ONLY MouseArea IN THIS FILE, and it is inside the pill. See the
        // header for why putting one across the row would break InfoRow's
        // promise as well as this one's.
        MouseArea {
            id: actionMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.row.actionEnabled
            onClicked: root.row.triggered()
        }
    }
}
