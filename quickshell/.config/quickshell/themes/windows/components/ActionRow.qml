// How the windows theme draws a reading with something to press: a SettingsCard
// with a Windows button in its content slot. The public half -- what the pages
// write, why this is not a clickable InfoRow, and why `actionEnabled` is a
// second property rather than a use of `enabled` -- is components/ActionRow.qml.
//
// THE BUTTON IS THE TARGET AND IT LOOKS LIKE ONE, which is the promise this
// file keeps and the facade cannot require. There is exactly one MouseArea in
// here that takes a click and it is inside the button on the right. The other
// one accepts no buttons at all: it exists so the CARD lights up as one object
// under the pointer, which is what a settings card does, and it cannot turn
// this row into the clickable InfoRow that components/InfoRow.qml exists to
// promise never happens. See rule 7 in themes/genesis/components/README.md.
//
// AND THE WORD IS THE BUTTON. `row.actionText` is always drawn;
// `row.actionGlyph` is optional and goes before it. A theme that dropped the
// word when a glyph was set would be inventing an icon language the call sites
// never agreed to -- the facade's header says why a pencil, a folder and an
// ellipsis are not one.
//
// TWO SWITCHES, READ IN TWO PLACES, WHICH IS THE FIDDLY PART OF THIS FILE.
// `root.enabled` is Qt's effective-enabled coming down the tree from the page,
// and it means the whole row is out of play. `row.actionEnabled` is the
// facade's own property and it means the action is BUSY: it dims and deadens
// THE BUTTON ONLY, so the label and the description stay at full contrast while
// something runs. They are deliberately not multiplied together anywhere.
//
// THE BUTTON CARRIES THE LIT EDGE, and that is the one Windows detail in this
// directory that a solid border cannot stand in for.
// ControlElevationBorderBrush is a vertical gradient in ABSOLUTE mapping over
// 3px -- ControlStrokeColorSecondary down to ControlStrokeColorDefault -- so
// the brighter stroke occupies the top pixel whatever the control's height is,
// and the button reads as lit from above. It is drawn here as an outer
// Rectangle with the gradient and an inner one with the fill, because a
// Rectangle's own border takes a colour and not a brush.

