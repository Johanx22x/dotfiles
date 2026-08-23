// How the windows theme draws a value stepped out of a list: a SettingsCard
// with a chevron / value / chevron in its content slot. The public half -- the
// two call sites, why this is not StepperRow and not ListRow, and why the
// facade stayed under pages/display/ -- is
// modules/settings/pages/display/CycleRow.qml.
//
// IT ASKS FOR A DIRECTION AND NOT FOR A VALUE. The two chevrons call
// `row.stepped(-1)` and `row.stepped(1)`; the list, the wrapping and the new
// value are the card's. Nothing here indexes anything, and `stepped` carries a
// direction rather than a position -- both call sites wrap rather than clamp,
// for the reason written beside the Mode row in MonitorCard.qml.
//
// THE CARD LIGHTS UP AND THE CARD DOES NOT ANSWER, which is the promise this
// theme keeps and no test can. The hover MouseArea covers the whole card,
// because a settings card is one object and lights up as one -- but it accepts
// no buttons. There is no obvious single action for "clicked the label", and
// inventing one -- step forward? -- would be a control nobody asked for. It is
// the same promise this directory's StepperRow.qml keeps, in the same words.
//
// AND THERE IS NO PRESSED FILL, for the same reason there is none there:
// SettingsCard's Pressed state is gated on IsClickEnabled exactly as its
// PointerOver state is, and a card that cannot be clicked never enters it.

import QtQuick
import qs
import qs.components
// CycleRow is modules/settings/pages/display/CycleRow.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings.pages.display
import ".."

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `CycleRow` here is the facade and not
    // this file.
    required property CycleRow row

    // SettingsCardContentMinWidth, verbatim from SettingsCard.xaml, where it is
    // applied to every Slider, ComboBox and TextBox a card holds so that the
    // right-hand controls of a stack of cards line up with each other. See
    // StepperRow.qml in this directory, which carries the same number for the
    // same reason.
    readonly property int contentMinWidth: 120

    // WHAT THE FACADE READS BACK. 68 is SettingsCardMinHeight and the 32 is the
    // card's padding, top and bottom. A cycle row of this theme is one storey
    // -- the label and the chevrons sit side by side.
    implicitHeight: Math.max(Fluent.cardMinHeight, headerText.implicitHeight + Fluent.cardPadding * 2)

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
    // item tree with nothing forwarded by hand -- both call sites set it. See
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

    // 14 at Normal weight: SettingsCard sets `FontWeight Normal` outright, and
    // Windows keeps Semibold for emphasis. The 24 on the right is HeaderPanel's
    // own Margin="0,0,24,0".
    Text {
        id: headerText

        anchors.left: mark.right
        anchors.leftMargin: root.row.glyph !== "" ? Fluent.cardIconGap : 0
        anchors.right: stepper.left
        anchors.rightMargin: Fluent.cardActionGutter
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        color: Theme.textOnSurface
    }

    // ---------------- The stepper ----------------
    //
    // The two chevrons are StepperButton, which is its own component with its
    // own facade: the 400ms-then-60ms repeat while held lives there and a theme
    // that reimplemented it would be guessing at two numbers that were arrived
    // at by holding the thing.
    Row {
        id: stepper

        anchors.right: parent.right
        anchors.rightMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        spacing: Theme.itemSpacing

        StepperButton {
            id: back

            anchors.verticalCenter: parent.verticalCenter
            symbol: Icons.chevronLeft
            enabled: root.enabled
            onTriggered: root.row.stepped(-1)
        }

        // OUTRIGHT AND NOT A FLOOR, where StepperRow's number is a floor. That
        // difference is not an oversight either way: a stepper's suffix can be
        // longer than its box and growing moves two buttons on one card, while
        // everything this row ever holds is a mode line or a scale. A mode
        // longer than the box elides; it does not push the chevrons apart.
        //
        // The width is what is left of SettingsCardContentMinWidth once the two
        // buttons and the two gaps are taken out of it, which is how a stack of
        // these cards ends up with its controls in a column.
        Text {
            anchors.verticalCenter: parent.verticalCenter

            width: root.contentMinWidth - back.width - forward.width - stepper.spacing * 2
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight

            text: root.row.value
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            // Normal, and never Bold: Windows 11's typography rule is Semibold
            // for emphasis and nothing heavier, and the value in a stepper is
            // not emphasis.
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }

        StepperButton {
            id: forward

            anchors.verticalCenter: parent.verticalCenter
            symbol: Icons.chevronRight
            enabled: root.enabled
            onTriggered: root.row.stepped(1)
        }
    }
}
