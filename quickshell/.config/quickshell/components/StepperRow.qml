// A settings row that holds a number: glyph, label, and a minus/value/plus
// stepper.
//
// A STEPPER AND NOT A SLIDER. Both values this shell has to offer -- an
// opacity in whole percent and a timeout in whole seconds -- have a small
// number of useful positions and one number that matters. A slider hides that
// number behind a handle position, cannot be nudged by one, and needs a drag
// gesture to do what a click does here. Sliders earn their place over
// continuous ranges; these are not.
//
// Same contract as ToggleRow: it displays `value` and asks for a new one
// through the signal. It does not write anything itself.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property int value: 0
    property int from: 0
    property int to: 100
    property int step: 1
    // Shown after the number, e.g. "%" or " s". Part of the label rather than
    // of the value, so the arithmetic never has to parse it back out.
    property string suffix: ""

    // Shown INSTEAD of the number when it is set.
    //
    // FOR VALUES THAT ARE NOT READ AS NUMBERS. A time of day steps in half
    // hours and is stored as minutes since midnight, because that is the only
    // representation the arithmetic is simple in -- but "1230 min" is not a
    // time and nobody reading it would know what it meant. The stepper keeps
    // the range, the step and the clamping; only the few characters on screen
    // become the caller's.
    property string display: ""

    // Optional. A row with one grows an info glyph after its label, and the
    // note appears under it on hover. Empty means no glyph at all -- a mark
    // that is always there and usually says nothing trains the eye to skip
    // it.
    property string hint: ""

    signal moved(int value)

    // See the note in ToggleRow: the parent supplies the width.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius
    color: mouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    opacity: root.enabled ? 1 : 0.4

    function nudge(delta: int): void {
        const next = Math.max(root.from, Math.min(root.to, root.value + delta));
        if (next !== root.value)
            root.moved(next);
    }

    // Hover on the row, not only on the buttons: the row is one object and it
    // should light up as one. The MouseArea is behind the buttons and does
    // nothing on click -- unlike ToggleRow there is no single obvious action
    // for "clicked the label", and guessing one (increment? reset?) would be
    // worse than no target at all.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Item {
            id: hintMark

            anchors.verticalCenter: parent.verticalCenter
            visible: root.hint !== ""
            // A hit area larger than the glyph: at 13pt the mark itself is
            // about ten pixels across, which is a target you have to aim at.
            implicitWidth: Theme.groupHeight - 12
            implicitHeight: Theme.groupHeight - 12

            Text {
                anchors.centerIn: parent
                text: Icons.info
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: hintMouse.containsMouse ? Theme.primary : Theme.outline

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            MouseArea {
                id: hintMouse

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }
    }

    // Aligned with the label, NOT with the mark that opens it. Hanging it off
    // the mark is the obvious arrangement and it does not fit: the mark sits
    // after the label, two thirds of the way across a row that is itself most
    // of the pane's width, so a note wide enough to read would start there and
    // run off the right edge -- where the Flickable clips it. Aligned left it
    // is always inside, whatever the label says.
    //
    // The left margin is repeated from the Row above rather than measured off
    // it: mapToItem is not a binding, it is a function evaluated once, and
    // here that once is before anything has been laid out. It read 0 and the
    // note happened to land in the right place for the wrong reason.
    //
    // AND THAT SAME SENTENCE IS WHY THERE IS NO `y` HERE ANY MORE. This row
    // used to place the note at `root.height - 4`, unconditionally below, and
    // on the last row of a page with no scroll left the Flickable cut it in
    // half. The vertical decision is Tooltip's now: the band it must not
    // cover is this whole row, the -4 is the overlap that used to be written
    // into the y, and it hangs below or flips above depending on the room
    // left in the viewport -- reactively, which the y it replaced was not.
    Tooltip {
        text: root.hint
        shown: hintMouse.containsMouse

        x: Theme.groupPadding
        gap: -4
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding - 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StepperButton {
            anchors.verticalCenter: parent.verticalCenter
            // U+2212 MINUS SIGN, not the hyphen on the keyboard: at this size
            // a hyphen sits high and short next to the plus and the pair
            // stops looking like a pair.
            symbol: "−"
            enabled: root.enabled && root.value > root.from
            onTriggered: root.nudge(-root.step)
        }

        // FIXED WIDTH, because the number is between two buttons and both of
        // them would shift sideways every time it went from 9 to 10. Wide
        // enough for three digits plus the suffix.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignHCenter
            text: root.display !== "" ? root.display : `${root.value}${root.suffix}`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Font.Bold
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        StepperButton {
            anchors.verticalCenter: parent.verticalCenter
            symbol: "+"
            enabled: root.enabled && root.value < root.to
            onTriggered: root.nudge(root.step)
        }
    }
}
