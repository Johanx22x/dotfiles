// The backlight, with a slider you can aim at.
//
// NEXT TO THE VOLUME AND SHAPED LIKE IT, because they are the same kind of
// thing: a value with a floor and a ceiling that you set by feel and then stop
// thinking about. Anything else here would be a second vocabulary for one
// idea.
//
// A VIEW AND NOTHING ELSE NOW. The device query and the two FileViews that
// used to be in this file live in Brightness.qml, and the move was not
// tidiness: this control is a child of Dashboard.qml, which the popout
// DESTROYS every time it closes. So the reading existed only while the panel
// was on screen, which meant the island had nothing to flash when a media key
// moved the backlight with the dashboard shut -- and it meant a
// `desktop-brightness device` spawn on every single opening of the panel.
//
// What stays here is the drawing and the aiming. See Brightness.qml for where
// the value comes from, why it is watched rather than reported, and why the
// reading and the writing go two different ways.
//
// OFF UNLESS THIS MACHINE SAID IT IS A LAPTOP, and off anyway when there is no
// backlight -- both gates are `Brightness.present`, so this control and the
// island's acknowledgement can never disagree about whether there is a
// backlight to talk about.

import QtQuick
import "root:/"
import "root:/components"

Item {
    id: root

    visible: Brightness.present
    implicitHeight: Brightness.present ? 62 : 0

    Text {
        id: mark

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 6

        text: Icons.brightness
        font.family: Theme.fontFamily
        font.pointSize: Theme.iconSize
        color: Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: mark.verticalCenter

        text: `${Brightness.percent}%`
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Font.Bold
        color: Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    VolumeSlider {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // Named for the volume because that is where it was extracted from,
        // and it is not audio-specific: a track, a fill and a handle over a
        // range. See its header.
        value: Brightness.percent
        maximum: 100
        step: Brightness.step
        accent: Theme.primary

        onMoved: value => Brightness.setPercent(value)
    }
}
