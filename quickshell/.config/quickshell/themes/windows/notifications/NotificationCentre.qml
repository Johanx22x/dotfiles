// WIN+N: THE NOTIFICATION CENTRE, WHICH IS THE LIST OVER THE CALENDAR.
//
// It is the content of the taskbar's one popout -- the clock opens it, because
// on Windows the clock IS the door to this and there is no bell anywhere on
// the bar. bar/Bar.qml hands this Component to components/Popout.qml, which
// owns the window, the position, the 12px it floats off the bar by, and the
// shadow. It draws no panel of its own: under this theme the material belongs
// to the content, one card at a time, which is exactly what this surface
// needs.
//
// TWO PANELS AND A GAP, WHICH IS THE SHAPE THE PHOTOGRAPH INSISTS ON.
// scratchpad/ref/notifcenter-calendar-empty.jpg is not one column with a
// divider in it: it is a notifications panel and a clock panel, stacked, with
// the WALLPAPER READING THROUGH the sixteen pixels between them. Quick
// Settings does the same thing with its media transport, and it is the reason
// components/Popout.qml has no rectangle in it.
//
// THE TONES ARE SAMPLED, NOT CHOSEN. Off that photograph the panel reads
// #1c2029 and a card in it #252932; off quicksettings-media-tiles.jpg the
// panel reads (29,33,42) and a tile (50,56,72). Both are the same statement:
// the PANEL is the dark ground with the wallpaper's colour in it --
// Theme.surface under acrylic -- and what sits ON it is a step lighter.
// Backwards is the tell the whole restart exists to avoid: every surface that
// comes forward gets LIGHTER.
//
// THE HEADER IS FROM notifcenter-card-buttons.jpg: `Notifications` large at
// the left, and at the right a small do-not-disturb glyph button and a
// `Clear all` button drawn as an OUTLINED rounded rectangle -- not a text
// link, which is what every recreation reaches for.
//
// WHAT THE LIST IS. NotificationState.history, which is what ARRIVED, not what
// is on screen: the toasts have their own surface and are gone by the time
// anybody opens this. That is also what makes the entries plain objects rather
// than live notifications; notifications/HistoryCard.qml carries the long
// version.

import QtQuick
import qs
import qs.modules.notifications
import qs.themes.windows

