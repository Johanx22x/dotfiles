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
// IT SHOWS THE MUTE, and while it is drawn it is the only thing that does.
//
// This file used to argue the opposite: a bell that crossed itself out while
// do not disturb was on would be the do-not-disturb badge's sentence said
// twice, at opposite ends of the same bar. The observation was right and the
// conclusion was the wrong way round. The badge grew out of the island's left
// edge in the middle of the bar, while the bell -- the control the mute is
// actually ABOUT, the one you press to find out what it swallowed -- sat
// unchanged at the far right. One control carries both halves now: bellOff
// while the mute is on, bell when it is not, which is byte for byte how the
// switch inside the panel it opens draws it. The badge stays only as a
// stand-in for a bar with no bell; see DndIndicator.active.
//
// THE ACCENT MEANS "THE MUTE IS ON", and that is not a second job for it.
// A count can only exist inside a mute -- NotificationState.record raises
// unread only for what it silenced, and either edge of setDnd zeroes it -- so
// the number is never the reason the colour is there, only a refinement of it:
// the mute is on, and it has swallowed four. The colour that WOULD be saying
// something else is critical, and nothing here is broken; that reasoning was
// the badge's and it still holds, because a mode you chose reads as a state
// and not as a fault.
//
// COLOUR AND GLYPH, NO BACKGROUND. "A mute you cannot see is a trap" is why
// the badge was built in the first place, and bellOff differs from bell by a
// thin diagonal across a small monochrome glyph at the end of a bar -- a swap
// nobody catches out of the corner of an eye. The accent is what makes it
// survive being read at a glance. A tinted background behind it would be a
// second background inside a pill that already has one, which is the same
// reason the count below takes the accent instead of a badge of its own.
//
// THE COUNT IS A DEBT -- see NotificationState.unread. It was the badge's
// number first, and the badge gave it up for as long as this widget is drawn
// so that exactly one thing on the bar is ever saying it. That handoff now
// covers the whole badge rather than only its number, for the same reason.
//
// RIGHT CLICK SWITCHES THE MUTE, without opening anything. It is the shortcut
// for the one case where you are already pointing at the control the mute is
// about -- the same argument the island makes for taking a right click as
// play/pause, and the same one the do-not-disturb badge makes for unmuting on
// its own right button. Left click is unchanged, because the panel is what
// this button is FOR; a gesture that only exists for people who already know
// it must not take the primary one.
//
// AND IT IS ANNOUNCED, which is not optional here. The obvious objection is
// that this button already draws the state, so the right click confirms
// itself -- and it does not, on precisely this gesture. Read the glyph's
// colour below: hover is one of the three conditions that turns it accent, and
// the pointer is on top of this button by definition when it is right-clicked.
// So the accent, which the note above calls the half that survives being read
// at a glance, does not move at all. What is left changing under the pointer
// is bell to bellOff, which the same note calls a thin diagonal nobody catches.
//
// The island says it instead, on the acknowledgement rung it already keeps for
// exactly this -- something you just did, confirmed, and gone in two seconds.
// It is wired in modules/island/Island.qml, watching the value rather than
// being told by this file, so EVERY door announces itself: this button, the
// switch in the panel, SUPER + N, and `qs ipc call dnd enable`. See the note
// there for why the flash lives in that file and not in the singleton.

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

    // Whether the mute is on. Read here beside the count for the same reason:
    // the glyph and its colour are two properties that have to change on the
    // same frame, and a binding each into the singleton would be two
    // subscriptions to one fact.
    readonly property bool muted: NotificationState.dnd

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
    // still work there -- SUPER + SHIFT + N is answered by whichever bar is
    // being asked whether or not it draws a bell, exactly as SUPER + D opens
    // the dashboard on a bar with no island -- but a Row does not lay out an
    // invisible child, so this item's own x has never been set and says
    // nothing. The right edge of the screen puts the panel where the widget
    // would have been, and Popout's own clamp brings it back inside.
    function anchorX(): real {
        if (root.visible)
            return root.mapToItem(null, root.width / 2, 0).x;

        return root.popout.screen?.width ?? 0;
    }

    // THE KEYBIND AND THE BADGE both arrive through NotificationState, and so
    // does the click on this button. They used to be SIGNALS on that singleton,
    // with a note saying whether the panel is up is the popout's business and a
    // flag there would be a second source of truth -- the same note IslandState
    // carried about the dashboard, and the same reason it no longer does. A
    // panel that has to move between monitors needs somebody who can see all
    // the bars at once, and a popout can only see itself.
    //
    // WHETHER THIS BAR IS THE ONE SHOWING THE LIST, and it is the dashboard's
    // rule with a different string -- see the block over showsDashboard in
    // modules/island/Island.qml, which carries the long version.
    //
    // The short one: NotificationState.historyScreen names the bar the list is
    // drawn on, every bell compares it against its own bar, at most one
    // matches. SUPER + SHIFT + N reaches every bar and used to make each of
    // them open its own copy; now it names one, and when the focus settles on
    // another monitor the string is retargeted and the panel moves.
    readonly property bool showsHistory: NotificationState.historyScreen !== ""
        && NotificationState.historyScreen === (root.popout.screen?.name ?? "")

    // The move REBUILDS the list -- a layer surface belongs to one output. The
    // rows come back off NotificationState.history unchanged; the one thing
    // that would not is where the list was scrolled to, which is why that
    // offset lives on the singleton rather than in the ListView.
    function syncHistory(): void {
        // Waiting for the Component further down to exist. Completion calls
        // this again, so nothing is lost by returning here.
        if (!historyComponent)
            return;

        if (root.showsHistory)
            root.popout.openAt(root.anchorX(), historyComponent);
        else if (root.popout.contentComponent === historyComponent)
            root.popout.close();
    }

    onShowsHistoryChanged: root.syncHistory()

    Component.onCompleted: root.syncHistory()

    // Clearing the string when the popout stops showing the list for any reason
    // nobody told the singleton about -- a click outside, a click on the bar,
    // the tray taking the window over. Guarded on showsHistory so it is the bar
    // that HAS the panel doing it: on a move the string changes first, so the
    // bar losing the list is already not the one showing it when its popout
    // closes, which is what tells a move apart from a dismissal.
    Connections {
        target: root.popout

        function onContentComponentChanged(): void {
            const mine = root.popout.contentComponent === historyComponent;

            if (root.showsHistory && !mine)
                NotificationState.historyScreen = "";
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

            // THE ONE THING ON THE BAR THAT SAYS THE MUTE IS ON. The same
            // pair the switch inside the panel draws for the same state, so
            // the button and the thing it opens are recognisably one setting
            // rather than two things that happen to be about bells.
            text: root.muted ? Icons.bellOff : Icons.bell

            font.family: Theme.fontFamily
            // Theme.controlSize, matching the two buttons beside it: inside a
            // shared pill these three have to read as one row of controls.
            font.pointSize: Theme.controlSize

            // ACCENT WHILE THE MUTE IS ON, accent while something is owed, and
            // accent on hover -- three conditions and one meaning each time,
            // because a debt only exists inside a mute (see the header) and
            // hover promises "this opens something", which a debt is a reason
            // to do. What would be wrong is a fourth colour, or critical --
            // nothing here is broken, the mute was asked for.
            //
            // Animated, so switching the mute with SUPER + N from anywhere on
            // the desktop reads as this glyph changing rather than as a
            // different glyph having always been there.
            color: root.muted || root.unread > 0 || mouse.containsMouse
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

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            // TOGGLE AND NOT SET, unlike the badge's right button, and the
            // difference is that the badge only exists while the mute is on --
            // it has nothing to switch back to. This button is drawn either
            // way, so a right click that only ever unmuted would do nothing at
            // all half the time it was tried.
            if (mouse.button === Qt.RightButton) {
                NotificationState.toggle();
                return;
            }

            // Toggle and not open, the same as the two buttons beside it:
            // clicking the button that opened the panel should put it away
            // again. Named with THIS bar, because a click lands on one and
            // says so -- and through the singleton rather than straight at the
            // popout, so what it opens is the one list that can be moved and
            // closed from anywhere rather than a copy nobody owns.
            NotificationState.toggleHistoryOn(root.popout.screen?.name ?? "");
        }
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
