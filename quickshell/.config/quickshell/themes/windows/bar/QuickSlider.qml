// A BRIGHTNESS OR VOLUME SLIDER IN QUICK SETTINGS.
//
// A glyph, a rail across the rest of the row, and -- on the volume one only --
// a mixer icon and a chevron at the right end that opens the sound page.
//
// THE UNFILLED TRACK IS LIGHTER THAN THE PANEL IT SITS ON. That is the detail
// worth writing down, because it is the opposite of the instinct and it is the
// rule this whole theme runs on: in Windows' dark mode every surface that
// comes forward gets lighter, never darker. A dark theme built by darkening as
// things stack reads inverted, and a rail drawn darker than its panel is the
// first place that shows.
//
// This is NOT the VolumeSlider facade. That one is a component the host asks
// every theme for, with a contract about `moveTo` and a wheel return value.
// This is a private part of the Quick Settings panel, drawn to the shape the
// photograph shows -- which has a trailing control the facade knows nothing
// about.

import QtQuick
import qs
import qs.themes.windows

Item {
    id: root

    property string sliderGlyph: ""
    property real value: 0
    property bool trailing: false

    signal moved(real fraction)
    signal trailingPressed

    implicitHeight: Fluent.quickSliderHeight

    Text {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Fluent.quickPadding
        anchors.verticalCenter: parent.verticalCenter

        text: root.sliderGlyph
        font.family: Theme.fontFamily
        font.pointSize: Fluent.captionSize
        color: Theme.textOnSurface
    }

    Item {
        id: track

        anchors.left: glyph.right
        anchors.leftMargin: 16
        anchors.right: root.trailing ? trail.left : parent.right
        anchors.rightMargin: Fluent.quickPadding
        anchors.verticalCenter: parent.verticalCenter

        height: Fluent.sliderThumb

        Rectangle {
            id: rail

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            height: Fluent.sliderTrackHeight
            radius: Fluent.sliderTrackRadius
            // ControlStrongFillColorDefault: lighter than the panel, on purpose.
            color: Theme.outline

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1, root.value))
                radius: parent.radius
                color: Theme.primary
            }
        }

        Rectangle {
            id: thumb

            x: (track.width - width) * Math.max(0, Math.min(1, root.value))
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.sliderThumb
            height: Fluent.sliderThumb
            radius: width / 2

            color: Theme.surfaceContainerHighest
            border.width: 1
            border.color: Theme.outlineVariant

            Rectangle {
                anchors.centerIn: parent
                width: railPointer.pressed
                    ? Fluent.sliderDotPress
                    : railPointer.containsMouse ? Fluent.sliderDotHover : Fluent.sliderDotRest
                height: width
                radius: width / 2
                color: Theme.primary

                Behavior on width {
                    NumberAnimation {
                        duration: Fluent.fastMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Fluent.easeOut
                    }
                }
            }
        }

        MouseArea {
            id: railPointer

            anchors.fill: parent
            hoverEnabled: true

            function report(x: real): void {
                const usable = track.width - thumb.width;
                if (usable <= 0)
                    return;
                root.moved(Math.max(0, Math.min(1, (x - thumb.width / 2) / usable)));
            }

            onPressed: mouse => report(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    report(mouse.x);
            }
        }
    }

    Row {
        id: trail

        anchors.right: parent.right
        anchors.rightMargin: Fluent.quickPadding - 4
        anchors.verticalCenter: parent.verticalCenter

        visible: root.trailing
        spacing: 2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.tune
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurface
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.chevronRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurface
        }
    }

    MouseArea {
        anchors.fill: trail
        enabled: root.trailing
        onClicked: root.trailingPressed()
    }
}
