// What has been through here, newest first.
//
// What the bell at the right end of the bar opens into -- it was a tab of the
// island's dashboard until it earned a widget of its own, and the only thing
// that changed for this file was the size it is given. It exists because of
// the mute: a switch that drops notifications and leaves only a number behind
// is a switch that loses things, and this is where the number turns back into
// the messages.
//
// It is NOT a second notification panel. The one top right is for the thing
// that just happened and is about to go away on its own; this is the record,
// and the difference shows in what each one can do. Nothing here is clickable
// and no actions are offered: an action is a call back into the sending
// application about a notification it has already closed, so the buttons would
// be there to fail. What is left is reading, and clearing.
//
// OPENING IT IS WHAT MARKS THE COUNT READ. The number on the bell is a debt --
// "four went by while you were not listening" -- and looking is what pays it.
// The entries stay; only the number goes.
//
// Paid off on `visible`, which still holds now that this is a popout rather
// than one tab of four: the popout builds its content when it opens and
// destroys it when it closes, so being constructed here does mean being looked
// at. The check costs nothing and keeps the file honest about why.
//
// THE MUTE IS IN THE HEADER, and this is where it belongs rather than where it
// was. It spent its life as a row in the island's dashboard, filed with the
// brightness and the volume because it was a thing you switch; but a panel
// that lists notifications and cannot silence them is the odd arrangement, and
// the dashboard is about this DESKTOP while the mute is about this LIST. The
// header already says what the mute did -- "3 arrived muted" -- so cause and
// effect are now one line apart instead of one panel apart.

import Quickshell
import QtQuick
import "root:/"
import "root:/components"

Item {
    id: root

    // Paid off the moment this is actually on screen, and not on
    // Component.onCompleted alone: that mattered while every tab of the
    // dashboard was built when the panel opened, whichever one was showing, so
    // construction said nothing about having been looked at. It is kept
    // because nothing about this file assumes which surface is holding it.
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

        // 30, which is the 26 the buttons are plus two either side. It was
        // the same before the mute joined them; what changed is that the
        // number now has two things depending on it.
        height: 30

        Text {
            anchors.left: parent.left
            // Stops at the controls rather than running under them: the mute
            // added a second button to this row, and "12 notifications · 3
            // arrived muted" is the longest string the header can hold.
            anchors.right: controls.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            elide: Text.ElideRight

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

        // TWO CONTROLS ON THE RIGHT, and they are deliberately not the same
        // shape of thing. Clear is an ACTION -- it happens once and there is
        // nothing left of it -- so it stays an outline you press. The mute is
        // a MODE that is either on or off, so it fills with the accent while
        // it is on and is an outline like Clear while it is not. Filled versus
        // outlined is the whole of the state, which is why the label never
        // changes: a toggle whose text flips between "Do not disturb" and
        // "Notifications on" leaves you working out whether the words are
        // describing the state or offering the action.
        Row {
            id: controls

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            spacing: 8

            Rectangle {
                id: dndButton

                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: dndContent.implicitWidth + 22
                implicitHeight: 26
                radius: height / 2

                // Filled while the mute is on. Off, it borrows Clear's
                // treatment exactly, hover included, so the two read as one
                // row of controls rather than as a button beside a widget.
                color: NotificationState.dnd
                    ? Theme.primary
                    : dndMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                border.width: NotificationState.dnd ? 0 : 1
                border.color: Theme.outlineVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                Row {
                    id: dndContent

                    anchors.centerIn: parent
                    spacing: 7

                    // THE SAME PAIR THE BELL DRAWS for the same state -- see
                    // modules/bar/NotificationButton.qml. The button on the
                    // bar and the switch in this panel are one setting, so
                    // they must not need to be read two ways.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        text: NotificationState.dnd ? Icons.bellOff : Icons.bell
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        color: NotificationState.dnd ? Theme.textOnPrimary : Theme.textOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        text: "Do not disturb"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        font.weight: Font.Bold
                        color: NotificationState.dnd ? Theme.textOnPrimary : Theme.textOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }
                    }
                }

                // NO COUNT CHIP, unlike the row this replaces. The dashboard's
                // switch carried "how many the mute has swallowed", and here
                // that number is provably always zero: being on screen is what
                // marks the count read (see the top of this file), so by the
                // time anyone can look at this button the debt is already
                // paid. A chip that can only ever say nothing is a chip that
                // should not be drawn.
                MouseArea {
                    id: dndMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationState.toggle()
                }
            }

            Rectangle {
                id: clearButton

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
        anchors.rightMargin: scrollBar.width + 8
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
    // components/ScrollBar.qml now, and it used to be a hundred lines of
    // rectangles right here. This was the first of them; the cheatsheet grew
    // the second and said in its own comment that a third is what should lift
    // it into components/. The third turned out to be every capped list in the
    // settings window at once.
    //
    // WHAT MOVED OUT AND WHAT STAYED. The drawing, the thumb's floor, the
    // remapped travel and the widened hit target are all the component's; the
    // placement is this file's, because what a bar can sit on top of is a
    // question only the thing underneath can answer. Here it sits in a gutter
    // the list gives up, which is the arrangement the note above the list
    // explains and the reason this one is anchored to the panel rather than
    // over the rows.
    ScrollBar {
        id: scrollBar

        view: list

        anchors.right: parent.right
        anchors.top: list.top
        anchors.bottom: list.bottom
    }
}
