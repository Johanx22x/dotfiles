// A SETTINGS CARD WITH A TOGGLE SWITCH ON ITS RIGHT END.
//
// THE SWITCH IS WINDOWS' OWN AND ITS NUMBERS ARE NOT NEGOTIABLE: a track 40 by
// 20 at radius 10, and a knob that is 12 at rest, 14 under the pointer and 17
// BY 14 while it is held -- it squashes sideways rather than growing. All four
// are in Fluent.qml, read out of ToggleSwitch_themeresources.xaml.
//
// THE KNOB TURNS BLACK WHEN IT COMES ON, and it looks wrong until you see it
// beside the real thing. Dark mode's accent is SystemAccentColorLight2, a
// LIGHT blue, so the thing sitting on it has to be dark: Theme.textOnPrimary
// is #000000 under this scheme and that is the correct answer, not a bug to
// fix. Measured straight off ref/settings-touchpad-mica.png -- the knob's
// pixels there are (0,0,0).
//
// THE WORD BESIDE IT IS "On" OR "Off" and it belongs to Windows too: every
// toggle in the Settings app carries one, to the left of the track, and it is
// the only label in the row that is not the setting's own name.
//
// THE WHOLE CARD IS THE TARGET. A SettingsCard whose content is a ToggleSwitch
// is IsClickEnabled=false in the toolkit's own samples, but this shell's rows
// have always toggled from anywhere on the row and the facade's one signal
// says so -- so the card highlights and the card toggles, and the switch is
// drawn rather than wired.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property ToggleRow row

    implicitHeight: Math.max(Fluent.cardMinHeight, body.implicitHeight + 2 * Fluent.cardPadding)
        + 2 * Fluent.cardGapInset

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.topMargin: Fluent.cardGapInset
        anchors.bottomMargin: Fluent.cardGapInset

        radius: Fluent.controlRadius
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, Fluent.cardStrokeAlpha)
        opacity: root.row.enabled ? 1 : Fluent.disabledOpacity

        color: {
            if (pointer.pressed)
                return Fluent.fillPress;
            if (pointer.containsMouse)
                return Fluent.fillHover;
            return Fluent.fillRest;
        }

        // The one animation a card gets: SettingsCard's own visual states put a
        // transition at ControlFastAnimationDuration on the fill. Nothing else
        // in this theme fades a hover.
        Behavior on color {
            ColorAnimation { duration: Fluent.fasterMs }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            onClicked: root.row.toggled(!root.row.checked)
        }

        Text {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.cardIconMax
            horizontalAlignment: Text.AlignHCenter

            visible: root.row.glyph !== ""
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSize
            color: Theme.textOnSurface
        }

        Text {
            id: body

            anchors.left: parent.left
            anchors.leftMargin: Fluent.cardPadding + (root.row.glyph !== "" ? Fluent.cardIconMax + Fluent.cardIconGap : 0)
            anchors.right: word.left
            anchors.rightMargin: Fluent.cardActionGutter
            anchors.verticalCenter: parent.verticalCenter

            text: root.row.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            color: Theme.textOnSurface
        }

        Text {
            id: word

            anchors.right: track.left
            anchors.rightMargin: Fluent.switchLabelGap
            anchors.verticalCenter: parent.verticalCenter

            text: root.row.checked ? "On" : "Off"
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            color: Theme.textOnSurface
        }

        // ---------------- The switch ----------------
        Rectangle {
            id: track

            anchors.right: parent.right
            anchors.rightMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.switchTrackWidth
            height: Fluent.switchTrackHeight
            radius: height / 2

            // ON HAS NO STROKE AT ALL and off is a stroke around a subtle
            // fill, which is the pair the XAML ships: ToggleSwitchStrokeOn is
            // zero-thickness and ToggleSwitchFillOff is the alt fill.
            color: root.row.checked ? Theme.primary : Theme.surfaceContainerHighest
            border.width: root.row.checked ? 0 : 1
            border.color: Theme.outline

            Rectangle {
                id: knob

                // The knob grows IN PLACE: its centre travels and its size
                // changes around that centre, which is why this is written as
                // a centre and two half-sizes rather than as an x.
                readonly property real centre: root.row.checked
                    ? track.width - Fluent.switchTrackHeight / 2
                    : Fluent.switchTrackHeight / 2

                x: knob.centre - width / 2
                anchors.verticalCenter: parent.verticalCenter

                width: {
                    if (pointer.pressed)
                        return Fluent.switchThumbPressWidth;
                    if (pointer.containsMouse)
                        return Fluent.switchThumbHover;
                    return Fluent.switchThumbRest;
                }
                height: pointer.pressed || pointer.containsMouse
                    ? Fluent.switchThumbHover
                    : Fluent.switchThumbRest
                radius: height / 2

                // BLACK ON THE ACCENT. See the header.
                color: root.row.checked ? Theme.textOnPrimary : Theme.textOnSurface

                Behavior on x {
                    NumberAnimation {
                        duration: Fluent.fastMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Fluent.easeOut
                    }
                }
            }
        }
    }
}
