// The horizontal slider every volume in this shell is dragged with.
//
// IT WAS DRAWN TWICE BEFORE IT WAS A COMPONENT. The island had one and the
// sound page needed four more -- one per output, one per input, one per
// application -- which is the point at which "two rectangles and a MouseArea"
// stops being cheaper than a file.
//
// Still built by hand rather than from QtQuick.Controls, for the reason the
// island's copy already gave: a Controls Slider arrives with its own style,
// and styling it back into this palette is more code than drawing a bar.
//
// THE RANGE IS THE CALLER'S. The island passes 1.0 and the sound page passes
// 1.5, and that difference is deliberate rather than an oversight -- see the
// note over the output section in AudioPage.qml. This file only draws what it
// is told and reports where the pointer went; it has no opinion about how
// loud is too loud.

import QtQuick
import "root:/"

Item {
    id: root

    // Both in the same units the caller thinks in -- PipeWire's, where 1.0 is
    // 100%. Nothing here converts.
    property real value: 0
    property real maximum: 1

    // A mark drawn across the rail, for a range whose interesting point is
    // not at either end: at 1.0 on a slider that goes to 1.5 it is the line
    // between "as loud as the hardware means" and "gain applied in software".
    // Anything at or below zero draws none.
    property real notch: -1

    property color accent: Theme.primary

    // ---- The two colours that are not the accent ----
    //
    // Parameterised for the dashboard, which draws this slider on a
    // PHOTOGRAPH: there, a role derived from the wallpaper has nothing to do
    // with what is behind the rail. The defaults are exactly the roles that
    // were read in place here before, so the sound page gets the slider it
    // had.
    property color railColor: Theme.surfaceContainerHighest

    // The mark reads as a gap cut through the bar rather than as a third
    // colour, so it wants whatever is BEHIND the slider -- the window's own
    // background on a settings page, the scrimmed cover on the dashboard.
    property color notchColor: Theme.surface

    // How far one wheel click moves it, in the same units. Five percent, the
    // step the bar's own wheel handler has always used.
    property real step: 0.05

    // WHETHER THE WHEEL BELONGS TO THE SLIDER AT ALL, and the default is yes
    // because that is where this control came from: on the island it is a
    // popout with nothing behind it to scroll, and turning the wheel over a
    // volume bar is what everyone expects.
    //
    // It is FALSE on the sound page, and the difference is not taste. That
    // page is a Flickable taller than the window, so the wheel over a slider
    // has two possible meanings -- move this value, or move the page -- and
    // the pointer happens to be over a slider on the way past far more often
    // than it is there on purpose. Scrolling down to reach the input devices
    // and arriving with the output volume changed is the bug; the page is the
    // one that gets the wheel there. Same argument as ScrollList.qml, reached
    // from the other side: the rule is that the surface you MEANT to scroll
    // gets the event, and for a slider in a long page that is never the
    // slider.
    property bool wheelEnabled: true

    signal moved(real value)

    readonly property real fraction: root.maximum > 0
        ? Math.max(0, Math.min(1, root.value / root.maximum))
        : 0

    implicitHeight: 20

    // ---------------- Rail ----------------
    Rectangle {
        id: rail

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: root.railColor

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // ---------------- Fill ----------------
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: rail.width * root.fraction
        height: 6
        radius: 3
        color: root.accent

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // ---------------- The mark ----------------
    //
    // OVER THE FILL AND UNDER THE HANDLE, which is the whole reason it is
    // written here and not before the fill: painted underneath it would
    // disappear at exactly the moment it starts to mean something, which is
    // when the fill has passed it.
    Rectangle {
        visible: root.notch > 0 && root.notch < root.maximum

        x: rail.width * (root.notch / root.maximum) - width / 2
        anchors.verticalCenter: parent.verticalCenter

        width: 2
        height: 12
        radius: 1

        // See notchColor: it reads as a gap cut through the bar rather than
        // as a third colour, which works over the rail and over the fill
        // alike where no ink colour does.
        color: root.notchColor

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // ---------------- Handle ----------------
    Rectangle {
        x: rail.width * root.fraction - width / 2
        anchors.verticalCenter: parent.verticalCenter

        width: 14
        height: 14
        radius: 7
        color: root.accent

        // Grows under the pointer: the handle is the thing being aimed at and
        // 14px is small for a mouse.
        scale: mouse.containsMouse || mouse.pressed ? 1.25 : 1

        Behavior on scale {
            NumberAnimation { duration: Theme.animDuration }
        }

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        // Taller than the 6px rail it covers: the row is thin and the pointer
        // is not.
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Both, so a click jumps and a drag follows.
        onPressed: event => root.emit(event.x)
        onPositionChanged: event => {
            if (pressed)
                root.emit(event.x);
        }

        // DECLINED RATHER THAN IGNORED when the wheel is not ours. A
        // MouseArea accepts a wheel event whether or not anything handles it,
        // so leaving this empty would still swallow the notch and leave a dead
        // patch on the page instead of scrolling it. Handing it back is what
        // lets the Flickable underneath take it.
        onWheel: event => {
            if (!root.wheelEnabled) {
                event.accepted = false;
                return;
            }

            root.moved(Math.max(0, Math.min(root.maximum,
                root.value + (event.angleDelta.y > 0 ? root.step : -root.step))));
        }
    }

    // The MouseArea is inset by its negative margins, so its x is 6px to the
    // left of the rail's -- without correcting for that, a click at the very
    // start of the rail would report a small negative volume and one at the
    // end would overshoot. Clamped rather than merely offset, because the
    // margins also let the pointer stray past both ends.
    function emit(x: real): void {
        const local = x + mouse.anchors.margins;
        root.moved(Math.max(0, Math.min(1, local / rail.width)) * root.maximum);
    }
}
