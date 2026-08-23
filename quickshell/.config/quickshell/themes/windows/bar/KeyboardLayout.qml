// Which keyboard layout the typing is going into, and the fastest way to change
// it.
//
// THIS IS ONE OF THE FEW WIDGETS ON THIS BAR THAT WINDOWS ACTUALLY HAS. The
// input-indicator sits in the taskbar corner between the tray icons and the
// clock, it shows a short code for the active layout, and clicking it switches.
// That is exactly this, so it needed less redrawing than anything else here.
//
// THE GLYPH WENT. Genesis introduces the code with a keyboard mark, the way its
// clock introduces the time with a clock face. Windows' indicator is the letters
// and nothing else, and at 12px in a 34px box the mark was half the width of the
// item for no information at all.
//
// IT SHOWS THE CODE AND NOT A FLAG. `latam` is Spanish across a continent and
// there is no flag that means it; `us` and `gb` would be two flags for what is
// nearly one layout. The code is also what the settings window, the script and
// the compositor all call it.
//
// IT IS AS WIDE AS THE LAYOUT IT IS SHOWING, and the width is animated. The
// original reserved the width of the longest code in the cycle so nothing beside
// it ever moved, and on screen that was worse: "US" sat in a box built for
// "LATAM" with a finger of empty glass after it, which reads as a widget that
// failed to draw something.
//
// ONLY WHEN THERE IS SOMEWHERE TO GO -- Bar.qml hides it with one layout
// configured. It would be a control that cannot change anything, reporting a
// fact that cannot change either.

import QtQuick
import qs
import qs.themes.windows

TaskbarItem {
    id: root

    // What the compositor is typing in right now, upper-cased. The lower-case
    // form is the one every command takes; capitals are what a two-letter
    // reading on a bar wants.
    readonly property string code: Config.keyboardLayout.toUpperCase()

    readonly property int padH: Theme.barPadding

    boxWidth: label.implicitWidth + root.padH * 2

    // The same command SUPER + K runs and the same one the settings window sends
    // -- see Config.cycleKeyboardLayout. Nothing here talks to the compositor
    // directly, which is what stops this indicator from ever disagreeing with
    // what is being typed.
    onActivated: Config.cycleKeyboardLayout()

    Behavior on boxWidth {
        NumberAnimation {
            duration: Fluent.fastMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Fluent.easeOut
        }
    }

    Text {
        id: label

        anchors.centerIn: parent

        text: root.code
        font.family: Theme.fontFamily
        font.pointSize: Fluent.captionSize
        font.weight: Fluent.normalWeight
        color: root.hovered ? Theme.primary : Theme.textOnSurface
    }
}
