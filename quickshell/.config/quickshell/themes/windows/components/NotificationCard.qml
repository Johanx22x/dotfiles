// How Windows draws one notification. The public half -- the timeout per
// urgency, the two values the spec reserves, the clock, and the difference
// between dismissing a notification and letting it expire -- is
// components/NotificationCard.qml, and none of that is drawing.
//
// A TOAST AND A NOTIFICATION CENTRE CARD ARE THE SAME COMPONENT IN TWO EXPAND
// STATES. That is documented rather than inferred, and it is why the facade has
// `expanded` at all: collapsed, the body is cut to a line and the sender's
// actions are not drawn; expanded, the body wraps and the actions appear. The
// card grows in place, the stack below slides down, and nothing opens a second
// window.
//
// THE GEOMETRY IS THE THEME'S theme.json AND IT IS OVERLAY GEOMETRY:
//
//   width    360   Theme.notificationWidth -- the PANEL's number, filled to
//   padding   16   Theme.notificationPadding, the standard flyout inset
//   radius     8   Theme.notificationRadius = OverlayCornerRadius. A toast is an
//                  overlay, so it is 8 and not the in-page 4
//   app icon  40   Theme.notificationIconSize, at ControlCornerRadius 4 -- the
//                  icon is an in-page element sitting inside an overlay
//
// THREE CONTRACTS THIS FILE KEEPS AND NOTHING CHECKS.
//
// `expanded` IS WRITABLE AND THIS FILE DOES NOT WRITE IT. Rule 4: the chevron
// calls `row.toggleExpanded()`. The facade's Timer is bound to that property, so
// a second writer to it is a second writer to when notifications leave the
// screen.
//
// THE WHOLE CARD IS THE TARGET AND A CLICK MEANS `row.dismiss()`, NEVER
// `expire()`. Both take the card off the screen and they say opposite things to
// the sender: dismissing tells the application the user closed it deliberately,
// which is what lets apps like Discord stop re-sending the same thing, while
// expiring tells it you never looked. The facade owns that distinction and
// exposes the one of the two a click means.
//
// THE X IN THE HEADER IS THAT SAME `dismiss()` AND NOT A SECOND ANSWER. Windows
// toasts carry a close button and genesis's card does not, which is the one
// place this drawing adds a control the rule in README.md says is not there --
// so it is worth being exact about what changed and what did not. What the rule
// protects is that closing means dismiss and that the card is not a target you
// have to aim at; both hold. The X is a smaller target on top of the big one,
// wired to the same function, and the card behind it still dismisses from
// anywhere.
//
// THE TIMEOUT IS READ AND NEVER RECOMPUTED. `row.timeoutSeconds`, `row.timeout`
// and `row.critical` are the facade's answers -- which urgency maps to which
// setting, what the spec's -1 and 0 mean, and that "critical" is the spec's enum
// and not a style. This drawing reads `critical` for the stroke and asks the
// other two nothing: the clock is the facade's and there is nothing on a Windows
// toast that counts it down.
//
// AND THERE IS NO TIMESTAMP, WHICH IS A GAP RATHER THAN A CHOICE. A Notification
// Center card puts the time at the right end of its header and this one has an
// empty slot there. Quickshell's Notification type exposes no arrival time --
// checked against
// /usr/lib/qt6/qml/Quickshell/Services/Notifications/quickshell-service-notifications.qmltypes,
// which lists expireTimeout and no creation time of any kind -- so the only ways
// to draw one are to invent it or to clock it from inside a theme file, and a
// clock behind the seam stops existing on a theme swap. Genesis prints the
// literal "now" on every card including the ones in the history panel. That is
// the wrong kind of answer, so this file prints nothing and says why.

