// What has been through here, newest first.
//
// The dashboard's Notifications tab. It exists because of the mute: a switch
// that drops notifications and leaves only a number behind is a switch that
// loses things, and this is where the number turns back into the messages.
//
// It is NOT a second notification panel. The one top right is for the thing
// that just happened and is about to go away on its own; this is the record,
// and the difference shows in what each one can do. Nothing here is clickable
// and no actions are offered: an action is a call back into the sending
// application about a notification it has already closed, so the buttons would
// be there to fail. What is left is reading, and clearing.
//
// OPENING IT IS WHAT MARKS THE COUNT READ. The badge on the bar is a debt --
// "four went by while you were not listening" -- and looking is what pays it.
// The entries stay; only the number goes.

import Quickshell
import QtQuick
import "root:/"

Item {
    id: root

    // Paid off the moment the tab is actually on screen, and not on
    // Component.onCompleted: every tab of the dashboard is built when the
    // panel opens, whichever one is showing, so construction says nothing
    // about having been looked at.
    onVisibleChanged: if (visible)
        NotificationState.markRead()

    Component.onCompleted: if (visible)
        NotificationState.markRead()

    // Relative times have to be recomputed or they freeze at whatever they
    // said when the panel opened. Minutes, because that is the smallest step
    // the labels below draw.
    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Milliseconds to something worth reading.
    //
    // Deliberately coarse. This is a catch-up list, so "17:42" answers the
    // only question anyone asks of an entry more than an hour old, and the
    // exact minute of something that happened four hours ago is noise.
    function ago(time: real): string {
        // Referenced so this re-evaluates on every tick rather than only when
        // the list changes.
        clock.date;

        const seconds = Math.floor((Date.now() - time) / 1000);
        if (seconds < 60)
            return "now";
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return `${minutes} min ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 6)
            return `${hours} h ago`;
        return Qt.formatDateTime(new Date(time), "HH:mm");
    }

    // ---------------- Header ----------------
    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            // Says what the list IS when there is nothing unusual about it,
            // and what the mute did when there is. The second reading is the
            // one that matters: landing here from the badge, the first thing
            // to confirm is that the missing notifications are in fact here.
            text: {
                const total = NotificationState.history.length;
                if (total === 0)
                    return "Nothing yet";
                const muted = NotificationState.history.filter(entry => entry.silenced).length;
                if (muted === 0)
                    return `${total} notification${total === 1 ? "" : "s"}`;
                return `${total} notification${total === 1 ? "" : "s"} · ${muted} arrived muted`;
            }

            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: Theme.textOnSurfaceVariant
        }

        Rectangle {
            id: clearButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: NotificationState.history.length > 0

            implicitWidth: clearLabel.implicitWidth + 24
            implicitHeight: 26
            radius: height / 2
            color: clearMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

            border.width: 1
            border.color: Theme.outlineVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Text {
                id: clearLabel

                anchors.centerIn: parent
                text: "Clear"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                font.weight: Theme.fontWeight
                color: Theme.textOnSurfaceVariant
            }

            MouseArea {
                id: clearMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationState.clearHistory()
            }
        }
    }

    // ---------------- The list ----------------
    Text {
        anchors.centerIn: parent
        visible: NotificationState.history.length === 0

        // Not "empty". The list being empty is the good outcome, and an empty
        // state that reads like a failure makes it look like something went
        // wrong.
        text: "Nothing to catch up on"

        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.textOnSurfaceVariant
    }

    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        // The gutter the scrollbar lives in. Reserved ALWAYS, not only while
        // the list overflows: taking it back when the last entry is cleared
        // would re-lay out every remaining row sideways, which is a lot of
        // movement to pay for eleven pixels.
        anchors.rightMargin: scrollTrack.width + 8
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom

        clip: true
        spacing: 8

        // StopAtBounds and not the default overshoot. The bounce is a touch
        // idiom -- it exists so a finger gets told it has hit the end -- and
        // on a wheel it just makes the list wobble past its own last row.
        // The scrollbar is what says "this is the end" here.
        boundsBehavior: Flickable.StopAtBounds

        model: NotificationState.history

        delegate: Rectangle {
            id: entry

            required property var modelData

            width: ListView.view.width
            height: entryLayout.implicitHeight + 24

            radius: Theme.cardRadius - 10
            color: Theme.surfaceContainerHigh

            // Same treatment the live card uses: an outline rather than a
            // different fill, so a critical entry is marked without the row
            // fighting the palette.
            border.width: entry.modelData.critical ? 1 : 0
            border.color: Theme.critical

            Item {
                id: entryLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 12

                implicitHeight: Math.max(icon.height, text.implicitHeight)

                Rectangle {
                    id: icon

                    anchors.left: parent.left
                    anchors.top: parent.top

                    width: Theme.notificationIconSize - 6
                    height: width
                    radius: height / 2
                    color: Theme.surfaceContainerHighest

                    Image {
                        id: iconImage

                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: parent.height - 8

                        // The sender's own picture if it is still there, the
                        // themed application icon otherwise. See the note on
                        // `image` in NotificationState.record: the first of
                        // the two can outlive its notification by less than
                        // the history does.
                        source: Icons.resolve(entry.modelData.image) || Icons.resolve(entry.modelData.appIcon)
                        visible: status === Image.Ready
                        sourceSize.width: width
                        sourceSize.height: height
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !iconImage.visible
                        text: Icons.bell
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.iconSize
                        color: Theme.textOnSurfaceVariant
                    }
                }

                Column {
                    id: text

                    anchors.left: icon.right
                    anchors.leftMargin: Theme.itemSpacing
                    anchors.right: parent.right
                    anchors.top: parent.top

                    spacing: 2

                    Item {
                        width: parent.width
                        height: title.implicitHeight

                        Text {
                            id: title

                            anchors.left: parent.left
                            anchors.right: stamp.left
                            anchors.rightMargin: Theme.itemSpacing

                            text: entry.modelData.summary || entry.modelData.appName
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            font.weight: Font.Bold
                            color: Theme.textOnSurface
                        }

                        Row {
                            id: stamp

                            anchors.right: parent.right
                            anchors.verticalCenter: title.verticalCenter
                            spacing: 5

                            // The mark that answers "was this one of the ones
                            // the mute ate". A glyph and not a colour: the row
                            // is already carrying a colour for critical, and
                            // two meanings on one channel is how you end up
                            // with neither being read.
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: entry.modelData.silenced
                                text: Icons.bellOff
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 1
                                color: Theme.primary
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.ago(entry.modelData.time)
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 1
                                color: Theme.outline
                            }
                        }
                    }

                    Text {
                        width: parent.width

                        // The application's name, which the live card only
                        // shows when there is no summary. Here it earns its
                        // place: a list of twenty entries from six senders is
                        // read by source first.
                        text: entry.modelData.appName
                        visible: text !== "" && text !== entry.modelData.summary
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 2
                        color: Theme.outline
                    }

                    Text {
                        width: parent.width

                        text: entry.modelData.body
                        visible: text !== ""
                        textFormat: Text.StyledText

                        // Two lines and then cut. One was not enough for the
                        // messages this is here to rescue -- a chat line runs
                        // past it -- and letting them run free would make a
                        // single verbose sender fill the panel.
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight

                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        color: Theme.textOnSurfaceVariant
                    }
                }
            }
        }
    }

    // ---------------- Scrollbar ----------------
    //
    // Hand-drawn, for the same reason the volume slider is: a Controls
    // ScrollBar arrives with its own style and putting it back into this
    // palette is more code than two rectangles.
    //
    // IT ANSWERS TWO QUESTIONS, and the list could not answer either on its
    // own. "Is there more below" -- a row cut off by the bottom edge looks the
    // same as a row that happens to end there. And "how far down am I" -- with
    // twenty entries of similar shape, scrolling with no landmark feels like
    // the list is going nowhere.
    //
    // It disappears when everything fits: a scrollbar that is always full
    // height is a control that says nothing and takes up room saying it.
    Rectangle {
        id: scrollTrack

        anchors.right: parent.right
        anchors.top: list.top
        anchors.bottom: list.bottom

        width: 4
        radius: width / 2

        visible: list.contentHeight > list.height

        color: Qt.alpha(Theme.outlineVariant, 0.5)

        Rectangle {
            id: thumb

            // As tall a share of the track as the visible part is of the
            // whole, with a floor: proportional alone means fifty entries
            // leave a four-pixel dot, which is a position indicator you have
            // to hunt for.
            height: Math.max(30, scrollTrack.height * list.visibleArea.heightRatio)

            // The floor is also why the position is not simply
            // `yPosition * track.height`: once the thumb is taller than its
            // share, it has less room to travel than the content does, so the
            // scroll position is mapped onto the travel that is actually left.
            // Without that the bar reaches the bottom before the list does.
            y: {
                const travel = scrollTrack.height - thumb.height;
                const range = 1 - list.visibleArea.heightRatio;
                if (travel <= 0 || range <= 0)
                    return 0;
                const progress = Math.max(0, Math.min(1, list.visibleArea.yPosition / range));
                return progress * travel;
            }

            width: parent.width
            radius: parent.radius

            // Brighter while it is being used -- moved, dragged or pointed at
            // -- and quiet the rest of the time. At rest this is a hint about
            // the shape of the list; in the hand it is a control, and the two
            // should not look the same.
            //
            // Both `moving` and the velocity are asked, because they do not
            // cover the same gestures: `moving` is a drag or a flick, and a
            // wheel notch on a desktop is neither -- it moves the view without
            // ever putting the Flickable into that state.
            color: list.moving || list.verticalVelocity !== 0 || scrollMouse.pressed || scrollMouse.containsMouse
                ? Theme.primary
                : Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        // The target is far wider than the bar it drives. Four pixels is the
        // right width to LOOK at and an unfair thing to ask anyone to hit, so
        // the pointer gets eighteen and the drawing keeps its four.
        //
        // WIDER ONLY, never taller. Growing it vertically as well would move
        // this item's origin above the track, and `mouse.y` is measured from
        // that origin -- so every position below would be off by the overhang
        // and the thumb would sit seven pixels from where it was grabbed.
        MouseArea {
            id: scrollMouse

            anchors.fill: parent
            anchors.leftMargin: -7
            anchors.rightMargin: -7

            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // Press jumps and drag follows, which is what the volume slider
            // does and for the same reason: one gesture, and no dead zone on
            // the track where nothing happens.
            //
            // The pointer is treated as the MIDDLE of the thumb, so what you
            // pressed on ends up under your finger rather than starting there
            // and sliding down by half a thumb.
            function scrollTo(y: real): void {
                const travel = scrollTrack.height - thumb.height;
                if (travel <= 0)
                    return;
                const progress = Math.max(0, Math.min(1, (y - thumb.height / 2) / travel));
                list.contentY = progress * (list.contentHeight - list.height);
            }

            onPressed: mouse => scrollMouse.scrollTo(mouse.y)
            onPositionChanged: mouse => {
                if (pressed)
                    scrollMouse.scrollTo(mouse.y);
            }
        }
    }
}
