// THE SCROLL BAR, WHICH IS A BEHAVIOUR BEFORE IT IS A SHAPE.
//
// Two rectangles. What makes it Windows is when they change size and how long
// they wait first, and getting that wrong is more visible than getting the
// colour wrong -- everyone has watched a Windows scrollbar swell under the
// pointer without ever looking at one.
//
// A 2px LINE AT REST IN A 12px GUTTER, EXPANDING TO 6px. The expansion begins
// 400ms after the pointer arrives -- not on arrival, so crossing the bar on
// the way somewhere else does not set it off -- takes 167ms, and contracts
// 500ms after the pointer leaves. All six numbers are Microsoft's, out of
// ScrollBar_themeresources.xaml, and they live in Fluent.qml:
//
//     ScrollBarSize                  12    scrollGutter
//     the resting line                2    scrollLineRest
//     ScrollBarThumbStrokeThickness   6    scrollLineHover
//     ScrollBarExpandBeginTime      0.40   scrollExpandDelayMs
//     ScrollBarExpandDuration      0.167   scrollExpandMs
//     ScrollBarContractBeginTime    0.50   scrollContractDelayMs
//
// THE THUMB'S COLOUR NEVER CHANGES. ScrollBarThumbFill,
// ScrollBarThumbFillPointerOver and ScrollBarThumbFillPressed are all the same
// resource -- ControlStrongFillColorDefault -- so rest, hover and press are
// one colour and the affordance is entirely the width plus the track fading in
// behind it. Measured off ref/settings-system-about.jpg, where a bar at rest is
// two pixels of #9a9a9a with nothing behind it: `Theme.outline` is #969696.
//
// THERE IS NO MouseArea IN HERE, and that is the seam's line rather than an
// oversight. components/ScrollBar.qml declares its own, OUTSIDE this Loader,
// with grab margins that reach three pixels inward and eleven outward, and it
// is what turns a press into a `contentY`. It also computes `inUse` from that
// MouseArea plus the view's own motion, so a wheel that moves the list shows
// the bar without the pointer ever being near it. A second MouseArea in here
// would sit on top of that one and eat the drag.
//
// WHAT `implicitHeight` MEANS HERE IS NOT WHAT RULE 2 SAYS IT MEANS. The
// facade reads it as `thumbFloor` -- THE SHORTEST TRACK THE THUMB MAY LIVE IN,
// the floor under a thumb that is otherwise proportional to how much of the
// list is on screen. Nothing lays a scrollbar out by its implicit height, and
// binding this to how tall the bar came out would floor the thumb at the whole
// track and stop it moving. `implicitWidth` is the GUTTER, not the line: two
// call sites in the settings window reserve their margin from it, and a bar
// that reported 2 would be a two-pixel target.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property ScrollBar row

    // Hoisted rather than read through `row` at each use: one checked read of
    // a typed property, and the change handler below needs a local name to
    // hang off anyway.
    readonly property bool inUse: root.row.inUse

    // WIDE IS A STATE THIS FILE KEEPS, because both of its edges are delays
    // and a binding cannot be late. `inUse` goes true the moment the pointer
    // is over the gutter; `expanded` follows it 400ms later, and follows it
    // back down 500ms after it goes false.
    property bool expanded: false

    onInUseChanged: {
        if (root.inUse) {
            contract.stop();
            expand.restart();
        } else {
            expand.stop();
            contract.restart();
        }
    }

    implicitWidth: Fluent.scrollGutter
    implicitHeight: Fluent.scrollThumbMin

    Timer {
        id: expand

        interval: Fluent.scrollExpandDelayMs
        onTriggered: root.expanded = true
    }

    Timer {
        id: contract

        interval: Fluent.scrollContractDelayMs
        onTriggered: root.expanded = false
    }

    // The gutter's own fill, which exists only while the bar is wide.
    // ScrollBarBackground is transparent in every state; what appears under an
    // expanded thumb is ScrollBarTrackFill = AcrylicInAppFillColorDefault, the
    // same in-app acrylic the tooltip is made of. It fades rather than snaps --
    // ScrollBarOpacityChangeDuration, 83ms -- and it is the only thing in this
    // file that is allowed to, because it is a reveal and not a hover brush.
    Rectangle {
        anchors.fill: parent

        color: Fluent.acrylic(Theme.surfaceContainer)
        opacity: root.expanded ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Fluent.scrollTrackFadeMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Fluent.easeOut
            }
        }
    }

    Rectangle {
        id: thumb

        anchors.horizontalCenter: parent.horizontalCenter

        y: root.row.thumbY
        width: root.expanded ? Fluent.scrollLineHover : Fluent.scrollLineRest
        height: root.row.thumbHeight

        // 3 is ScrollBarCornerRadius. At two pixels wide Qt clamps it to half
        // the width, which is what makes the resting line a capsule and the
        // expanded one a rounded bar without two numbers.
        radius: Fluent.scrollRadius
        antialiasing: true

        color: Theme.outline

        Behavior on width {
            NumberAnimation {
                duration: Fluent.scrollExpandMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Fluent.easeOut
            }
        }
    }
}