import QtQuick
import qs
import qs.components
import ".."

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in genesis's ToggleRow.qml on why it is `required`, why it is typed rather
    // than `var`, and why `NotificationCard` here is the facade and not this
    // file.
    required property NotificationCard row

    // HOISTED, because the Repeater at the bottom is a delegate and rule 1's
    // checking stops at its edge -- `row.notification.actions` read from inside
    // it would be exactly as unchecked as `property var row` would have made the
    // whole file. It is also read twice, once for `visible` and once for the
    // model, and an unqualified read of a member whose type Qt does not expose
    // declaratively costs an [unresolved-type] PER READ; hoisting it takes two
    // to one.
    readonly property var actions: root.row.notification.actions

    readonly property bool expanded: root.row.expanded

    // ---------------- The two header buttons ----------------
    //
    // One shape, twice, and it is an inline component rather than a Loader for
    // the reason in README.md: everything inside a `Loader { Component { } }` is
    // a nested component with `root` out of scope. AN INLINE `component` IS NOT
    // THAT -- it is a type declaration, its two instances in the header below
    // are ordinary children of this file, and the properties they set are
    // checked the way any other property assignment is. Nothing inside it reads
    // `row`: the instances read the facade at the call site and hand this a
    // glyph name and a function, which keeps every crossing of the seam at the
    // top level. Declared before it is used, which costs nothing and settles the
    // question rather than relying on the compiler collecting it first.
    component HeaderButton: Rectangle {
        id: headerButton

        // NOT `glyph`, WHICH IS RULE 3. SettingsSearch walks a live object
        // tree reading `child.glyph ?? ""`, and while a notification is not in
        // the settings window today, the ban is on the NAME rather than on the
        // place: a property called glyph anywhere behind the seam is a property
        // the index will pick up the day the tree it walks changes.
        property string symbol: ""
        property bool turned: false

        signal activated

        // Windows' own toast buttons are smaller than a Button: a caption-sized
        // glyph in a square backplate. OURS -- see the header on what is
        // published about toasts, which is nothing.
        width: 28
        height: 28
        radius: Fluent.controlRadius

        color: buttonMouse.pressed ? Theme.surfaceContainer
            : buttonMouse.containsMouse ? Fluent.fillSubtleHover
            : "transparent"

        Text {
            anchors.centerIn: parent
            text: headerButton.symbol
            rotation: headerButton.turned ? 180 : 0
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurfaceVariant

            Behavior on rotation {
                NumberAnimation {
                    duration: Fluent.fastMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Fluent.easeOut
                }
            }
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            enabled: headerButton.enabled
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            onClicked: headerButton.activated()
        }
    }

    implicitHeight: layout.implicitHeight + Theme.notificationPadding * 2

    radius: Theme.notificationRadius
    color: Theme.surfaceContainer

    // Critical notifications get an outline instead of a different fill:
    // recolouring the whole card would fight the palette, an edge does not. The
    // ordinary card keeps the thin stroke every Windows overlay has.
    border.width: 1
    border.color: root.row.critical ? Theme.critical : Theme.outlineVariant

    // THE GROWTH IS MOTION AND MOTION IS THIS SIDE'S. Nothing on the other side
    // of this seam reads the card's height except the Column that stacks the
    // cards, and it is happy to be told a moving number: the facade follows this
    // implicitHeight through its Loader and the stack slides.
    //
    // WinUI's one spline, at the 250ms it uses for a dialog's own scale. Qt takes
    // a cubic bezier as its control points flattened, which is what Fluent.easeOut
    // is.
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Fluent.normalMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Fluent.easeOut
        }
    }

    Column {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.notificationPadding

        spacing: Theme.notificationPadding / 2

        // ---------------- Header: who sent it, and the two buttons ----------
        Item {
            width: parent.width
            height: Math.max(appName.implicitHeight, chevron.height)

            Text {
                id: appGlyph

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                text: Icons.bell
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }

            // Caption, secondary ink: this is the line that says which
            // application is talking, and it is the quietest thing on the card.
            Text {
                id: appName

                anchors.left: appGlyph.right
                anchors.leftMargin: 6
                anchors.right: chevron.left
                anchors.rightMargin: Theme.itemSpacing
                anchors.verticalCenter: parent.verticalCenter

                text: root.row.notification.appName
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                font.weight: Fluent.normalWeight
                color: Theme.textOnSurfaceVariant
            }

            // AND NOTHING BETWEEN THE NAME AND THE BUTTONS, which is where a
            // Notification Center card puts the time. There is no arrival time
            // to draw -- see the header, which names the file that was checked
            // -- so the gap is left as a gap. The name above elides against the
            // chevron, so a timestamp added here later needs the one anchor
            // changed and nothing else moved.

            // Expand / collapse. The card's own state lives on the facade because
            // the clock is bound to it, so this asks rather than assigns -- rule
            // 4.
            HeaderButton {
                id: chevron

                anchors.right: close.left
                anchors.verticalCenter: parent.verticalCenter

                symbol: Icons.chevronDown
                turned: root.expanded
                onActivated: root.row.toggleExpanded()
            }

            // Close, and it is dismiss() -- see the header.
            HeaderButton {
                id: close

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                symbol: Icons.close
                onActivated: root.row.dismiss()
            }
        }

        // ---------------- The notification itself ----------------
        Item {
            width: parent.width
            height: Math.max(icon.height, body.implicitHeight)

            // The sender's icon: its own image if it sent one, otherwise the
            // application icon from the desktop entry. Square at
            // ControlCornerRadius, which is what Windows does with an app logo
            // inside a toast -- genesis's `radius: height / 2` circle is an
            // Android shape.
            Rectangle {
                id: icon

                anchors.left: parent.left
                anchors.top: parent.top

                width: Theme.notificationIconSize
                height: Theme.notificationIconSize
                radius: Fluent.controlRadius
                color: Theme.surfaceContainerHighest

                Image {
                    id: sent

                    anchors.fill: parent
                    anchors.margins: 4

                    source: Icons.resolve(root.row.notification.image || root.row.notification.appIcon)
                    visible: sent.status === Image.Ready
                    sourceSize.width: sent.width
                    sourceSize.height: sent.height
                }

                Text {
                    anchors.centerIn: parent

                    // Nothing to show: the bell stands in, so the card never has
                    // a hole where the icon goes.
                    visible: !root.row.notification.image && !root.row.notification.appIcon
                    text: Icons.bell
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: Theme.textOnSurfaceVariant
                }
            }

            Column {
                id: body

                anchors.left: icon.right
                anchors.leftMargin: Theme.itemSpacing
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: 2

                // Body Strong: 14 at Semibold, which is the one place Windows
                // 11's typography asks for weight. Never Bold.
                Text {
                    width: parent.width
                    visible: root.row.notification.summary !== ""
                    text: root.row.notification.summary
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    font.weight: Fluent.strongWeight
                    color: Theme.textOnSurface
                }

                // One under Body. OURS: Microsoft publishes no toast anatomy at
                // all -- the research sweep says so in as many words -- and the
                // ramp has no step between Caption 12 and Body 14. Written as an
                // offset from Fluent's own Body so the user's font dial still
                // moves it.
                Text {
                    width: parent.width
                    visible: root.row.notification.body !== ""
                    text: root.row.notification.body
                    textFormat: Text.StyledText

                    // Collapsed: two lines, cut. Expanded: as many as it needs.
                    maximumLineCount: root.expanded ? 0 : 2
                    wrapMode: Text.Wrap
                    elide: root.expanded ? Text.ElideNone : Text.ElideRight

                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize - 1
                    font.weight: Fluent.normalWeight
                    color: Theme.textOnSurfaceVariant
                }
            }
        }

        // ---------------- Actions ----------------
        //
        // Only while expanded: collapsed cards stay two lines tall whatever the
        // sender attached to them.
        //
        // DRAWN AS components/Chip.qml AND NOT AS A SECOND BUTTON. The button
        // role is already Windows' Button -- Fluent.controlHeight at
        // ControlCornerRadius, the lit edge, the accent variant with its black
        // ink -- which is exactly what the spec asks for here, and a Rectangle
        // written out again in this file would be a second answer to drift from
        // the first.
        Row {
            width: parent.width
            visible: root.expanded && root.actions.length > 0
            spacing: Theme.itemSpacing

            Repeater {
                model: root.actions

                Chip {
                    id: action

                    required property var modelData
                    required property int index

                    role: "button"

                    // `name` and not `label`: rule 3. An action a chat client
                    // attached to a message is not a setting, and `label` is what
                    // SettingsSearch indexes.
                    name: action.modelData.text

                    // The first one carries the sender's intent, which is the
                    // accent one. The rest are ordinary buttons.
                    filled: action.index === 0

                    onActivated: action.modelData.invoke()
                }
            }
        }
    }

    // Click anywhere else on the card to dismiss. Declared last so the two
    // header buttons and the action chips win the click where they overlap.
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.ArrowCursor
        onClicked: root.row.dismiss()
    }
}