import QtQuick
import qs
import qs.components
import ".."

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `ActionRow` here is the facade and not
    // this file.
    required property ActionRow row

    // WHAT THE FACADE READS BACK, and like InfoRow's it is not a constant: the
    // description wraps and nothing on the host side can know how far. 68 is
    // SettingsCardMinHeight and the 32 is the card's padding, top and bottom.
    implicitHeight: Math.max(Fluent.cardMinHeight, header.implicitHeight + Fluent.cardPadding * 2)

    radius: Fluent.controlRadius

    // The card lights up as one object. Hover brightens and press dims -- and
    // there is no press here, because nothing presses the card: the only thing
    // that takes a click is the button.
    color: mouse.containsMouse ? Fluent.fillHover : Fluent.fillRest

    border.width: 1
    border.color: Theme.outlineVariant

    // SettingsCard's own transition, and the only animation in this file:
    // `<win:Grid.BackgroundTransition><win:BrushTransition Duration="0:0:0.083"
    // /></win:Grid.BackgroundTransition>` on PART_RootGrid. Nothing else in a
    // Windows card fades -- see Fluent.hoverMs, which is 0 and is 0 on purpose.
    Behavior on color {
        ColorAnimation {
            duration: Fluent.fasterMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Fluent.easeOut
        }
    }

    // The dim is drawing and it lives here; `enabled` itself arrives down the
    // item tree with nothing forwarded by hand. See rule 6 in
    // themes/genesis/components/README.md -- including why the MouseAreas below
    // still say `enabled:` explicitly while this line does not read
    // `row.enabled`.
    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // The card lights up and the card does not answer. It takes no buttons at
    // all, which is what keeps this row from becoming the thing InfoRow
    // promises never to be.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // SettingsCardHeaderIconMargin is "2,0,20,0" -- a 20-wide icon column and a
    // 20 gap to the words. See ToggleRow.qml in this directory on why the 20 is
    // honoured as a box and the 2 is not carried.
    Item {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        visible: root.row.glyph !== ""
        width: root.row.glyph !== "" ? Fluent.cardIconMax : 0
        height: Fluent.cardIconMax

        Text {
            anchors.centerIn: parent

            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurface
        }
    }

    // The two lines stack with NO gap: SettingsCard's HeaderPanel is a
    // StackPanel with no Spacing set. The 24 on the right is that panel's own
    // Margin="0,0,24,0", which is the gutter Windows keeps in front of a card's
    // content whatever the content turns out to be.
    Column {
        id: header

        anchors.left: mark.right
        anchors.leftMargin: root.row.glyph !== "" ? Fluent.cardIconGap : 0
        anchors.right: action.left
        anchors.rightMargin: Fluent.cardActionGutter
        anchors.verticalCenter: parent.verticalCenter

        spacing: 0

        Text {
            width: parent.width
            visible: root.row.label !== ""
            text: root.row.label
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }

        Text {
            width: parent.width
            visible: root.row.description !== ""
            text: root.row.description
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurfaceVariant
        }
    }

    // ---------------- The button ----------------
    //
    // Button, ComboBox and TextBox all sit at 32 in Windows, with 11 of
    // horizontal padding and the control radius of 4. This outer Rectangle is
    // the lit edge and nothing else; the fill is the child below it.
    Rectangle {
        id: action

        // The gradient is mapped in ABSOLUTE pixels over 3, not as a fraction
        // of the control, which is why these two positions are computed from
        // the height rather than written down. Clamped so a control shorter
        // than the span still has stops in order.
        readonly property real edgeEnd: Math.min(1, Fluent.elevationSpan / Math.max(1, action.height))
        readonly property real edgeKnee: action.edgeEnd * Fluent.elevationStop

        // PRESSED DROPS THE GRADIENT TO A FLAT STROKE. That, and no movement at
        // all, is what reads as "pushed in" -- Windows does not translate a
        // pressed button by a pixel.
        readonly property color edgeTop: Qt.rgba(1, 1, 1, actionMouse.pressed ? Fluent.elevationRest : Fluent.elevationTop)
        readonly property color edgeRest: Qt.rgba(1, 1, 1, Fluent.elevationRest)

        anchors.right: parent.right
        anchors.rightMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: actionContent.implicitWidth + Fluent.controlPaddingH * 2
        implicitHeight: Fluent.controlHeight
        width: implicitWidth
        height: implicitHeight

        radius: Fluent.controlRadius

        gradient: Gradient {
            GradientStop { position: 0; color: action.edgeTop }
            GradientStop { position: action.edgeKnee; color: action.edgeTop }
            GradientStop { position: action.edgeEnd; color: action.edgeRest }
            GradientStop { position: 1; color: action.edgeRest }
        }

        // The button's own dim, and only the button's. See the header: this is
        // `actionEnabled` and not `enabled`, and the sentence beside it must
        // stay readable while whatever it started is running.
        opacity: root.row.actionEnabled ? 1 : Fluent.disabledOpacity

        // The fill, inside the 1px edge. THE INNER RADIUS IS THE OUTER ONE LESS
        // THE BORDER, which is the whole of why there is no 7 anywhere in
        // Windows 11: a 7 measured off a screenshot is an 8px outer arc with a
        // 1px stroke sitting inside it.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1

            radius: Fluent.controlRadius - 1
            color: actionMouse.pressed ? Fluent.fillPress : actionMouse.containsMouse ? Fluent.fillHover : Fluent.fillRest

            // A button is not a card and has no BrushTransition: Windows swaps
            // its brush on a DiscreteObjectKeyFrame at KeyTime 0. No Behavior
            // here on purpose.
        }

        Row {
            id: actionContent

            anchors.centerIn: parent
            spacing: Theme.itemSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.row.actionGlyph !== ""
                text: root.row.actionGlyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize - 1
                color: Theme.textOnSurface
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.row.actionText
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                font.weight: Fluent.normalWeight
                color: Theme.textOnSurface
            }
        }

        // THE ONLY MouseArea IN THIS FILE THAT TAKES A CLICK, and it is inside
        // the button. It reads `actionEnabled` rather than `enabled` because a
        // MouseArea does not follow the item tree, while event delivery to a
        // disabled ancestor's children stops anyway.
        MouseArea {
            id: actionMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.row.actionEnabled
            onClicked: root.row.triggered()
        }
    }
}
