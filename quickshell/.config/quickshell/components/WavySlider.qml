// The seek bar from end-4/dots-hyprland: the played part is a moving sine, the
// rest is a flat rail, and a thin vertical bead sits between them.
//
// Ported from the Wavy configuration of their
// modules/common/widgets/StyledSlider.qml. The first port of the media card
// left this as a plain filled rectangle and that was rejected, so this is the
// real thing: their geometry, their numbers, and their WavyLine doing the
// drawing.
//
// THEIRS SUBCLASSES QtQuick.Controls' Slider AND THIS DOES NOT, and that is
// the one thing here that is not a copy. This shell has no QtQuick.Controls
// anywhere in it, on purpose -- components/VolumeSlider.qml says why, and it
// is the same argument every time: a Controls Slider arrives with its own
// style and getting it back to this palette costs more than drawing a bar.
// Nothing visible rests on that choice; every number below is theirs, and the
// wave is their component. What is dropped with the base class is the press
// tooltip, the divider segments and the configurable stop indicators, none of
// which their media card uses either.
//
// THE NUMBERS, all from their Wavy configuration:
//
//   track            4 tall, which is Configuration.Wavy itself
//   handle           3 wide, 1.5 while pressed, 24 tall, fully rounded
//   handle margins   4 either end, which is the slider's padding
//   wave             frequency 6 over the whole rail, amplitude half the
//                    4px line width
//   stop indicator   a 3px dot at the far end
//   inner corners    2, their rounding.unsharpen, on the ends that meet the
//                    handle -- the outer ends are fully rounded

import QtQuick
import "root:/"

Item {
    id: root

    // 0..1. The caller keeps the units; this only draws and reports.
    property real value: 0

    property bool seekable: true

    property color highlightColor: Theme.primary
    property color trackColor: Theme.secondaryContainer
    property color handleColor: Theme.primary
    property color dotColor: Theme.textOnSecondaryContainer
    property color dotColorHighlighted: Theme.textOnPrimary

    // Whether the wave should be moving. False leaves the curve frozen where
    // it is rather than flattening it -- a paused track still shows a wave,
    // it just stops travelling, which is theirs.
    property bool animateWave: true

    signal moved(real value)

    readonly property real handleMargins: 4
    readonly property real handleHeight: 24
    // Not readonly, only because a Behavior is attached below and a value
    // interceptor on a read-only property is a needless thing to have to be
    // sure about. Nothing writes it.
    property real handleWidth: seekArea.pressed ? 1.5 : 3
    readonly property real trackWidth: 4
    readonly property real trackDotSize: 3
    readonly property real unsharpenRadius: 2
    readonly property real waveFrequency: 6

    // The span the handle's CENTRE travels across, which is the width less a
    // margin at each end. Every x below is measured against this.
    readonly property real effectiveDraggingWidth: Math.max(0, width - root.handleMargins * 2)

    // WHILE DRAGGING, THE HANDLE FOLLOWS THE POINTER AND NOT THE PLAYER.
    // `value` comes back from MPRIS through a twice-a-second poll, so a slider
    // that only ever drew `value` would lag a drag by up to half a second and
    // feel unhooked. A real Slider -- which is what theirs subclasses -- keeps
    // this position itself for exactly this reason.
    property real dragValue: 0

    readonly property real visualPosition: seekArea.pressed
        ? Math.max(0, Math.min(1, root.dragValue))
        : Math.max(0, Math.min(1, root.value))

    implicitHeight: root.handleHeight

    Behavior on handleWidth {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
    }

    // ---- The played part: their WavyLine ----
    //
    // THE CANVAS IS AS TALL AS THE WHOLE CONTROL and not as tall as the 4px
    // track, which is the one piece of their sizing that had to be worked out
    // rather than read off. A Canvas clips to its own bounds, so a 4px-tall
    // canvas holding a 4px line swinging +-2 would come out as a solid 4px bar
    // with no visible wave at all. Their StyledProgressBar gives the same
    // component `height: contentItem.height * 6` against `lineWidth:
    // contentItem.height` -- six times the line width -- and 24 over a 4px
    // line is exactly that ratio, so this is their proportion, reached from
    // the file of theirs that states it outright.
    WavyLine {
        id: wave

        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.visualPosition * root.effectiveDraggingWidth - root.handleWidth / 2)
        height: root.handleHeight

        visible: width > 0

        color: root.highlightColor
        lineWidth: root.trackWidth
        amplitudeMultiplier: 0.5
        frequency: root.waveFrequency

        // The phase runs against the WHOLE rail, so the wave does not compress
        // as the track plays. Theirs.
        fullLength: root.width

        onWidthChanged: wave.requestPaint()
        onColorChanged: wave.requestPaint()

        FrameAnimation {
            // wave.visible and not root.visible: at position zero the wave
            // has no width and there is nothing to repaint sixty times a
            // second.
            running: root.animateWave && wave.visible
            onTriggered: wave.requestPaint()
        }
    }

    // ---- The part not played yet ----
    Rectangle {
        id: rail

        anchors.verticalCenter: parent.verticalCenter

        x: root.visualPosition * root.effectiveDraggingWidth + root.handleMargins * 2 + root.handleWidth / 2
        width: Math.max(0, (1 - root.visualPosition) * root.effectiveDraggingWidth - root.handleWidth / 2)
        height: root.trackWidth

        color: root.trackColor

        // Fully rounded at the far end, barely rounded at the end that meets
        // the handle. Theirs.
        topRightRadius: height / 2
        bottomRightRadius: height / 2
        topLeftRadius: root.unsharpenRadius
        bottomLeftRadius: root.unsharpenRadius
    }

    // ---- The stop indicator ----
    //
    // Their StyledSlider carries `stopIndicatorValues: [1]` by default and the
    // media card does not override it, so their seek bar has this dot at the
    // far end. It flips colour once the position reaches it.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter

        x: root.handleMargins + root.effectiveDraggingWidth - root.trackDotSize / 2
        width: root.trackDotSize
        height: root.trackDotSize
        radius: width / 2

        color: root.visualPosition < 1 ? root.dotColor : root.dotColorHighlighted

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // ---- The handle ----
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter

        x: root.handleMargins + root.visualPosition * root.effectiveDraggingWidth - root.handleWidth / 2
        width: root.handleWidth
        height: root.handleHeight
        radius: width / 2

        color: root.handleColor
    }

    // The rail is 4 pixels of a 24 pixel control; the pointer gets all 24.
    MouseArea {
        id: seekArea

        anchors.fill: parent
        enabled: root.seekable
        cursorShape: seekArea.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        function report(mouseX: real) {
            if (root.effectiveDraggingWidth <= 0)
                return;
            const at = Math.max(0, Math.min(1, (mouseX - root.handleMargins) / root.effectiveDraggingWidth));
            root.dragValue = at;
            root.moved(at);
        }

        onPressed: mouse => seekArea.report(mouse.x)
        onPositionChanged: mouse => {
            if (seekArea.pressed)
                seekArea.report(mouse.x);
        }
    }
}
