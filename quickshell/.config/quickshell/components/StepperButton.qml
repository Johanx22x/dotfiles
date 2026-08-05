// The round minus / plus of a StepperRow.
//
// It repeats while held, which is what makes a stepper usable over a range
// worth stepping through: 400ms before the first repeat -- long enough that a
// deliberate single click never triggers one -- and 60ms between them after
// that.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property string symbol: ""

    signal triggered

    implicitWidth: 26
    implicitHeight: 26
    radius: height / 2

    color: mouse.pressed && root.enabled ? Theme.primary
        : mouse.containsMouse && root.enabled ? Theme.surfaceContainerHighest
        : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    // Disabled means the value is already at the end of its range. Dimmed
    // rather than hidden: a button that disappears takes the other one with
    // it sideways, and the row would twitch at both ends of the range.
    opacity: root.enabled ? 1 : 0.3

    Text {
        anchors.centerIn: parent
        text: root.symbol
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Font.Bold
        color: mouse.pressed && root.enabled ? Theme.textOnPrimary : Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled

        // On press and not on click, so the first step lands under the finger
        // rather than on release, and so the hold below continues from it.
        onPressed: {
            root.triggered();
            repeatDelay.restart();
        }

        onReleased: {
            repeatDelay.stop();
            repeat.stop();
        }

        onCanceled: {
            repeatDelay.stop();
            repeat.stop();
        }
    }

    Timer {
        id: repeatDelay
        interval: 400
        onTriggered: repeat.start()
    }

    Timer {
        id: repeat
        interval: 60
        repeat: true
        // The button disables itself when the value reaches the end of the
        // range, but a Timer already running does not stop for that -- and
        // the released handler never arrives if the pointer is still down.
        onTriggered: {
            if (!root.enabled) {
                repeat.stop();
                return;
            }
            root.triggered();
        }
    }
}
