// ONE APPLICATION MAKING NOISE: what it is called, where the sound is going, a
// mute button, a slider and a number.
//
// THE SHAPE IS THE VOLUME MIXER'S. ref/settings-system-sound-volumemixer.jpg
// shows the row Windows draws for exactly this: a mark at the left, the name
// beside it, and then a group hard against the right edge that runs speaker
// glyph, then the number, then the slider. The number sits INSIDE the group and
// to the left of the track rather than after it, which is the detail that would
// have been guessed the other way round.
//
// The mark at the left of a Settings row is the application's icon; here it is
// the mute button, because the facade hands over a glyph and a muted glyph and
// this row has to be mutable from the row itself. That is the same move the
// volume flyout makes in ref/tray-volume-flyout.jpg, where the speaker at the
// left of each slider IS the mute toggle.
//
// NO HOVER FILL ON THE ROW ITSELF, and that is a promise rather than a
// preference. components/StreamRow.qml sets it out: the row is not a target --
// this page cannot reroute a stream, so a click on it has nowhere to go -- and
// InfoRow's rule applies, that the cheapest way to tell a control from a
// reading is that a control lights up. The two things here that DO respond,
// the mute glyph and the slider, light up on their own.
//
// THE WRITES GO THROUGH THE FACADE. `row.toggleMute()` and `row.setVolume(v)`,
// never `row.node.audio.muted = ...`: a theme does not know what a PipeWire
// node is, and un-muting when the slider comes off zero is a rule about audio
// that lives on the other side of the seam. This is also why there is no
// second slider drawn in here -- the VolumeSlider below is the shell's own
// component, with its own theme half, and it already knows how a Windows
// slider looks.
//
// THE NUMBER'S COLUMN IS PINNED TO THE WORD `muted`, which is the reason for
// the two invisible Texts at the foot of this file. The readout swaps between
// a percentage and a word of a different length, and a column sized to
// whichever is showing makes the slider's right-hand end jog sideways every
// time somebody presses mute.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    required property StreamRow row

    // SettingsExpander's child-row height, which is what a compact row inside a
    // section is in Windows -- and the same 52 the facade already floors at, so
    // the two agree by arithmetic rather than by luck.
    implicitHeight: Math.max(Fluent.expanderChildHeight,
        lines.implicitHeight + Theme.itemSpacing * 4)

    // ---------------- The mute button, at the left ----------------
    Rectangle {
        id: mute

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.controlHeight
        height: Fluent.controlHeight
        radius: Fluent.controlRadius
        antialiasing: true

        // Hover brightens, press dims, and neither of them fades: the fill is
        // swapped on a DiscreteObjectKeyFrame at time zero. `Fluent.fillRest`
        // is not used for the resting state on purpose -- a button that is
        // only a glyph until the pointer reaches it is what the mixer draws,
        // and a permanent backplate here would make the row look clickable
        // when it is not.
        color: !muteMouse.containsMouse
            ? "transparent"
            : (muteMouse.pressed ? Fluent.fillPress : Fluent.fillHover)

        Text {
            anchors.centerIn: parent

            text: root.row.muted ? root.row.mutedGlyph : root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            color: root.row.muted ? Theme.textOnSurfaceVariant : Theme.textOnSurface
        }

        MouseArea {
            id: muteMouse

            anchors.fill: parent

            enabled: root.enabled
            hoverEnabled: true

            // No cursorShape: Windows leaves the arrow on every control it
            // draws and keeps the hand for hyperlinks. The hover fill is what
            // says this glyph is a button.

            onClicked: root.row.toggleMute()
        }
    }

    // ---------------- What it is, and where it is going ----------------
    Column {
        id: lines

        anchors.left: mute.right
        anchors.leftMargin: Theme.itemSpacing * 2
        anchors.right: readout.left
        anchors.rightMargin: Theme.itemSpacing * 2
        anchors.verticalCenter: parent.verticalCenter

        spacing: 0

        Text {
            width: parent.width

            text: root.row.label
            elide: Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            lineHeight: Fluent.bodyLineRatio
            lineHeightMode: Text.ProportionalHeight

            color: Theme.textOnSurface
        }

        Text {
            width: parent.width

            // "to Speakers" or "from Microphone": the preposition is the call
            // site's, because sound goes TO a pair of headphones and comes
            // FROM a microphone, and the row reads as nonsense with the wrong
            // one.
            visible: root.row.route !== ""
            text: root.row.routePrefix + " " + root.row.route
            elide: Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            lineHeight: Fluent.captionLineRatio
            lineHeightMode: Text.ProportionalHeight

            color: Theme.textOnSurfaceVariant
        }
    }

    // ---------------- The group at the right: number, then slider ----------
    VolumeSlider {
        id: level

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.cardContentMinWidth

        // SettingsCardContentMinWidth, so that a stack of these lines its
        // controls up down the right-hand edge instead of each row ending
        // where its own name happens to.

        // The page this row lives on is a Flickable taller than the window, and
        // the pointer crosses these on the way down it far more often than it
        // stops on one. Same call the sound page's own rows make.
        wheelEnabled: false

        value: root.row.volume
        maximum: 1

        onMoved: value => root.row.setVolume(value)
    }

    Text {
        id: readout

        anchors.right: level.left
        anchors.rightMargin: Theme.itemSpacing * 2
        anchors.verticalCenter: parent.verticalCenter

        width: Math.max(mutedMetrics.implicitWidth, loudMetrics.implicitWidth)
        horizontalAlignment: Text.AlignRight

        text: root.row.muted ? "muted" : String(Math.round(root.row.volume * 100))

        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        color: root.row.muted ? Theme.textOnSurfaceVariant : Theme.textOnSurface
    }

    // The two widths the readout has to be able to hold without moving. They
    // are laid out by nothing and drawn by nothing; a Text still measures its
    // string while invisible, which is the whole trick.
    Text {
        id: mutedMetrics

        visible: false
        font: readout.font
        text: "muted"
    }

    Text {
        id: loudMetrics

        visible: false
        font: readout.font
        text: "150"
    }
}
