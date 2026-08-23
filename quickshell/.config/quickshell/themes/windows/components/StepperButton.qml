// THE SPIN BUTTON OF A STEPPER.
//
// A SUBTLE BUTTON, which is Windows' name for the shape with no fill and no
// border until the pointer arrives: transparent at rest,
// ControlFillColorSecondary under the pointer, and DARKER again while it is
// held. That last one is the tell -- hover brightens and press dims, and
// getting the pair backwards is the second-fastest way to give a Fluent
// recreation away.
//
// 32 SQUARE, from ControlHeight, over the facade's floor of 26. A NumberBox's
// inline spin buttons are the height of the box they sit in, and the box is a
// control.
//
// IT FIRES ON PRESS AND THE HOST OWNS THE REPEAT. `row.press()` starts the
// hold -- one step immediately, 400ms before the first repeat, 60ms between
// them after that -- and `row.release()` ends it. Both of those numbers are
// the host's on purpose: they are the difference between a control that feels
// like a held key and one that runs away from you, and a theme that wired
// `onClicked` instead would pass every check in tests/ while losing the first
// step under the finger AND the whole hold.
//
// RELEASE IS ANSWERED TWICE, onReleased AND onCanceled, and the second one is
// not defensive. A press that ends because the Flickable under this row took
// the grab away never emits `released` -- the timers would keep firing with
// nothing holding them.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property StepperButton row

    implicitWidth: Fluent.controlHeight
    implicitHeight: Fluent.controlHeight

    Rectangle {
        anchors.fill: parent

        radius: Fluent.controlRadius
        opacity: root.row.enabled ? 1 : Fluent.disabledOpacity

        color: {
            if (pointer.pressed)
                return Fluent.fillPress;
            if (pointer.containsMouse)
                return Fluent.fillSubtleHover;
            return "transparent";
        }

        Text {
            anchors.centerIn: parent

            text: root.row.symbol
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSmallSize
            color: Theme.textOnSurface
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            enabled: root.row.enabled

            onPressed: root.row.press()
            onReleased: root.row.release()
            onCanceled: root.row.release()
        }
    }
}
