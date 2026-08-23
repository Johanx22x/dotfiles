// How the windows theme draws the minus / plus of a stepper: a NumberBox spin
// button. The public half -- what the rows write, and the repeat that makes a
// stepper usable at all -- is components/StepperButton.qml.
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
// ---------------------------------------------------------------------------
// A BOX AND NOT A CIRCLE, AND ITS TOP EDGE IS SOMEBODY ELSE'S
// ---------------------------------------------------------------------------
//
// genesis draws a 26px circle. Windows' NumberBox spin buttons are rectangles
// that butt against the field they belong to: square corners, a glyph at 12,
// and `NumberBoxSpinButtonBorderThickness = 1,0,1,1` -- left, right and bottom,
// and NOTHING ALONG THE TOP, because the top edge is the edge of whatever the
// button is hanging under. That asymmetry is the whole shape, so it is drawn as
// three lines rather than as a `border` that would put a fourth one in.
//
// It is also why there is no radius. A rounded box with three sides is a shape
// Windows does not have; the outer corners of a real spin button follow the
// field's 4, and the field is on the other side of a component boundary from
// here.
//
// HOVER BRIGHTENS AND PRESS DIMS, which is the state model for every control in
// this theme and the opposite of what most toolkits do: `ControlFillColorSecondary`
// #15FFFFFF on hover sits ABOVE `ControlFillColorTertiary` #08FFFFFF on press.
// Fluent.fillHover and Fluent.fillPress name the two scheme levels those
// composite to. Getting the pair the wrong way round is the second-best tell
// that a Fluent recreation is a recreation.
//
// AND NONE OF IT ANIMATES. Windows swaps the brush on a DiscreteObjectKeyFrame
// at time zero; Fluent.hoverMs is 0 and says so. There is no `Behavior on
// color` in this file and there must not be one.

import QtQuick
import qs
// StepperButton is components/StepperButton.qml -- the facade -- and not this
// file. The explicit import wins over the directory a document implicitly
// imports.
import qs.components
// Fluent lives one directory up. Without this line every `Fluent.` below is a
// ReferenceError at runtime, once per read; tests/qml-rules.sh checks the pair.
import qs.themes.windows

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. Typed and
    // `required` for the reason rule 1 of README.md sets out.
    required property StepperButton row

    // WHAT THE FACADE READS BACK, AND HERE IT IS A PAIR. This is one of the six
    // components that report a width, and the facade's header says why that is
    // not a breach of rule 2: a button in a Row has no parent width to take, so
    // its own is the only one there is. Both are constants, which is what keeps
    // it out of a loop -- neither is derived from the size the Loader handed
    // this item.
    //
    // MICROSOFT'S NUMBERS, AND THE FACADE FLOORS ONE OF THEM. A NumberBox spin
    // button is 32 wide and about 24 tall. The facade floors BOTH directions at
    // 26 -- what this button was before the split -- so what actually reaches
    // the screen is 32x26, measured. The 24 stays here anyway: it is what this
    // drawing asks for, the floor is the host's answer to it, and a file that
    // wrote 26 would be repeating somebody else's number as though it were its
    // own. MenuRow.qml in this directory meets the same floor from further
    // below and says the same thing.
    implicitWidth: 32
    implicitHeight: 24

    // Square, and see the header for why.
    radius: 0

    // The glyph box. 12 is what NumberBox gives its spin buttons, and it is not
    // in Fluent.qml because Fluent.qml carries the constants more than one
    // component needs and this is the only one that needs this. Microsoft's,
    // not ours.
    readonly property int glyphBox: 12

    color: mouse.pressed && root.enabled ? Fluent.fillPress
        : mouse.containsMouse && root.enabled ? Fluent.fillHover
        : Fluent.fillRest

    // Disabled means the value is already at the end of its range. Dimmed
    // rather than hidden: a button that disappears takes the other one with it
    // sideways, and the row would twitch at both ends of the range.
    //
    // Against `root.enabled` and not `row.enabled`, which is rule 6: this is
    // Qt's effective-enabled, computed down the tree from the facade through
    // its Loader to here, and it is the one that stays right when something
    // between the page and this button is disabled.
    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // ---------------- The three sides ----------------
    //
    // 1,0,1,1. Drawn as lines rather than as `border.width: 1`, which has no
    // way to leave one side out.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.outlineVariant
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.outlineVariant
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.outlineVariant
    }

    // The glyph. 12 epx, which is a BOX and not type -- Fluent.qml's rule is
    // that sizes are absolute and text is relative, so this is pixelSize while
    // every label in this directory is pointSize.
    Text {
        anchors.centerIn: parent

        text: root.row.symbol
        font.family: Theme.fontFamily
        font.pixelSize: root.glyphBox
        font.weight: Fluent.normalWeight
        color: Theme.textOnSurface
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Forwarded by hand, because MouseArea.enabled is a flag of its own and
        // does not follow the item tree the way the opacity above does. Rule 6
        // in README.md measures that; it is the opposite of what it looks like.
        enabled: root.enabled

        // ON PRESS, NOT ON CLICK. See the top of this file.
        onPressed: root.row.press()

        // BOTH, and they say the same thing. A release is the finger coming up;
        // a cancel is the grab being taken away by something above -- a
        // Flickable deciding the gesture was a scroll, a popout closing. The
        // timers have to stop for either, and the facade has nothing to tell
        // them apart by, which is why there is one function and not two.
        onReleased: root.row.release()
        onCanceled: root.row.release()
    }
}
