// Which keyboard layout the typing is going into, and the fastest way to
// change it.
//
// A READING THAT IS ALSO A CONTROL, which almost nothing else on this bar is.
// The clock's note is explicit that it has nothing behind it; the batteries
// are readings and the tray belongs to other applications. This one earns the
// exception: the thing it reports is a MODE, the only question it provokes is
// "put me back in the other one", and a pill that answers that question in one
// click is the whole reason to have it. Hover speaks in primary, the same way
// the settings button does, so that it says so before it is clicked.
//
// IT SHOWS THE CODE AND NOT A FLAG. `latam` is Spanish across a continent and
// there is no flag that means it; `us` and `gb` would be two flags for what is
// nearly one layout. The code is also what the settings window, the script and
// the compositor all call it, so the bar agreeing with them is worth more than
// a prettier glyph -- and it stays legible at bar size, which a 16px flag does
// not.
//
// IT IS AS WIDE AS THE LAYOUT IT IS SHOWING, and this was the other way round
// first. The original reserved the width of the longest code in the cycle so
// that nothing beside it ever moved -- the clock's rule -- and on screen that
// was worse: "US" sat in a pill built for "LATAM" with a finger of empty glass
// after it, which reads as a widget that failed to draw something rather than
// as a short word.
//
// So the pill fits its own text and the width is ANIMATED. What the reserved
// space was buying is that the bar does not jump; a width that slides for
// 150ms buys the same thing, because the movement is then something the eye
// follows instead of a jump-cut, and it only ever happens at the moment you
// asked for it by switching.
//
// ONLY WHEN THERE IS SOMEWHERE TO GO. With one layout configured the pill is
// hidden: it would be a control that cannot change anything, reporting a fact
// that cannot change either. Same call AppearancePage makes about the cursor
// theme row when only one theme is installed.

import QtQuick
import "root:/"

Item {
    id: root

    // The gap between the glyph and the code it introduces, borrowed from the
    // clock: an icon and its reading are one thing and have to bind more
    // tightly to each other than to whatever sits next in the group.
    readonly property int glyphGap: 5

    // What the compositor is typing in right now, upper-cased. The lower-case
    // form is the one every command takes; capitals are what a two-letter
    // reading on a bar wants.
    readonly property string code: Config.keyboardLayout.toUpperCase()

    implicitWidth: mark.implicitWidth + root.glyphGap + label.implicitWidth
    implicitHeight: Theme.groupHeight

    // The slide. On implicitWidth and not on width: the pill above this widget
    // sizes itself to its contents, so animating the reported size is what
    // makes the whole group grow rather than the label sliding around inside a
    // background that has already jumped.
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Text {
        id: mark

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        text: Icons.keyboard
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        // Muted until hovered, like the clock's glyphs: the accent on this
        // side of the bar is spoken for, and the code is what the eye is
        // meant to land on.
        color: mouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    Text {
        id: label

        anchors.left: mark.right
        anchors.leftMargin: root.glyphGap
        anchors.verticalCenter: parent.verticalCenter

        text: root.code
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Font.Bold
        color: mouse.containsMouse ? Theme.primary : Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // The same command SUPER + K runs and the same one the settings
        // window sends -- see Config.cycleKeyboardLayout. Nothing here talks
        // to the compositor directly, which is what stops this pill from ever
        // disagreeing with what is being typed.
        onClicked: Config.cycleKeyboardLayout()
    }
}
