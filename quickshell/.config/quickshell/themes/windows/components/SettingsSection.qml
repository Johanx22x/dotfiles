// How genesis draws a settings section: a heading line with an optional chip
// on its right, and a card under it holding the rows. The public half -- the
// forty-nine call sites, the default property, and the long note on why the
// column of rows stayed on the host side -- is
// modules/settings/SettingsSection.qml.
//
// THIS FILE PLACES AN OBJECT IT DOES NOT OWN. `slot` below has
// `data: [root.row.rows]`, and appending the facade's Column to this item's
// own data list is what moves it into the card. The direction is the ordinary
// one -- this file writes to its own item and reads the facade -- and the
// column's anchors are bound to `parent`, so they re-evaluate against the slot
// the moment it arrives. components/SearchField.qml in this directory does the
// same thing with a TextInput and its header is the account of the mechanism.
//
// A THEME THAT LEAVES THAT LINE OUT still loads, still draws a heading and a
// card, and has the section's rows lying across the whole width of the facade
// with the card behind them empty. There is no property the facade could have
// made `required` to prevent it: the slot is an item, not a value.
//
// THE HEADING SITS OUTSIDE THE CARD, and that is the promise this file
// inherited from the component it was split out of. Inside, it would be the
// first row of a list of rows and would have to be styled hard enough not to
// be read as one; outside, the indent alone does the work and the card stays a
// list of like things.
//
// THE MARGIN AROUND THE SLOT IS WHAT KEEPS A HOVERED ROW'S PILL OFF THE CARD'S
// ROUNDED CORNER. It is four pixels against a corner of Theme.cardRadius; a
// theme with a rounder card needs more. The column inside centres itself in
// whatever it is given and keeps its own row spacing, so the margin is the
// whole of what this file has to say about where the rows sit.

import QtQuick
import qs
// SettingsSection is modules/settings/SettingsSection.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings

Column {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property SettingsSection row

    spacing: Theme.itemSpacing

    // ---------------- The heading line ----------------
    //
    // One item so that the words and the chip share a line and the taller of
    // the two decides how tall it is. The chip's height is read even when it
    // is not shown, which is deliberate: a section that grows an action must
    // not grow a heading line as well.
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
                visible: root.row.glyph !== ""
                text: root.row.glyph
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
                text: root.row.title
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

            visible: root.row.actionText !== "" || root.row.actionGlyph !== ""
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
                    visible: root.row.actionGlyph !== ""
                    text: root.row.actionGlyph
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize - 2
                    color: actionMouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.row.actionText !== ""
                    text: root.row.actionText
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 2
                    font.weight: Theme.fontWeight
                    color: actionMouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }
            }

            // The chip asks the facade; it does not act. Rule 4: a theme reads
            // `row` and emits through it, and has no idea what the page wired
            // this to.
            MouseArea {
                id: actionMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.row.actionTriggered()
            }
        }
    }

    // ---------------- The card ----------------
    Rectangle {
        width: root.width
        implicitHeight: root.row.rows.implicitHeight + Theme.itemSpacing * 2

        radius: Theme.cardRadius
        color: Theme.surfaceContainer

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        // Where the rows go. An empty item whose only job is to have a
        // position and an inset; the line that matters is `data`, and the top
        // of this file has the account of it.
        Item {
            anchors.fill: parent
            anchors.margins: 4

            data: [root.row.rows]
        }
    }
}
