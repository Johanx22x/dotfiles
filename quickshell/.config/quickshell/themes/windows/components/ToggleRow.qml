// How the windows theme draws a settings toggle: a SettingsCard with a
// ToggleSwitch in its content slot. The public half -- what the pages write,
// what `checked` means, why the whole row is the target -- is
// components/ToggleRow.qml.
//
// IT IS A CARD AND NOT A ROW, which is the first thing that is different from
// genesis. Genesis draws a transparent strip that borrows the section's
// surface; Windows draws every settings row as its own SettingsCard --
// 68 tall, 16 all round, radius 4, a 1px stroke, and its own fill. Cards STACK
// WITH A GAP and stay fully rounded; they do not join. The top-rounds/
// middle-squares arrangement exists only inside a SettingsExpander, which this
// shell has no facade for.
//
// THIS IS THE CLICKABLE CARD, and that matters more than it looks. In
// SettingsCard.cs the pointer handlers are subscribed by
// EnableButtonInteraction(), which is only called when IsClickEnabled is true,
// and OnPointerPressed is gated on the same flag -- so a settings card with
// nothing to click DOES NOT HIGHLIGHT AT ALL. This one does, because the whole
// row IS the target: that is the promise components/ToggleRow.qml's header
// makes and only this file can keep. components/InfoRow.qml is the other side
// of the same coin and its implementation in this directory has no MouseArea
// at all.
//
// THE FILL IS THE ONE THING THAT ANIMATES, and it is the one place this theme
// is allowed to fade a hover. Fluent.hoverMs is 0 because Windows swaps a
// control's brush on a DiscreteObjectKeyFrame at time zero -- but SettingsCard
// declares `<win:Grid.BackgroundTransition><win:BrushTransition
// Duration="0:0:0.083"/>` on PART_RootGrid, so the card's BACKGROUND, and only
// its background, crosses over 83ms. The border brush is outside that
// transition and snaps, which is why there is no Behavior on it below.
//
// IT READS `row` AND NEVER WRITES TO IT. `row.checked` is the value the page
// handed down; the click calls `row.toggled(...)` to ask for a new one. See
// themes/genesis/components/README.md for why writing `row.checked = value`
// here would be the same bug as writing to Config from inside a row.

import QtQuick
import qs
import qs.components
import ".."

