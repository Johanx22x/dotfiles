// THE WINDOWS 11 TOAST, AND THE CARD IN THE NOTIFICATION CENTRE, WHICH ARE
// THE SAME THING IN TWO EXPAND STATES -- theme.json says so beside
// notificationWidth, and it is why the facade carries `expanded` at all.
//
// EVERY NUMBER BELOW THAT IS NOT A TOKEN WAS MEASURED OFF A PHOTOGRAPH.
// scratchpad/ref/toast-minimal-outlook.png is close enough to 1:1 to read
// directly -- its card comes out 361 px wide, which is notificationWidth 360 --
// and toast-bottom-right.jpg is the same toast with an icon, a body and two
// buttons at 1.69x, taken off its 81 px taskbar against the real 48.
//
// WHAT THE PHOTOGRAPHS CORRECTED, and none of it is in any document:
//
//   * A TOAST CARRIES NO TIMESTAMP. The header is app icon, app name, then
//     `...` and `X` hard right, on one line, and nothing else. The clock only
//     appears on a card in the notification centre, where the notification is
//     already old. See the note over the header row for what that means here.
//   * The card ground is #212121 over a near-black wallpaper -- Theme.surface,
//     NOT surfaceContainer. The notification centre's cards sample #252932 on a
//     #1c2029 panel, one step lighter than the panel they sit on, which is the
//     same rule seen from the other side: a card is one step above ITS ground,
//     and a toast's ground is the desktop.
//   * The action buttons are the step above the card again (#333 on #2b2b2b in
//     the centre), side by side, each half the width, both the same weight.
//     There is no filled "primary" button on either photograph.
//   * There is no hover state on the card itself. The controls in it have one;
//     the card does not, and inventing one is the kind of detail that reads as
//     a recreation.
//
// THE WHOLE CARD IS THE CLICK TARGET AND THE CLICK IS dismiss(). Never
// expire(): expiring tells the sending application that the user never closed
// it, and Discord answers that by sending it again. The facade's header is the
// long version.
//
// `expanded` IS WRITABLE AND THIS FILE DOES NOT WRITE IT -- rule 4. The
// chevron calls row.toggleExpanded(), which is also what stops the facade's
// timer, because expanded means somebody is reading it.

