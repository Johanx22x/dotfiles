// THE SLIDER, AND THE ONE THING ABOUT IT THAT LOOKS WRONG UNTIL YOU MEASURE IT.
//
// THE UNFILLED TRACK IS LIGHTER THAN THE SURFACE UNDER IT. Every instinct says
// the part that is not filled in should recede -- a dark groove with a bright
// fill in it -- and Windows does the opposite: sampled off
// ref/settings-system-sound-volumemixer.jpg the unfilled half is #9ba0a6 on a
// card of #2b2b2b, which is `Theme.outline`, and the filled half is #56bff8,
// which is the accent. The same thing is called out in the reference index for
// Quick Settings: "the unfilled part of the slider track is a light grey,
// clearly brighter than the panel -- it is not a subtle dark track".
//
// It is NOT read from `row.railColor`, and that is deliberate. The property is
// real API -- the island's brightness and volume controls set it, because they
// draw this slider on a photograph -- but nothing that loads under THIS theme
// sets it, so what would arrive here is its default,
// `Theme.surfaceContainerHighest` (#454545), which is the dark groove the
// photograph says Windows does not draw. The day a windows surface sets it,
// this line is where to notice.
//
// THE REST OF THE GEOMETRY IS MICROSOFT'S, out of Slider_themeresources.xaml
// and via Fluent.qml: a 4px track at radius 2, a 22px thumb (the 18px element
// plus a Border at Margin="-2"), and an inner dot of 12 at rest that goes to
// 14 under the pointer and 10 while pressed. THE DOT IS THE ONE THING IN THIS
// THEME THAT ANIMATES ON HOVER, because it is a scale and not a brush swap:
// the storyboards are SplineDoubleKeyFrames at ControlNormalAnimationDuration
// going out and ControlFastAnimationDuration coming back, which is why the two
// durations below are not the same number.
//
// ---------------------------------------------------------------------------
// THE TWO LINES THAT ARE A CONTRACT AND NOT A STYLE
// ---------------------------------------------------------------------------
//
// `row.moveTo(fraction)` -- the theme says WHERE ALONG ITS OWN RAIL the
// pointer landed, from 0 to 1, and the facade clamps it and multiplies by a
// maximum this file has no business knowing. The correction for the thumb's
// own width belongs here because the thumb's width is drawn here: the pointer
// at the extreme left means zero, and zero is a thumb whose LEFT EDGE is at
// the left edge, not one whose centre is.
//
// `event.accepted = row.wheel(event.angleDelta.y)` -- and never a bare call.
// The facade decides whether the wheel belongs to the slider at all (it does
// not on the sound page, which scrolls), and it says so through that return
// value. Dropping it swallows the notch: the page under the pointer does not
// scroll and the volume does not move, which reads as a dead patch in the
// middle of a list.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property VolumeSlider row

    implicitHeight: Fluent.sliderRowHeight

    // How far the thumb's centre may travel, and the shape of everything else
    // on the rail. The rail is full width; the thumb's centre runs from one
    // radius in to one radius from the far end, which is what makes a slider
    // at 0 look like a thumb sitting AT the start rather than half off it.
    readonly property real travel: Math.max(0, root.width - Fluent.sliderThumb)
    readonly property real thumbX: root.travel * root.row.fraction
    readonly property real thumbCentre: root.thumbX + Fluent.sliderThumb / 2

    // Rule 6: the dim is written against this item's own effective `enabled`,
    // not against anything on `row`.
    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // The rail, unfilled. Full width and behind everything else.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        height: Fluent.sliderTrackHeight
        radius: Fluent.sliderTrackRadius
        antialiasing: true

        color: Theme.outline
    }

    // The rail, filled. It stops at the thumb's centre and the thumb covers
    // the stub that is left at zero.
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        width: root.thumbCentre
        height: Fluent.sliderTrackHeight
        radius: Fluent.sliderTrackRadius
        antialiasing: true

        color: root.row.accent
    }

    // The mark for a range whose interesting point is not at either end: 1.0
    // on a slider that goes to 1.5, the line between the hardware's idea of
    // full and gain applied in software. It is drawn in whatever is BEHIND the
    // slider so that it reads as a gap cut through the rail rather than as a
    // third colour on it -- see components/VolumeSlider.qml on `notchColor`.
    Rectangle {
        readonly property real fraction: root.row.maximum > 0
            ? root.row.notch / root.row.maximum
            : 0

        anchors.verticalCenter: parent.verticalCenter

        visible: root.row.notch > 0 && fraction < 1
        x: root.travel * fraction + Fluent.sliderThumb / 2 - width / 2
        width: 2
        height: Fluent.sliderTrackHeight

        color: root.row.notchColor
    }

    Rectangle {
        id: thumb

        anchors.verticalCenter: parent.verticalCenter

        x: root.thumbX
        width: Fluent.sliderThumb
        height: Fluent.sliderThumb
        radius: width / 2
        antialiasing: true

        color: Theme.surfaceContainerHighest

        // The lit edge, flat rather than the three-pixel gradient the bigger
        // controls carry: at 22px round there is no top for an absolute
        // gradient stop to sit in.
        border.width: 1
        border.color: Qt.alpha(Theme.textOnSurface, Fluent.elevationTop)

        Rectangle {
            id: dot

            anchors.centerIn: parent

            width: pointer.pressed
                ? Fluent.sliderDotPress
                : (pointer.containsMouse ? Fluent.sliderDotHover : Fluent.sliderDotRest)
            height: width
            radius: width / 2
            antialiasing: true

            color: root.row.accent

            // 250ms out, 167ms back. Both of Microsoft's, and the asymmetry is
            // in the source: the PointerOver and Pressed storyboards run at
            // ControlNormalAnimationDuration and the return to rest at
            // ControlFastAnimationDuration.
            Behavior on width {
                NumberAnimation {
                    duration: dot.width === Fluent.sliderDotRest ? Fluent.normalMs : Fluent.fastMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Fluent.easeOut
                }
            }
        }
    }

    // THE WHOLE CONTROL IS THE TARGET, not the four pixels of rail. A 4px
    // track is not something anybody can hit, which is why the row height is
    // 32 and why this fills it.
    MouseArea {
        id: pointer

        anchors.fill: parent

        // Rule 6 again, and from the other side: a MouseArea under a disabled
        // ancestor still reports `enabled: true`, so this has to be bound.
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function seek(x: real): void {
            if (root.travel <= 0)
                return;

            root.row.moveTo((x - Fluent.sliderThumb / 2) / root.travel);
        }

        onPressed: mouse => pointer.seek(mouse.x)
        onPositionChanged: mouse => {
            if (pointer.pressed)
                pointer.seek(mouse.x);
        }

        onWheel: event => {
            event.accepted = root.row.wheel(event.angleDelta.y);
        }
    }
}
