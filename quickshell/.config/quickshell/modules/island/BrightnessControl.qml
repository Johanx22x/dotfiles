// The backlight, as a hairline directly above the volume's.
//
// SHAPED LIKE THE VOLUME because they are the same kind of thing: a value with
// a floor and a ceiling that you set by feel and then stop thinking about.
// Anything else here would be a second vocabulary for one idea. See
// VolumeControl.qml, which carries the argument for the shape.
//
// IT IS NOT IN THE DASHBOARD'S DRAWING, which was made against this desktop --
// a machine with no backlight, where this control has always measured zero.
// A laptop has one, and dropping it to make a layout work would be dropping
// content. It appears only where there is a backlight to talk about.
//
// A VIEW AND NOTHING ELSE. The device query and the two FileViews that used to
// be in this file live in Brightness.qml, and the move was not tidiness: this
// control is a child of Dashboard.qml, which the popout DESTROYS every time it
// closes. See Brightness.qml for where the value comes from, why it is watched
// rather than reported, and why the reading and the writing go two different
// ways.
//
// OFF UNLESS THIS MACHINE SAID IT IS A LAPTOP, and off anyway when there is no
// backlight -- both gates are `Brightness.present`, so this control and the
// island's acknowledgement can never disagree about whether there is one.

import QtQuick
import "root:/"

Item {
    id: root

    property color ink: Theme.textOnSurface

    readonly property int reach: 12

    visible: Brightness.present
    implicitHeight: Brightness.present ? 6 : 0

    readonly property real fraction: Math.max(0, Math.min(1, Brightness.percent / 100))

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.ink, 0.15)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: parent.width * root.fraction
        // Quieter than the volume's fill on purpose: two identical rules
        // stacked two pixels apart read as one thick rule, and the one you
        // reach for more often should be the one that looks brighter.
        color: Qt.alpha(root.ink, 0.6)
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.bottom: parent.top
        anchors.bottomMargin: 6

        visible: opacity > 0
        opacity: rail.containsMouse ? 1 : 0

        text: `${Brightness.percent}%`
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize * 0.85
        font.weight: Font.Bold
        color: root.ink

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }
    }

    MouseArea {
        id: rail

        anchors.fill: parent
        anchors.topMargin: -root.reach

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function report(mouseX: real): void {
            if (root.width <= 0)
                return;
            Brightness.setPercent(Math.round(Math.max(0, Math.min(100, mouseX / root.width * 100))));
        }

        onPressed: mouse => rail.report(mouse.x)

        onPositionChanged: mouse => {
            if (rail.pressed)
                rail.report(mouse.x);
        }

        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? Brightness.step : -Brightness.step;
            Brightness.setPercent(Math.max(0, Math.min(100, Brightness.percent + step)));
        }
    }
}