Rectangle {
    id: root

    // THE FACADE, HANDED IN BY ITS LOADER AS AN INITIAL PROPERTY, AND TYPED.
    // `ToggleRow` here is components/ToggleRow.qml and not this file: the
    // explicit `import qs.components` beats the implicit import of a document's
    // own directory. See rule 1 in themes/genesis/components/README.md for what
    // the type buys and what `property var row` would throw away.
    required property ToggleRow row

    // WHAT THE FACADE READS BACK. SettingsCardMinHeight is 68 and the padding
    // is 16 top and bottom, so a card is 68 tall until its header wraps past
    // 36 -- at which point the text decides, not the constant. The facade
    // floors the same number at Theme.groupHeight, which is smaller; that floor
    // is about a theme that reported nothing, not about this arithmetic.
    implicitHeight: Math.max(Fluent.cardMinHeight, headerText.implicitHeight + Fluent.cardPadding * 2)

    radius: Fluent.controlRadius

    // Hover BRIGHTENS and press DIMS: ControlFillColorSecondary over
    // ControlFillColorTertiary, and the pressed fill is darker than the resting
    // one. Getting that the other way round is the second-best tell after
    // animating the hover.
    color: mouse.pressed ? Fluent.fillPress : mouse.containsMouse ? Fluent.fillHover : Fluent.fillRest

    // CardStrokeColorDefault at rest. Windows swaps this for the lit
    // ControlElevationBorderBrush on hover and for a flat
    // ControlStrokeColorDefault on press; both are a hair's difference against
    // a fill that has already moved a whole level, and neither is inside the
    // BrushTransition above. The one that carries the state is the fill.
    border.width: 1
    border.color: Theme.outlineVariant

    Behavior on color {
        ColorAnimation {
            duration: Fluent.fasterMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Fluent.easeOut
        }
    }

    // The dim is drawing and it lives here; `enabled` itself is Qt's effective
    // value, computed down the item tree from the page through the facade's
    // Loader to this root, so six call sites keep working with nothing
    // forwarded by hand. The MouseArea at the bottom is the exception and
    // still says so explicitly -- see rule 6 in
    // themes/genesis/components/README.md, where that is measured.
    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // ---------------- The header: icon, then words ----------------
    //
    // SettingsCardHeaderIconMargin is "2,0,20,0" -- the icon column is 20 wide
    // at most and the gap to the words is 20. The 2px left nudge is not carried
    // here: it exists to centre a vector icon inside a Viewbox, and this shell
    // draws a font glyph, which has its own side bearings.
    Item {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        visible: root.row.glyph !== ""
        width: root.row.glyph !== "" ? Fluent.cardIconMax : 0
        height: Fluent.cardIconMax

        // THE 20 IS A BOX AND NOT A FONT SIZE. Windows bounds the header icon
        // with a Viewbox that scales a vector down to fit; a glyph out of a
        // text font cannot be scaled that way, so what is honoured here is the
        // column the icon occupies. The glyph itself is drawn at the host's own
        // icon size, which is what every other component in this shell does.
        Text {
            anchors.centerIn: parent

            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            // SettingsCard's Foreground is TextFillColorPrimary and the header
            // icon inherits it, so the glyph is WHITE and not muted -- genesis
            // mutes it and Windows does not. Pressed takes both the glyph and
            // the words down to TextFillColorSecondary.
            color: mouse.pressed ? Theme.textOnSurfaceVariant : Theme.textOnSurface
        }
    }

    // 14 at Normal weight. SettingsCard sets `FontWeight Normal` outright, so
    // this is one of the few places the theme does NOT reach for
    // Theme.fontWeight: Windows' emphasis rule is Semibold and never Bold, and
    // a settings card header is not emphasis.
    Text {
        id: headerText

        anchors.left: mark.right
        anchors.leftMargin: root.row.glyph !== "" ? Fluent.cardIconGap : 0
        anchors.right: track.left
        anchors.rightMargin: Fluent.cardActionGutter
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        color: mouse.pressed ? Theme.textOnSurfaceVariant : Theme.textOnSurface
    }

    // ---------------- The ToggleSwitch ----------------
    //
    // 40x20 at radius 10, thumb 12 at rest, 14 on hover and 17 WIDE BY 14 TALL
    // when pressed -- it squishes wider, not taller -- travelling 20. Every one
    // of those is in Fluent.qml, read out of ToggleSwitch_themeresources.xaml.
    //
    // Hand-built rather than QtQuick.Controls' Switch: nothing else in this
    // shell imports Controls, and a Controls widget arrives with its own style,
    // its own metrics and its own idea of the palette, none of which are
    // Theme's.
    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.rightMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.switchTrackWidth
        height: Fluent.switchTrackHeight
        radius: height / 2

        // ToggleSwitchFillOn is AccentFillColorDefault. Off is
        // ControlAltFillColorSecondary, which is BLACK at 10% -- a fill darker
        // than the ground, not a lighter one. Theme.surface is the darkest
        // level the scheme publishes and is what carries that here.
        color: root.row.checked ? Theme.primary : Theme.surface

        // ToggleSwitchOuterBorderStrokeThickness is 1 and
        // ToggleSwitchOnStrokeThickness is 0: the track loses its stroke
        // ENTIRELY when it switches on, rather than taking the accent for it.
        border.width: root.row.checked ? 0 : 1
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Fluent.fasterMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Fluent.easeOut
            }
        }

        Rectangle {
            id: thumb

            // THE TRAVEL IS ITS OWN PROPERTY AND THE X IS A PURE BINDING, which
            // is not a flourish. The thumb changes width under the pointer, so
            // an `x` with a Behavior on it would be re-targeted every frame of
            // the resize and would lag behind its own arithmetic. Animating the
            // slide and deriving x from it keeps the two independent.
            //
            // The rest position's centre is exactly half the track height: the
            // 4px inset plus half of a 12px thumb is 10, and 10 is 20/2.
            property real slide: root.row.checked ? Fluent.switchTravel : 0

            width: mouse.pressed ? Fluent.switchThumbPressWidth : mouse.containsMouse ? Fluent.switchThumbHover : Fluent.switchThumbRest
            height: mouse.pressed ? Fluent.switchThumbPressHeight : mouse.containsMouse ? Fluent.switchThumbHover : Fluent.switchThumbRest
            radius: height / 2

            x: Fluent.switchTrackHeight / 2 + thumb.slide - thumb.width / 2
            anchors.verticalCenter: parent.verticalCenter

            // TextOnAccentFillColorPrimary IS BLACK IN DARK MODE, because dark
            // mode's accent is the LIGHT shade of the accent ramp. The knob
            // turning black when the switch comes on looks wrong until it is
            // seen beside the real thing; it is not a mistake and it must not
            // be "fixed" to white. Off is TextFillColorSecondary.
            color: root.row.checked ? Theme.textOnPrimary : Theme.textOnSurfaceVariant

            // THE RESIZE IS 83ms AND SO IS THE SLIDE, and only the first of
            // those is a published number. Every SplineDoubleKeyFrame that
            // moves the knob's width and height in ToggleSwitch_themeresources
            // .xaml is at ControlFasterAnimationDuration on
            // ControlFastOutSlowInKeySpline. The slide is a
            // RepositionThemeAnimation, whose duration lives in the system
            // theme animations rather than in that file, so it is matched to
            // the crossfade beside it instead of being invented.
            Behavior on slide {
                NumberAnimation {
                    duration: Fluent.fasterMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Fluent.easeOut
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Fluent.fasterMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Fluent.easeOut
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Fluent.fasterMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Fluent.easeOut
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Fluent.fasterMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Fluent.easeOut
                }
            }
        }
    }

    // THE WHOLE ROW, and that is the promise the facade's header makes and this
    // file keeps. A theme that put this MouseArea on `track` instead would pass
    // every check in tests/ and would shrink the target from a 320-pixel row to
    // a 40-pixel pill.
    //
    // `enabled` is forwarded by hand because MouseArea.enabled is a flag of its
    // own and does not follow the item tree -- measured, and written up as
    // rule 6 in themes/genesis/components/README.md.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.row.toggled(!root.row.checked)
    }
}
