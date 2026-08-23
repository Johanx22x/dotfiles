// StepperButton, as the probe draws it: a square that goes green while it is
// held down.
//
// Both dimensions are reported and the facade floors both at 26. Rule 2's loop
// cannot form here: a stepper button is not a row and nothing above it takes
// its size from this.
//
// PRESS AND RELEASE, NOT CLICK. The facade's press()/release() pair is what
// drives the repeat, so `onCanceled` has to release as well -- a pointer that
// leaves the button while held would otherwise leave it repeating for ever.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property StepperButton row

    implicitWidth: 20
    implicitHeight: 20
    color: area.pressed ? "#00ff00" : "#00ffff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.centerIn: parent
        text: root.row.symbol
        color: "#000000"
        font.family: Theme.fontFamily
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: root.enabled
        onPressed: root.row.press()
        onReleased: root.row.release()
        onCanceled: root.row.release()
    }
}
