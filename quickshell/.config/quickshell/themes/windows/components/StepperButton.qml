// How genesis draws the round minus / plus of a stepper. The public half --
// what the rows write, and the repeat that makes a stepper usable at all -- is
// components/StepperButton.qml.
//
// THE PROMISE THIS FILE KEEPS IS THAT IT FIRES ON PRESS. `onPressed` calls
// down, `onReleased` and `onCanceled` call back, and the facade does the rest.
// A theme that wired `onClicked` here instead would compile, load, pass every
// check in tests/, and quietly lose two things at once: the first step would
// land on release instead of under the finger, and the hold would never start,
// because nothing would ever have told the facade the pointer went down. That
// is the sentence rule 7 of README.md in this directory is about, and this is
// where it has to live now.
//
// AND IT NEVER REIMPLEMENTS THE REPEAT. No Timer belongs in this file. The 400
// and the 60 are in the facade, with the guard for a button that disables
// itself while it is still being held -- a case this side cannot even see,
// because a MouseArea that has gone disabled mid-hold sends no release.
//
// THE ROOT IS A Rectangle AND THE FACADE'S IS AN Item: `radius` and the two
// fills are the reasons this was ever a Rectangle and all three are drawing.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `StepperButton` here is the facade and
    // not this file.
    required property StepperButton row

    // WHAT THE FACADE READS BACK, AND HERE IT IS A PAIR. This is the one
    // component in this directory that reports a width as well as a height,
    // and the facade's header says why that is not a breach of rule 2: a
    // button in a Row has no parent width to take, so its own is the only one
    // there is. Both are constants, which is what keeps it out of a loop --
    // neither is derived from the size the Loader handed this item.
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
    //
    // Against `root.enabled` and not `row.enabled`, which is rule 6: this is
    // Qt's effective-enabled, computed down the tree from the facade through
    // its Loader to here, and it is the one that stays right when something
    // between the page and this button is disabled.
    opacity: root.enabled ? 1 : 0.3

    Text {
        anchors.centerIn: parent
        text: root.row.symbol
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

        // Forwarded by hand, because MouseArea.enabled is a flag of its own
        // and does not follow the item tree the way the opacity above does.
        // Rule 6 in README.md measures that; it is the opposite of what it
        // looks like.
        enabled: root.enabled

        // ON PRESS, NOT ON CLICK. See the top of this file.
        onPressed: root.row.press()

        // BOTH, and they say the same thing. A release is the finger coming
        // up; a cancel is the grab being taken away by something above --
        // a Flickable deciding the gesture was a scroll, a popout closing.
        // The timers have to stop for either, and the facade has nothing to
        // tell them apart by, which is why there is one function and not two.
        onReleased: root.row.release()
        onCanceled: root.row.release()
    }
}
