// How genesis draws a value stepped out of a list: glyph, label, and a
// chevron/value/chevron stepper. The public half -- the two call sites, why
// this is not StepperRow and not ListRow, and why the facade stayed under
// pages/display/ -- is modules/settings/pages/display/CycleRow.qml, and this
// file is everything that was below those comments before the split, moved
// unchanged.
//
// THE ROW LIGHTS UP AND THE ROW DOES NOT ANSWER, which is the promise this
// theme keeps and no test can. The hover MouseArea covers the whole row,
// because the row is one object and should light up as one -- but it accepts no
// buttons. There is no obvious single action for "clicked the label", and
// inventing one -- step forward? -- would be a control nobody asked for. A
// theme that made the row clickable would pass every check in tests/ and would
// give this control a meaning the cards never asked for. It is the same promise
// this directory's StepperRow.qml keeps, in the same words, and rule 7 in
// README.md is why it is written here rather than only remembered.
//
// IT ASKS FOR A DIRECTION AND NOT FOR A VALUE. The two chevrons call
// `row.stepped(-1)` and `row.stepped(1)`; the list, the wrapping and the new
// value are the card's. Nothing here indexes anything.

import QtQuick
import qs
import qs.components
// CycleRow is modules/settings/pages/display/CycleRow.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings.pages.display

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `CycleRow` here is the facade and not
    // this file.
    required property CycleRow row

    // WHAT THE FACADE READS BACK. A cycle row of this theme is one line tall,
    // always -- the label and the stepper sit side by side -- so the facade
    // floors at the same number and this is what the row was before the split
    // rather than a second opinion about it.
    implicitHeight: Theme.groupHeight

    radius: Theme.groupRadius
    color: cycleMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    // The dim is drawing and it lives here; `enabled` itself arrives down the
    // item tree with nothing forwarded by hand -- both call sites set it. See
    // rule 6 in README.md, including why the StepperButtons below still name
    // `root.enabled` explicitly.
    opacity: root.enabled ? 1 : 0.4

    // Hover on the whole row, like StepperRow: the row is one object and
    // lights up as one. It takes no clicks -- see the header.
    MouseArea {
        id: cycleMouse

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
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding - 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StepperButton {
            anchors.verticalCenter: parent.verticalCenter
            symbol: Icons.chevronLeft
            enabled: root.enabled
            onTriggered: root.row.stepped(-1)
        }

        // FIXED WIDTH, for the reason StepperRow's number is: the buttons
        // sit either side of it, and without this they would jump every
        // time the text went from "800 × 600 · 60 Hz" to
        // "2560 × 1440 · 165 Hz".
        //
        // OUTRIGHT AND NOT A FLOOR, where StepperRow's number is a floor. That
        // difference is not an oversight either way: a stepper's suffix can be
        // longer than its box and growing moves two buttons on one row, while
        // everything this row ever holds is a mode line or a scale and the
        // longest of them fits. A mode longer than 168 pixels elides; it does
        // not push the chevrons apart.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 168
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight

            text: root.row.value
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            font.weight: Font.Bold
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        StepperButton {
            anchors.verticalCenter: parent.verticalCenter
            symbol: Icons.chevronRight
            enabled: root.enabled
            onTriggered: root.row.stepped(1)
        }
    }
}
