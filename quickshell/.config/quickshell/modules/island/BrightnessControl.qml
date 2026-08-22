// The backlight: a glyph, a slider, and the number.
//
// SHAPED LIKE THE VOLUME AND SITTING DIRECTLY UNDER IT, because they are the
// same kind of thing: a value with a floor and a ceiling that you set by feel
// and then stop thinking about. Anything else here would be a second
// vocabulary for one idea. See VolumeControl.qml, which carries the argument
// for the shape and the history of the hairline this replaced.
//
// IT IS NOT IN THE DRAWING THE DASHBOARD CAME FROM, which was made against
// this desktop -- a machine with no backlight, where this control has always
// measured zero. A laptop has one, and dropping it to make a layout work
// would be dropping content.
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
import "root:/components"

Item {
    id: root

    property color ink: Theme.textOnSurface
    property color rest: Qt.alpha(root.ink, 0.13)

    visible: Brightness.present
    implicitHeight: Brightness.present ? 34 : 0

    // NOT A BUTTON, so no hover and no resting surface beyond the disc it
    // shares with the volume's glyph for alignment. There is nothing to
    // toggle about a backlight -- the volume's twin of this mutes, and this
    // one does not, so it does not pretend it can be pressed.
    Rectangle {
        id: mark

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        width: 30
        height: 30
        radius: width / 2
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: Icons.brightness
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Qt.alpha(root.ink, 0.8)
        }
    }

    Text {
        id: readout

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        text: `${Brightness.percent}%`
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        font.weight: Font.Bold
        color: root.ink
    }

    VolumeSlider {
        anchors.left: mark.right
        anchors.leftMargin: 14
        anchors.right: readout.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter

        // Named for the volume because that is where it was extracted from,
        // and it is not audio-specific: a track, a fill and a handle over a
        // range. See its header.
        value: Brightness.percent
        maximum: 100
        step: Brightness.step

        // Quieter than the volume's fill: two identical rows stacked read as
        // one control, and the one reached for more often should be the one
        // that looks brighter.
        accent: Qt.alpha(root.ink, 0.62)
        railColor: Qt.alpha(root.ink, 0.18)

        onMoved: value => Brightness.setPercent(Math.round(value))
    }
}
