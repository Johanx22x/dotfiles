// How the windows theme draws a number: a SettingsCard with a minus / value /
// plus in its content slot. The public half -- what the pages write, why this
// is a stepper and not a slider, and what a step is allowed to produce -- is
// components/StepperRow.qml.
//
// IT ASKS FOR THE STEP, IT DOES NOT TAKE IT. The two buttons call
// `row.nudge(-row.step)` and `row.nudge(row.step)` and nothing here adds,
// clamps or compares. That is the facade's rule: nudge() is where "inside the
// range, and silent when the value would not move" lives, and a theme that did
// the arithmetic for itself could emit `moved` with the value the row already
// has -- a write to Config for no change -- or one outside [from, to].
//
// THE CARD LIGHTS UP AND THE CARD DOES NOT ANSWER, which is the promise this
// theme keeps and no test can. The hover MouseArea covers the whole card,
// because a settings card is one object and lights up as one -- but it accepts
// no buttons. There is no single obvious action for "clicked the label", and
// guessing one -- increment? reset? -- would be worse than no target at all. A
// theme that made the card clickable would pass every check in tests/ and would
// give this control a meaning the pages never asked for.
//
// AND THAT IS ALSO WHY THERE IS NO PRESSED FILL HERE. SettingsCard's Pressed
// visual state is gated on IsClickEnabled in exactly the way its PointerOver
// state is; a card that cannot be clicked never enters it. Hover, and only
// hover, is what this card has.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `StepperRow` here is the facade and not
    // this file.
    required property StepperRow row

    // SettingsCardContentMinWidth, verbatim from SettingsCard.xaml, where it is
    // applied to every Slider, ComboBox and TextBox a card holds so that the
    // right-hand controls of a stack of cards line up with each other. It is
    // Microsoft's number and not ours; it is here rather than in Fluent.qml
    // only because the two files that need it are both in this directory.
    readonly property int contentMinWidth: 120

    // WHAT THE FACADE READS BACK. 68 is SettingsCardMinHeight and the 32 is the
    // card's padding, top and bottom. A stepper of this theme is one storey --
    // the label and the buttons sit side by side -- so this is the floor until
    // a label wraps past it.
    implicitHeight: Math.max(Fluent.cardMinHeight, header.implicitHeight + Fluent.cardPadding * 2)

    radius: Fluent.controlRadius
    color: mouse.containsMouse ? Fluent.fillHover : Fluent.fillRest

    border.width: 1
    border.color: Theme.outlineVariant

    // SettingsCard's own transition and the only animation in this file:
    // `<win:BrushTransition Duration="0:0:0.083" />` on PART_RootGrid's
    // background. Fluent.hoverMs is 0 for everything else on purpose.
    Behavior on color {
        ColorAnimation {
            duration: Fluent.fasterMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Fluent.easeOut
        }
    }

    // The dim is drawing and it lives here; `enabled` itself arrives down the
    // item tree with nothing forwarded by hand -- four call sites set it. See
    // rule 6 in themes/genesis/components/README.md, including why the
    // StepperButtons below still name `root.enabled` explicitly.
    opacity: root.enabled ? 1 : Fluent.disabledOpacity

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

    Row {
        id: header

        anchors.left: mark.right
        anchors.leftMargin: root.row.glyph !== "" ? Fluent.cardIconGap : 0
        anchors.right: stepper.left
        // HeaderPanel's own Margin="0,0,24,0": the gutter Windows keeps in
        // front of a card's content whatever the content turns out to be.
        anchors.rightMargin: Fluent.cardActionGutter
        anchors.verticalCenter: parent.verticalCenter

        spacing: Theme.itemSpacing

        // 14 at Normal weight. SettingsCard sets `FontWeight Normal` outright,
        // so this is one of the places the theme does NOT reach for
        // Theme.fontWeight: Windows keeps Semibold for emphasis, and a settings
        // card header is not emphasis.
        //
        // IT ELIDES RATHER THAN WRAPPING, unlike InfoRow's, and the reason is
        // the mark beside it: a wrapped label would take the info glyph down to
        // the second line and away from the words it belongs to.
        Text {
            id: headerText

            anchors.verticalCenter: parent.verticalCenter

            width: Math.min(implicitWidth, header.width - (hintMark.visible ? hintMark.width + header.spacing : 0))
            elide: Text.ElideRight

            text: root.row.label
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }

        // A hit area larger than the glyph: the mark itself is about ten pixels
        // across, which is a target you have to aim at. 20 is the header icon
        // column, reused here so the two marks on one card agree.
        Item {
            id: hintMark

            anchors.verticalCenter: parent.verticalCenter

            visible: root.row.hint !== ""
            width: Fluent.cardIconMax
            height: Fluent.cardIconMax

            Text {
                anchors.centerIn: parent

                text: Icons.info
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                // TextFillColorTertiary at rest, the accent under the pointer.
                // Instant, like every other hover in Windows.
                color: hintMouse.containsMouse ? Theme.primary : Theme.outline
            }

            MouseArea {
                id: hintMouse

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }
    }

    // Aligned with the card's own padding, NOT with the mark that opens it.
    // Hanging it off the mark is the obvious arrangement and it does not fit:
    // the mark sits after the label, most of the way across a card that is
    // itself most of the pane's width, so a note wide enough to read would
    // start there and run off the right edge -- where the Flickable clips it.
    //
    // The vertical decision is Tooltip's: the band it must not cover is this
    // whole card, and it hangs below or flips above depending on the room left
    // in the viewport.
    Tooltip {
        text: root.row.hint
        shown: hintMouse.containsMouse

        x: Fluent.cardPadding
        z: 200
    }

    // ---------------- The stepper ----------------
    //
    // The minus and the plus are StepperButton, which is its own component with
    // its own facade: the 400ms-then-60ms repeat while held lives there and a
    // theme that reimplemented it would be guessing at two numbers that were
    // arrived at by holding the thing.
    Row {
        id: stepper

        anchors.right: parent.right
        anchors.rightMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        spacing: Theme.itemSpacing

        StepperButton {
            id: minus

            anchors.verticalCenter: parent.verticalCenter
            // U+2212 MINUS SIGN, not the hyphen on the keyboard: at this size a
            // hyphen sits high and short next to the plus and the pair stops
            // looking like a pair.
            symbol: "−"
            enabled: root.enabled && root.row.value > root.row.from
            onTriggered: root.row.nudge(-root.row.step)
        }

        // A FLOOR, NOT A FIXED WIDTH. The number sits between two buttons and
        // both of them would shift sideways every time it went from 9 to 10, so
        // it holds a width rather than hugging its text. The floor is what is
        // left of SettingsCardContentMinWidth once the two buttons and the two
        // gaps are taken out of it, which is how a stack of these cards ends up
        // with its controls in a column.
        //
        // GROWING PAST IT IS DELIBERATE. The recording page asks for " Mbit/s",
        // and `40 Mbit/s` in a box built for three digits overflows in both
        // directions at once and draws straight through the minus and the plus.
        // The jitter the floor guards against is between one value and the
        // next, not between one card and another.
        Text {
            anchors.verticalCenter: parent.verticalCenter

            width: Math.max(root.contentMinWidth - minus.width - plus.width - stepper.spacing * 2, implicitWidth)
            horizontalAlignment: Text.AlignHCenter

            text: root.row.display !== "" ? root.row.display : `${root.row.value}${root.row.suffix}`
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            // Normal, and never Bold: Windows 11's typography rule is Semibold
            // for emphasis and nothing heavier, and the value in a stepper is
            // not emphasis -- it is the thing the control is about, which the
            // position of the box already says.
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }

        StepperButton {
            id: plus

            anchors.verticalCenter: parent.verticalCenter
            symbol: "+"
            enabled: root.enabled && root.row.value < root.row.to
            onTriggered: root.row.nudge(root.row.step)
        }
    }
}
