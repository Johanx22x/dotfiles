// A hover note, for the row that needs a sentence the label has no room for.
//
// IT IS A CHILD OF WHAT IT EXPLAINS, not a window-level overlay, and that is
// a trade worth knowing about: it is clipped by the first ancestor with
// clip: true, which in the settings window is the Flickable holding the
// pages. Fine for a note under a row near the top of a page, wrong for one at
// the very bottom. The alternative -- a single tooltip at window level with
// the rows reporting their position into it -- is what to reach for on the
// day a row at the bottom needs one, and not before.
//
// Opaque, unlike almost everything else this shell draws. A translucent note
// over a translucent window over a wallpaper is three layers of image behind
// two lines of small text, and the point of the thing is that it can be read
// at a glance.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property alias text: label.text
    // Set by whatever is being hovered. Not `visible` directly: the fade
    // needs something to animate, and an item that is not visible does not
    // animate at all.
    property bool shown: false

    // Wide enough for a sentence over two or three lines. Wider and the eye
    // has to travel back across the row it is explaining.
    property int maxWidth: 320

    implicitWidth: Math.min(label.implicitWidth + Theme.groupPadding * 2, maxWidth)
    implicitHeight: label.implicitHeight + Theme.groupPadding

    radius: 10
    color: Theme.surfaceContainerHighest
    border.width: 1
    border.color: Theme.outlineVariant

    // Above the rows it overlaps, including the one below it in the card.
    z: 100

    visible: opacity > 0
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: Theme.recolorDuration }
    }

    Text {
        id: label

        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.maxWidth - Theme.groupPadding * 2)

        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        color: Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }
}
