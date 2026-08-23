// How genesis draws one notification. The public half -- the timeout per
// urgency, the two values the spec reserves, the clock, and the difference
// between dismissing a notification and letting it expire -- is
// components/NotificationCard.qml, and none of that is drawing.
//
// Collapsed it is two lines: who sent it and when, then the body cut to a
// single line. The chevron expands it in place to the full body plus the
// actions the sender offered -- the card grows, the stack below slides down,
// and nothing opens a second window.
//
// THE WHOLE CARD IS THE TARGET, which is a promise the facade cannot require
// and this file has to keep. A click anywhere that is not the chevron and not
// an action button dismisses the notification; there is no close button and
// there never was one. The MouseArea at the foot of this file is how, and it
// is declared last on purpose. See rule 7 in README.md in this directory.
//
// AND IT IS `row.dismiss()` AND NOT `row.notification.expire()`. Both would
// take the card off the screen and they say opposite things to the sender --
// dismissing tells the application the user closed it deliberately, which is
// what lets apps like Discord stop re-sending the same thing. The facade owns
// that distinction and exposes the one of the two a click means; a theme that
// reached past it to the notification would be answering a question about the
// protocol that it was not asked.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `NotificationCard` here is the facade
    // and not this file.
    required property NotificationCard row

    // HOISTED, because the Repeater at the bottom is a delegate and rule 1's
    // checking stops at its edge -- `row.notification.actions` read from inside
    // it would be exactly as unchecked as `property var row` would have made
    // the whole file. Read once here, where the type is real, and the delegate
    // binds to a local name. LevelMeter.qml in this directory does the same
    // thing and says so in the same words.
    readonly property var actions: root.row.notification.actions

    implicitHeight: layout.implicitHeight + Theme.groupPadding * 2

    // A box on the panel, not a window of its own: a step up the surface
    // ladder from the panel behind it, and opaque -- the panel already
    // carries the transparency for both.
    radius: Theme.notificationRadius
    color: Theme.surfaceContainer

    // Critical notifications get an outline instead of a different fill:
    // recolouring the whole card would fight the palette, an edge does not.
    border.width: root.row.critical ? 1 : 0
    border.color: Theme.critical

    // THE GROWTH IS MOTION AND MOTION IS THIS SIDE'S, unlike Popout's two
    // Behaviors, which are on its facade because a window's input mask and its
    // size reservation both have to follow the same geometry. Nothing on the
    // other side of this seam reads the card's height except the Column that
    // stacks the cards, and it is happy to be told a moving number: the facade
    // follows this implicitHeight through its Loader and the stack slides.
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
    }

    Column {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.groupPadding

        spacing: 6

        // ---------------- Header ----------------
        Item {
            width: parent.width
            height: Math.max(icon.height, header.implicitHeight)

            // The sender's icon: its own image if it sent one, otherwise the
            // application icon from the desktop entry.
            Rectangle {
                id: icon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                width: Theme.notificationIconSize
                height: Theme.notificationIconSize
                radius: height / 2
                color: Theme.surfaceContainerHigh

                Image {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    height: parent.height - 8

                    source: Icons.resolve(root.row.notification.image || root.row.notification.appIcon)
                    visible: status === Image.Ready
                    sourceSize.width: width
                    sourceSize.height: height
                }

                Text {
                    anchors.centerIn: parent
                    // Nothing to show: the bell stands in, so the card never
                    // has a hole where the icon goes.
                    visible: !root.row.notification.image && !root.row.notification.appIcon
                    text: Icons.bell
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: Theme.textOnSurfaceVariant
                }
            }

            Column {
                id: header

                anchors.left: icon.right
                anchors.leftMargin: Theme.itemSpacing
                anchors.right: chevron.left
                anchors.rightMargin: Theme.itemSpacing
                anchors.verticalCenter: parent.verticalCenter

                spacing: 2

                Row {
                    spacing: 6

                    Text {
                        text: root.row.notification.summary || root.row.notification.appName
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: Font.Bold
                        color: Theme.textOnSurface
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, header.width - 60)
                    }

                    Text {
                        text: "•"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        color: Theme.outline
                    }

                    Text {
                        text: "now"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        color: Theme.textOnSurfaceVariant
                    }
                }

                Text {
                    width: header.width
                    text: root.row.notification.body
                    textFormat: Text.StyledText

                    // Collapsed: one line, cut. Expanded: as many as it needs.
                    maximumLineCount: root.row.expanded ? 0 : 1
                    wrapMode: root.row.expanded ? Text.Wrap : Text.NoWrap
                    elide: root.row.expanded ? Text.ElideNone : Text.ElideRight

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    color: Theme.textOnSurfaceVariant
                }
            }

            // Expand / collapse. The card's own state lives on the facade
            // because the clock is bound to it, so this asks rather than
            // assigns -- rule 4.
            Text {
                id: chevron

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: "⌄"
                rotation: root.row.expanded ? 180 : 0
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.textOnSurfaceVariant

                Behavior on rotation {
                    NumberAnimation { duration: Theme.animDuration }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.row.toggleExpanded()
                }
            }
        }

        // ---------------- Actions ----------------
        // Only while expanded: collapsed cards stay two lines tall whatever
        // the sender attached to them.
        Row {
            visible: root.row.expanded && root.actions.length > 0
            spacing: Theme.itemSpacing

            Repeater {
                model: root.actions

                Rectangle {
                    required property var modelData

                    implicitWidth: actionLabel.implicitWidth + Theme.groupPadding * 2
                    implicitHeight: Theme.groupHeight
                    radius: Theme.groupRadius
                    color: actionMouse.containsMouse ? Theme.primary : Theme.surfaceContainerHigh

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Text {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: parent.modelData.text
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: Theme.fontWeight
                        color: actionMouse.containsMouse ? Theme.textOnPrimary : Theme.textOnSurface
                    }

                    MouseArea {
                        id: actionMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.modelData.invoke()
                    }
                }
            }
        }
    }

    // Click anywhere else on the card to dismiss. Declared last so the
    // chevron and the action buttons win the click where they overlap.
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.row.dismiss()
    }
}
