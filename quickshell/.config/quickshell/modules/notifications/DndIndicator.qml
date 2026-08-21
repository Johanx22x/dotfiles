// "Nothing is going to reach you right now."
//
// The other half of do-not-disturb, and the half that makes it safe to have
// at all: a mute you cannot see is a trap. The switch in the dashboard is
// behind a click and a tab; this is the part that is true on screen for as
// long as the mute is.
//
// It borrows the capture badge's grammar wholesale -- collapsed to nothing
// when it does not apply, a pill beside the island when it does, and the
// label revealed on hover rather than costing width all day. The two sit on
// opposite sides of the island on purpose: one is a thing being done TO this
// desktop, the other a thing this desktop was told to do.
//
// TINTED WITH THE ACCENT, NOT WITH CRITICAL. The capture badge is red because
// something is watching you and you may not know it. This is a mode you chose,
// so it reads as a state and not as a fault -- while still being the one
// coloured thing on that side of the bar.
//
// CLICKING IT OPENS THE HISTORY, and unmuting moved to the right button.
//
// It was the other way round while there was nothing to read: the badge said
// "you are muted", and the only useful thing to do about that was to stop
// being muted. Once the number next to the bell became four actual messages,
// the question the badge provokes changed -- "which four?" -- and a click that
// answered "they are gone now" instead was answering something nobody asked.
//
// Unmuting did not need the primary button anyway: it has SUPER + N, which is
// how it is switched on in the first place, and a switch in the dashboard.
// This is the only way to the list.

import QtQuick
import "root:/"
import "root:/modules/island"

Item {
    id: root

    // WHETHER THIS BADGE IS THE ONE SHOWING THE UNREAD COUNT.
    //
    // It used to be, unconditionally, and it was the right place for it while
    // it was the only thing on the bar that knew the number existed. The bell
    // at the right end of the bar shows it now -- on the door you pay the debt
    // through, which is where a count belongs -- so the two of them on screen
    // together would be one bar saying one thing twice.
    //
    // Set by Bar.qml, which is the only file that can see both, and it is
    // FALSE rather than absent when the bell is switched off on that bar: the
    // number then comes back here. See the note at the DndIndicator in Bar.qml.
    property bool showCount: false

    // Collapses to nothing when off, so the bar has no hole in it. The width
    // animates rather than the visibility flipping: the badge grows out of the
    // island's left edge instead of appearing beside it.
    implicitWidth: NotificationState.dnd ? pill.implicitWidth : 0
    implicitHeight: Theme.groupHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }
    }

    clip: true

    HoverHandler {
        id: hover
    }

    Rectangle {
        id: pill

        // Anchored to the RIGHT, which is the edge that touches the island.
        // That is what makes the badge unfold leftwards out of it: the side
        // nearest the island stays put and the rest is revealed.
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: content.implicitWidth + 22
        implicitHeight: Theme.groupHeight
        radius: Theme.groupRadius

        color: Qt.alpha(Theme.primary, hover.hovered ? 0.26 : 0.18)

        opacity: NotificationState.dnd ? 1 : 0

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        Row {
            id: content

            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.bellOff
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.primary
            }

            // The count is NOT hidden behind the hover, unlike the label.
            //
            // "You are muted" and "you have missed four things" are two
            // different pieces of news, and only the first one is implied by
            // the glyph. A number that only appears when you go looking for it
            // is a number you find out about too late.
            //
            // Drawn here only when nothing else is drawing it -- see showCount
            // above. The argument in the paragraph before this one is why the
            // number has to be SOMEWHERE, not why it has to be here.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showCount && NotificationState.unread > 0
                text: `${NotificationState.unread}`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: Theme.textOnSurface
            }

            // A SLOT that widens, not a label that appears -- see the same
            // construction in island/CaptureIndicator.qml. A Text given an
            // explicit width narrower than its content elides rather than
            // being revealed, so the clipping Item is what animates and the
            // text slides out from behind the glyph at its natural size.
            //
            // `visible` follows the width because a Row does not lay out
            // invisible children: without it the Row's spacing would leave a
            // gap on the left at rest.
            Item {
                anchors.verticalCenter: parent.verticalCenter

                clip: true
                width: hover.hovered ? label.implicitWidth : 0
                height: label.implicitHeight
                visible: width > 0

                Behavior on width {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }

                Text {
                    id: label

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    // Says what a click does, not what the state is: the glyph
                    // already said the state, and the pointer is on top of the
                    // badge by the time this is legible. When something has
                    // been missed it names that instead -- the list is worth
                    // opening for a reason, and the reason is the number.
                    text: NotificationState.unread > 0 ? "See what you missed" : "Notifications"

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    font.weight: Font.Bold
                    color: Theme.textOnSurface

                    opacity: hover.hovered ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDuration }
                    }
                }
            }
        }

        // Right click unmutes. It is not discoverable and does not need to be:
        // the mute has a key and a switch, and this is a shortcut for the one
        // case where you are already pointing at the thing -- the same reason
        // the island takes a right click as play/pause.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    NotificationState.setDnd(false);
                else
                    IslandState.openDashboard("Notifications");
            }
        }
    }
}
