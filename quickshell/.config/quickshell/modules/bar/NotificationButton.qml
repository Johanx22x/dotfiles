// The door into the notification history, at the right end of the bar.
//
// It used to be a tab of the island's dashboard: the only ways in were the
// panel in the middle of the bar plus a click on "Notifications", or the
// do-not-disturb badge, which only exists while the mute is on. Two of the
// dashboard's other tabs answer questions about this machine and one is about
// what is playing, so "what did I miss" was filed with them for no better
// reason than that it needed somewhere to live. It has its own place now, and
// the panel comes out from under the thing you pressed.
//
// WHY THIS END OF THE BAR. It shares the pill with the settings and the power
// buttons, and that pill is for the shell's own controls rather than for
// readings -- which is exactly what this is. It opens something belonging to
// the shell; it does not report on the machine. It goes FIRST inside that
// pill so the power button keeps its place at the very end with nothing new
// beside it, which is what PowerButton.qml has asked for since it moved there.
//
// THE COUNT IS A DEBT, and it is the same number the do-not-disturb badge used
// to carry -- see NotificationState.unread. Only the mute ever creates one, so
// most of the time this is a plain glyph and nothing else; when there is a
// number, the glyph and the number take the accent so the debt is legible
// without a second background inside a pill that already has one. The badge
// beside the island gives the number up for as long as this widget is drawn
// and takes it back when it is not, so exactly one thing on the bar is ever
// saying it. See DndIndicator.showCount.
//
// IT DOES NOT SHOW THE MUTE. A bell that crossed itself out while do not
// disturb was on would be the badge's sentence said twice, at opposite ends of
// the same bar. This one says what it opens; the badge says what is being done
// to you.

import QtQuick
import "root:/"
import "root:/modules/notifications"

Item {
    id: root

    // The bar's shared popout, handed down by Bar.qml exactly as the tray and
    // the peripheral battery get it. One window for the whole bar, moved under
    // whichever widget was clicked -- see components/Popout.qml.
    required property var popout

    // How many went by unseen. Read once here so the width, the two colours
    // and the label all move together off one value.
    readonly property int unread: NotificationState.unread

    // Matches SettingsButton and PowerButton beside it; the note on why the
    // disc is six under the pill rather than ten lives in SettingsButton.
    readonly property int discSize: Theme.groupHeight - 6

    // A DISC WHILE THERE IS NOTHING TO SAY, A PILL WHEN THERE IS. With no
    // count this is byte for byte the target the gear next to it draws; with
    // one, the same rounded shape grows sideways to hold it rather than the
    // number being stuck to the glyph as a superscript badge. The bar has no
    // other superscripts and one of them would read as damage.
    implicitWidth: root.unread > 0 ? content.implicitWidth + 16 : root.discSize
    implicitHeight: Theme.groupHeight

    // Animated because the change is caused by something arriving, not by
    // something being clicked: the pill should grow out of the disc the way
    // the badges beside the island unfold, rather than the row of controls
    // jumping sideways.
    Behavior on implicitWidth {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
    }

    // WHERE THE PANEL COMES OUT, in screen coordinates. mapToItem(null, ...)
    // gives coordinates in the bar's window and the bar starts at x = 0 of the
    // screen, so this is already a screen x -- the same reading Tray and
    // PeripheralBattery make.
    //
    // The fallback is for the bar where this widget is switched OFF. The keys
    // still work there -- SUPER + SHIFT + N reaches every bar, exactly as
    // SUPER + D opens the dashboard on a bar with no island -- but a Row does
    // not lay out an invisible child, so this item's own x has never been set
    // and says nothing. The right edge of the screen puts the panel where the
    // widget would have been, and Popout's own clamp brings it back inside.
    function anchorX(): real {
        if (root.visible)
            return root.mapToItem(null, root.width / 2, 0).x;

        return root.popout.screen?.width ?? 0;
    }

    // THE KEYBIND AND THE BADGE, both arriving through NotificationState.
    //
    // They are signals rather than a flag on that singleton for the reason
    // IslandState's header gives about the dashboard: whether the panel is up
    // is the popout's business, and mirroring it into a singleton would be a
    // second source of truth for one surface. So the singleton asks and this
    // file -- the only one that can see both the popout and the list --
    // answers.
    //
    // TOGGLE FOR THE KEY, OPEN FOR THE BADGE, and the difference is deliberate.
    // A second press of a key pressed by mistake should put the panel away; a
    // click on a badge that has just sent you somewhere should not close the
    // thing it opened. The same split the dashboard's two entry points had.
    Connections {
        target: NotificationState

        function onHistoryToggleRequested(): void {
            root.popout.toggleAt(root.anchorX(), historyComponent);
        }

        function onHistoryOpenRequested(): void {
            root.popout.openAt(root.anchorX(), historyComponent);
        }
    }

    Rectangle {
        anchors.fill: parent
        // Kept as tall as the disc rather than as tall as the group, so the
        // hover target is the same height whichever shape it is in.
        anchors.topMargin: (root.implicitHeight - root.discSize) / 2
        anchors.bottomMargin: (root.implicitHeight - root.discSize) / 2

        radius: height / 2
        color: mouse.containsMouse ? Qt.alpha(Theme.primary, 0.18) : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: Icons.bell
            font.family: Theme.fontFamily
            // Theme.controlSize, matching the two buttons beside it: inside a
            // shared pill these three have to read as one row of controls.
            font.pointSize: Theme.controlSize

            // ACCENT WHILE SOMETHING IS OWED, and accent on hover, which are
            // not in conflict: hover promises "this opens something" and a
            // debt is a reason to open it. What would be wrong is a third
            // colour, or critical -- nothing here is broken.
            color: root.unread > 0 || mouse.containsMouse
                ? Theme.primary
                : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        // NOT HIDDEN BEHIND THE HOVER, unlike the labels the badges beside the
        // island reveal. "There is a list here" is implied by the glyph;
        // "four things went past you" is not, and a number you only find by
        // pointing at it is a number you find out about too late. It was the
        // do-not-disturb badge that made that argument first.
        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: root.unread > 0
            text: `${root.unread}`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: Theme.primary
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Toggle and not open, the same as the two buttons beside it: clicking
        // the button that opened the panel should put it away again. The
        // popout's toggleAt compares what it is currently holding against the
        // component it is handed, so a second click here closes it while a
        // click on the tray next door swaps the contents instead.
        onClicked: root.popout.toggleAt(root.anchorX(), historyComponent)
    }

    Component {
        id: historyComponent

        // THE LIST, AT THE SIZE THE DASHBOARD TAB USED TO GIVE IT. That tab
        // was 620 x 480 with the card inside it inset 16 on every side, so the
        // list itself had 588 x 448 -- and the two-line body wrap it is tuned
        // for holds only at a particular width. Moving the panel should not
        // silently re-wrap every message in it.
        //
        // A fixed size and not one that follows the content, for the reason
        // the tab sizes give: this drives the popout's implicit size, which
        // drives a Wayland layer surface, and a panel that resized itself as
        // entries were cleared would ask the compositor to reconfigure under
        // the pointer.
        Item {
            implicitWidth: 588
            implicitHeight: 448

            NotificationHistory {
                anchors.fill: parent
            }
        }
    }
}