import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property NotificationCard row

    // Hoisted, typed, and read from here by everything below -- including the
    // delegates, where `row.` would be checked by nothing at all.
    readonly property Notification note: root.row.notification

    readonly property int padding: Theme.notificationPadding

    // OURS, all four, measured off the two toast photographs at the scales in
    // the header. The type ramp and the two radii are Microsoft's and come
    // from Fluent; the gaps inside a toast are published nowhere.
    readonly property int headerIcon: 16
    readonly property int headerButton: 24
    readonly property int headerGap: 12
    readonly property int headerTextGap: 8
    readonly property int actionGap: 24
    readonly property int buttonGap: 8

    // Collapsed shows two lines of body and expanded shows ten. Two is what
    // the minimal toast shows before it runs out of card; ten is a stop, not a
    // measurement -- a notification whose body is longer than that is a mail,
    // and the application it came from can show it better than this can.
    readonly property int collapsedLines: 2
    readonly property int expandedLines: 10

    // TWO ICONS AND NOT ONE TWICE, which is the difference between the two
    // toast photographs. `appIcon` is per-application and identifies the
    // sender, so it goes small in the header the way Outlook's does; `image`
    // is the picture attached to THIS notification -- an avatar, a cover, a
    // thumbnail -- so it goes in the 40px column beside the text, the way the
    // Game Pass toast's does. A sender that attaches nothing gets no column at
    // all, which is exactly the minimal toast's shape.
    readonly property string appSource: Icons.resolve(root.note.appIcon)
    readonly property string bodySource: root.note.image

    // ONLY THE ACTIONS THAT CARRY A LABEL. The freedesktop protocol lets a
    // sender attach a "default" action -- the one that means "clicked the
    // body" -- and its label is routinely empty, because nothing is supposed
    // to draw it. Counting it made a real button with nothing written on it:
    // photographed on a notify-send card whose only action was the default
    // one. Windows has no such button either; its toast activation is the
    // body, which is the same statement the protocol is making.
    // An indexed loop and not `[...].filter()`: `actions` is a C++ QList, and
    // spreading one depends on the iterator protocol being wired for that
    // exact wrapper type. Length-and-index is the access every wrapper has.
    readonly property var labelledActions: {
        const out = [];
        const all = root.note.actions;
        for (let i = 0; i < all.length; i++) {
            if ((all[i].text ?? "").trim() !== "")
                out.push(all[i]);
        }
        return out;
    }

    readonly property int actionCount: root.labelledActions.length

    // WHETHER THERE IS ANYTHING TO EXPAND, asked twice because the answer has
    // to survive being expanded. Collapsed, `truncated` is the elide reporting
    // that it dropped something; expanded, the elide is gone and the only
    // evidence left is the line count.
    readonly property bool expandable: root.row.expanded
        ? bodyText.lineCount > root.collapsedLines
        : bodyText.truncated

    implicitHeight: (actions.visible ? actions.y + actions.height : body.y + body.height)
        + root.padding

    // ---------------- The card ----------------
    Rectangle {
        anchors.fill: parent

        radius: Theme.notificationRadius
        antialiasing: true

        // A flyout, so acrylic and not Theme.glass: the taskbar carries the
        // wallpaper's colour and a card that opens on top of the desktop does
        // not.
        color: Fluent.acrylic(Theme.surface)

        // The hairline the photographs show all round. Critical takes the alert
        // colour instead -- OURS: Windows has no urgent toast, and a card that
        // said nothing about urgency would be a card that dropped the one field
        // the spec has for it.
        border.width: 1
        border.color: root.row.critical ? Theme.critical : Theme.outlineVariant
    }

    // The whole card, under everything else so that the buttons in it keep
    // their own clicks.
    MouseArea {
        anchors.fill: parent

        onClicked: root.row.dismiss()
    }

    // ---------------- Header ----------------
    //
    // THE TIMESTAMP SLOT IS EMPTY AND THAT IS THE HONEST ANSWER.
    //
    // Windows prints a time on a card in the notification centre and never on
    // a toast, so on this surface there is nothing missing. Where one WOULD go,
    // there is nothing to print: Quickshell's Notification carries
    // expireTimeout and no creation time of any kind -- checked in
    // quickshell-service-notifications.qmltypes, which lists every property it
    // has -- and the facade does not add one. The one real clock in this shell
    // is NotificationState.history's `time`, which is stamped when a
    // notification arrives and is what notifications/HistoryCard.qml prints.
    //
    // The alternative is a card that stamps Date.now() when it is BUILT and
    // calls that the arrival time. It is right for a toast by accident and
    // wrong for everything else, and printing a wrong time is worse than
    // printing none.
    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding

        height: root.headerButton

        Image {
            id: appIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: root.headerIcon
            height: root.headerIcon

            source: root.appSource
            visible: root.appSource !== "" && appIcon.status === Image.Ready
            sourceSize.width: root.headerIcon * 2
            sourceSize.height: root.headerIcon * 2
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }

        // The fallback, and it is a glyph rather than a blank: a header with
        // nothing at its left reads as a broken row, not as an application
        // without an icon.
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            visible: !appIcon.visible
            width: root.headerIcon

            text: Icons.bell
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: root.headerIcon + root.headerTextGap
            anchors.right: controls.left
            anchors.rightMargin: root.headerTextGap
            anchors.verticalCenter: parent.verticalCenter

            text: root.note.appName
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurfaceVariant
            elide: Text.ElideRight
        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            spacing: 0

            // The chevron, which is the `...` in the photograph's place and not
            // its job: Windows opens a context menu there. What this card has
            // to offer is the expand the facade already carries, and it is only
            // there when there is something under it.
            GlyphButton {
                visible: root.expandable
                content: Icons.chevronDown
                // There is no chevronUp in the icon set, and a rotated chevron
                // is what the control does anyway.
                turn: root.row.expanded ? 180 : 0

                onActivated: root.row.toggleExpanded()
            }

            GlyphButton {
                content: Icons.close

                onActivated: root.row.dismiss()
            }
        }
    }

    // ---------------- Icon, title, body ----------------
    Item {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: root.headerGap

        implicitHeight: Math.max(picture.visible ? picture.height : 0, text.height)
        height: body.implicitHeight

        ClippingRectangle {
            id: picture

            anchors.left: parent.left
            anchors.top: parent.top

            width: Theme.notificationIconSize
            height: Theme.notificationIconSize

            visible: root.bodySource !== "" && art.status === Image.Ready
            color: "transparent"
            radius: Fluent.controlRadius

            Image {
                id: art

                anchors.fill: parent

                source: root.bodySource
                sourceSize.width: Theme.notificationIconSize * 2
                sourceSize.height: Theme.notificationIconSize * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }

        Column {
            id: text

            anchors.left: picture.visible ? picture.right : parent.left
            anchors.leftMargin: picture.visible ? Fluent.cardIconGap : 0
            anchors.right: parent.right
            anchors.top: parent.top

            spacing: 0

            Text {
                width: parent.width

                text: root.note.summary
                textFormat: Text.PlainText
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                font.weight: Fluent.strongWeight
                color: Theme.textOnSurface
                elide: Text.ElideRight
            }

            Text {
                id: bodyText

                width: parent.width

                visible: root.note.body !== ""
                text: root.note.body
                // The daemon answers GetCapabilities with body-markup, so a
                // sender is entitled to have sent some.
                textFormat: Text.StyledText
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.textOnSurfaceVariant
                wrapMode: Text.Wrap
                maximumLineCount: root.row.expanded ? root.expandedLines : root.collapsedLines
                elide: Text.ElideRight
            }
        }
    }

    // ---------------- The actions ----------------
    //
    // Side by side and equal, however many there are. Two is what the
    // photographs show and what nearly every sender emits; three is not a
    // shape Windows has, so they divide the width rather than wrap.
    Row {
        id: actions

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: body.bottom
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: root.actionGap

        visible: root.actionCount > 0
        height: visible ? Fluent.controlHeight : 0
        spacing: root.buttonGap

        Repeater {
            model: root.labelledActions

            Rectangle {
                id: button

                required property NotificationAction modelData

                readonly property bool hovered: pointer.containsMouse
                readonly property bool held: pointer.pressed

                width: (actions.width - (root.actionCount - 1) * root.buttonGap) / root.actionCount
                height: Fluent.controlHeight

                radius: Fluent.controlRadius
                border.width: 1
                border.color: Theme.outlineVariant

                // No Behavior: Fluent.hoverMs is 0 because Windows swaps the
                // brush at time zero, and hover brightens while press dims.
                color: {
                    if (button.held)
                        return Fluent.fillPress;
                    if (button.hovered)
                        return Fluent.fillHover;
                    return Fluent.fillRest;
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: Fluent.controlPaddingH
                    anchors.rightMargin: Fluent.controlPaddingH

                    text: button.modelData.text
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    color: Theme.textOnSurface
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    hoverEnabled: true

                    // The action is the sender's, and invoking it is not
                    // closing the notification: an application that wants its
                    // card gone says so on the bus.
                    onClicked: button.modelData.invoke()
                }
            }
        }
    }

    // A 24px square that takes the click, with the 16px glyph centred in it.
    // The square is OURS -- Windows publishes 32 for a control and the header
    // of a toast is visibly smaller than that.
    component GlyphButton: Rectangle {
        id: glyphButton

        required property string content

        property int turn: 0

        readonly property bool hovered: glyphPointer.containsMouse
        readonly property bool held: glyphPointer.pressed

        signal activated

        width: root.headerButton
        height: root.headerButton

        radius: Fluent.controlRadius
        color: {
            if (glyphButton.held)
                return Fluent.fillPress;
            if (glyphButton.hovered)
                return Fluent.fillSubtleHover;
            return "transparent";
        }

        Text {
            anchors.centerIn: parent

            text: glyphButton.content
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurfaceVariant
            rotation: glyphButton.turn
        }

        MouseArea {
            id: glyphPointer

            anchors.fill: parent
            hoverEnabled: true

            onClicked: glyphButton.activated()
        }
    }
}
