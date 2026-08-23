// How genesis draws a number: glyph, label, and a minus/value/plus stepper.
// The public half -- what the pages write, why this is a stepper and not a
// slider, and what a step is allowed to produce -- is
// components/StepperRow.qml, and this file is everything that was below those
// comments before the split, moved unchanged.
//
// IT ASKS FOR THE STEP, IT DOES NOT TAKE IT. The two buttons call
// `row.nudge(-row.step)` and `row.nudge(row.step)` and nothing here adds,
// clamps or compares. That is the facade's rule and the reason it stayed there
// is in its header; what this file must not do is arrive at a new value by
// itself.
//
// THE ROW LIGHTS UP AND THE ROW DOES NOT ANSWER, which is the promise this
// theme keeps and no test can. The hover MouseArea covers the whole row,
// because the row is one object and should light up as one -- but it accepts
// no buttons. Unlike ToggleRow there is no single obvious action for "clicked
// the label", and guessing one -- increment? reset? -- would be worse than no
// target at all. A theme that made the row clickable would pass every check in
// tests/ and would give this control a meaning the pages never asked for.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `StepperRow` here is the facade and not
    // this file.
    required property StepperRow row

    // WHAT THE FACADE READS BACK. A stepper of this theme is one line tall,
    // always -- the label and the buttons sit side by side -- so the facade
    // floors at the same number and this is what the row was before the split
    // rather than a second opinion about it.
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius
    color: mouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    // The dim is drawing and it lives here; `enabled` itself arrives down the
    // item tree with nothing forwarded by hand -- four call sites set it. See
    // rule 6 in README.md, including why the StepperButtons below still name
    // `root.enabled` explicitly.
    opacity: root.enabled ? 1 : 0.4

    // Hover on the row, not only on the buttons: the row is one object and it
    // should light up as one. The MouseArea is behind the buttons and does
    // nothing on click -- see the header.
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
            visible: root.row.glyph !== ""
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.row.label
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
            visible: root.row.hint !== ""
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
    //
    // Tooltip is still the host's component and not a themed one -- it has not
    // been split, and until it is, this instantiates components/Tooltip.qml.
    // The extra Loader between this item and the row changes nothing it
    // depends on: Tooltip sums `y` up the parent chain to whatever ancestor
    // clips, and both of the items the split inserted sit at y=0.
    Tooltip {
        text: root.row.hint
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
            enabled: root.enabled && root.row.value > root.row.from
            onTriggered: root.row.nudge(-root.row.step)
        }

        // A FLOOR, NOT A FIXED WIDTH. The number sits between two buttons and
        // both of them would shift sideways every time it went from 9 to 10, so
        // it holds a width rather than hugging its text. Fifty-two is what three
        // digits and a short suffix need, and it is what every row here used to
        // be given outright.
        //
        // OUTRIGHT WAS WRONG the first time a suffix was longer than " px". The
        // recording page asks for " Mbit/s", and `40 Mbit/s` is nine characters
        // in a box built for six: it overflowed in both directions at once and
        // was drawn straight through the minus and the plus, which is how it was
        // noticed. Growing past the floor moves the buttons apart on that row
        // and nowhere else -- the jitter this guards against is between one
        // value and the next, not between one row and another.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(52, implicitWidth)
            horizontalAlignment: Text.AlignHCenter
            text: root.row.display !== "" ? root.row.display : `${root.row.value}${root.row.suffix}`
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
            enabled: root.enabled && root.row.value < root.row.to
            onTriggered: root.row.nudge(root.row.step)
        }
    }
}