Item {
    id: root

    readonly property int padding: Theme.notificationPadding

    // THE PANEL IS THE CARD'S WIDTH AND THE CARDS INSIDE IT ARE NARROWER,
    // which is the opposite of the arithmetic that suggests itself. Measured
    // off notifcenter-card-buttons.jpg against its own taskbar: the panel is
    // ~366 and the cards in it ~350, inset about eight a side. A toast is the
    // one that is Theme.notificationWidth on its own.
    readonly property int cardInset: Theme.notificationGap

    // Sixteen between the two panels, measured off
    // notifcenter-calendar-empty.jpg at its 0.917 scale. It is the flyout
    // padding again, which is what makes it a token rather than a fourth
    // number.
    readonly property int panelGap: root.padding

    // How much of the list is shown before it scrolls. OURS, and it is a
    // budget rather than a measurement: the popout's height is a session
    // high-water mark, so a list that grew without a stop would leave the
    // taskbar's flyout as tall as the tallest thing that ever opened in it.
    readonly property int listBudget: 380

    // AND THE BUDGET GIVES WAY TO THE SCREEN. Windows' own notification centre
    // is a tall flyout -- measured off notifcenter-calendar-empty.jpg it comes
    // to about 800 -- which is comfortable on the monitors this desktop has
    // and taller than the whole screen on a small one. The popout is anchored
    // to the taskbar and grows UPWARDS, so content that does not fit does not
    // scroll: it goes off the top edge, header first, and the `Clear all` that
    // would have emptied the list goes with it. Photographed on the sandbox's
    // 1280x720 output, which is exactly the case that shows it.
    //
    // The list is what gives, because it is the only part of this panel that
    // can scroll instead. The panel grows UPWARD from a bottom taskbar, so
    // what runs out of screen is the top of it -- the "Notifications" heading
    // and "Clear all", which are the two controls on this surface.
    //
    // `Screen` is QtQuick's attached property -- the OUTPUT this item is drawn
    // on -- and not the window's height, which is this content's own height
    // and would be a loop.
    //
    // THE FLOOR USED TO BE THE EMPTY STATE'S OWN HEIGHT, "so it can never be
    // squeezed to nothing", and that was the wrong thing to protect. On the
    // sandbox's 720p output the calendar and that floor together came to 666
    // against 660 of room and the panel went six pixels off the TOP, taking
    // the heading and Clear all with it: a floor under a placeholder, paid for
    // with the controls. Measured, not guessed -- 720p clips, 1080p leaves 102
    // and 1440p leaves 462.
    //
    // So the screen wins and the list takes what is left. What that costs on a
    // short screen is a squeezed "No new notifications", which is a message
    // about nothing; what it buys is a header that is always reachable.
    //
    // Windows itself does neither: it scrolls the calendar and the list
    // together as one column. That is very likely the right answer and it is
    // not implemented, because no reference photograph here shows this panel
    // on a screen too short for it and this theme does not guess at states it
    // has not seen.
    readonly property int listMax: {
        const chrome = Fluent.controlHeight + root.padding * 2 + root.cardInset
            + root.panelGap + calendar.implicitHeight;
        const room = Screen.height - Theme.barHeight - Fluent.flyoutInset * 2 - chrome;
        return Math.max(0, Math.min(root.listBudget, room));
    }

    readonly property bool empty: NotificationState.history.length === 0

    implicitWidth: Theme.notificationWidth
    implicitHeight: layout.implicitHeight

    // OPENING THE LIST PAYS THE DEBT. `unread` is what went by while the mute
    // was on and the taskbar clock carries it as a badge; reading the list is
    // what clears it. The entries stay, so it can be read again -- see
    // NotificationState.markRead().
    Component.onCompleted: NotificationState.markRead()

    Column {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        spacing: root.panelGap

        // ================= THE NOTIFICATIONS PANEL =================
        Rectangle {
            id: notificationsPanel

            width: parent.width
            implicitHeight: notifications.implicitHeight + root.cardInset

            radius: Fluent.overlayRadius
            antialiasing: true
            color: Fluent.acrylic(Theme.surface)
            border.width: 1
            border.color: Theme.outlineVariant

            Column {
                id: notifications

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: 0

                // ---------------- Header ----------------
                Item {
                    width: parent.width
                    height: Fluent.controlHeight + root.padding * 2

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: root.padding
                        anchors.verticalCenter: parent.verticalCenter

                        text: "Notifications"
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodyLargeSize
                        color: Theme.textOnSurface
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: root.padding
                        anchors.verticalCenter: parent.verticalCenter

                        spacing: Theme.itemSpacing

                        // Do not disturb. It is a real switch on this shell
                        // and it is the glyph Windows puts here, so it is the
                        // one control in this header that is not ours.
                        PillButton {
                            square: true
                            content: NotificationState.dnd ? Icons.bellOff : Icons.bell
                            accented: NotificationState.dnd

                            onActivated: NotificationState.toggle()
                        }

                        PillButton {
                            content: "Clear all"
                            enabled: !root.empty

                            onActivated: NotificationState.clearHistory()
                        }
                    }
                }

                // ---------------- The list ----------------
                ListView {
                    id: list

                    width: parent.width
                    height: Math.min(list.contentHeight, root.listMax)

                    visible: !root.empty
                    clip: true
                    model: NotificationState.history
                    spacing: Theme.notificationGap
                    boundsBehavior: Flickable.StopAtBounds

                    // IT STARTS AT THE TOP EVERY TIME and does not restore
                    // NotificationState.historyScroll. That property belongs
                    // to the shell's own history panel, which follows the
                    // focus across monitors and is rebuilt when it moves; this
                    // list is built fresh by the popout on every open and torn
                    // down on every close, which is the case that singleton
                    // clears the offset for anyway.

                    delegate: Column {
                        id: group

                        // Typed and hoisted out of the delegate body: inside
                        // one, an untyped read is checked by nothing at all.
                        required property int index
                        required property var modelData

                        readonly property var previous: group.index > 0
                            ? NotificationState.history[group.index - 1]
                            : null

                        // WINDOWS HEADS A RUN OF CARDS FROM ONE APPLICATION
                        // WITH ITS NAME, outside the card and above it --
                        // `Suggested` in notifcenter-card-buttons.jpg. Only
                        // the first of a run carries it, which is what makes
                        // it a group label rather than a repeated caption.
                        readonly property bool heads: group.previous === null
                            || group.previous.appName !== group.modelData.appName

                        width: list.width
                        spacing: 0

                        Item {
                            width: parent.width
                            height: group.heads ? Fluent.navItemHeight : 0

                            visible: group.heads

                            // The application's own icon at the head of its
                            // run, small, the way the photograph's `Suggested`
                            // row carries one. Sixteen is the same glyph size
                            // the toast's header uses.
                            Image {
                                id: groupIcon

                                anchors.left: parent.left
                                anchors.leftMargin: root.padding
                                anchors.verticalCenter: parent.verticalCenter

                                width: Fluent.trayIcon
                                height: Fluent.trayIcon

                                source: Icons.resolve(group.modelData.appIcon)
                                visible: groupIcon.status === Image.Ready
                                sourceSize.width: Fluent.trayIcon * 2
                                sourceSize.height: Fluent.trayIcon * 2
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: groupIcon.visible
                                    ? root.padding + Fluent.trayIcon + Theme.notificationGap
                                    : root.padding
                                anchors.right: parent.right
                                anchors.rightMargin: root.padding
                                anchors.verticalCenter: parent.verticalCenter

                                text: group.modelData.appName === ""
                                    ? "Notification"
                                    : group.modelData.appName
                                font.family: Theme.fontFamily
                                font.pointSize: Fluent.captionSize
                                color: Theme.textOnSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                        HistoryCard {
                            x: root.cardInset

                            width: list.width - root.cardInset * 2
                            entry: group.modelData
                        }
                    }
                }

                // ---------------- Nothing to show ----------------
                //
                // Centred in a tall empty area, which is what the photograph
                // does: the panel keeps its size when there is nothing in it
                // rather than collapsing to a header.
                //
                // THROUGH listMax LIKE THE LIST, and that is the whole reason
                // the clamp above works. `listMax` says the list is "the only
                // part of this panel that can scroll instead", but with an
                // empty history the list is zero high and this box is what
                // sets the panel's size -- so a bare 128 here walked straight
                // past the screen budget and pushed the header off the top.
                // Bounding both means one lever governs what gives.
                Item {
                    width: parent.width
                    height: Math.min(Fluent.previewIcon * 2, root.listMax)

                    visible: root.empty

                    Text {
                        anchors.centerIn: parent

                        text: "No new notifications"
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodySize
                        color: Theme.textOnSurfaceVariant
                    }
                }
            }
        }

        // ================= THE CLOCK PANEL =================
        Rectangle {
            width: parent.width
            implicitHeight: calendar.implicitHeight

            radius: Fluent.overlayRadius
            antialiasing: true
            color: Fluent.acrylic(Theme.surface)
            border.width: 1
            border.color: Theme.outlineVariant

            CalendarPane {
                id: calendar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
            }
        }
    }

    // The two shapes in the header: a 32px square for a glyph and a 32px pill
    // for a word -- the height is ControlHeight either way, and so is the
    // padding. OUTLINED AND NOT FILLED, both of them: the photograph's
    // `Clear all` is a rounded rectangle with a hairline round it, and there is
    // no filled primary button anywhere in the notification centre.
    component PillButton: Rectangle {
        id: pill

        required property string content

        property bool square: false
        property bool accented: false

        readonly property bool hovered: pointer.containsMouse
        readonly property bool held: pointer.pressed

        signal activated

        width: pill.square ? Fluent.controlHeight : pillText.implicitWidth + Fluent.controlPaddingH * 2
        height: Fluent.controlHeight

        radius: Fluent.controlRadius
        opacity: pill.enabled ? 1 : Fluent.disabledOpacity
        border.width: 1
        border.color: Theme.outlineVariant

        // No Behavior: Fluent.hoverMs is 0 because Windows swaps the brush at
        // time zero. Hover brightens and press dims, in that order.
        color: {
            if (pill.held)
                return Fluent.fillPress;
            if (pill.hovered)
                return Fluent.fillHover;
            return Fluent.fillRest;
        }

        // `pillText` and not `label`: rule 3 in
        // themes/genesis/components/README.md keeps that name, along with
        // `title` and `glyph`, out of a theme file entirely -- the settings
        // search walks the live object tree and duck-types on them.
        Text {
            id: pillText

            anchors.centerIn: parent

            text: pill.content
            font.family: Theme.fontFamily
            font.pointSize: pill.square ? Fluent.captionSize : Fluent.bodySize
            color: pill.accented ? Theme.primary : Theme.textOnSurface
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            // No `enabled` of its own: Item already has one, a disabled Item
            // disables the MouseArea under it, and the call site sets it.
            onClicked: pill.activated()
        }
    }
}
