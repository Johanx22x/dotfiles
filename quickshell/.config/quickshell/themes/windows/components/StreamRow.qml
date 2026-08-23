// How Windows draws one application making noise. The public half -- why this is
// not a ListRow, and why the two writes to PipeWire are on the other side of the
// seam -- is components/StreamRow.qml.
//
// THE TWO WRITES ARE NOT THIS FILE'S. `row.toggleMute()` and
// `row.setVolume(v)`, never `row.node.audio.muted = ...`: `node` is a PipeWire
// node and rule 5 in themes/genesis/components/README.md says nothing under a
// theme directory may know what one of those is. The direction is rule 4's --
// the theme reads a value and asks for a new one -- and the half that owns the
// value is the half that acts.
//
// NO HOVER FILL ON THE ROW ITSELF, and that is the promise the facade cannot
// require. There is nowhere for a click on this row to go: the sound page cannot
// reroute a stream, so the row is a reading with two controls sitting on it
// rather than a control in its own right. InfoRow's rule applies whole -- the
// cheapest way to tell a control from a reading is that a control lights up --
// and the two things here that DO respond, the mute button and the slider, light
// up on their own. A theme that gave this row a hover fill would load, pass every
// check in tests/, and offer a target that answers to nothing.
//
// THE MUTE BUTTON IS A 32-SQUARE SUBTLE BUTTON AND NOT A CIRCLE. Windows has no
// round buttons: the volume flyout's mute control is a square backplate at
// ControlCornerRadius with a Segoe Fluent glyph in it, filling on hover and
// dimming on press, with no transition either way. Genesis's `radius: height / 2`
// is genesis.
//
// THE PERCENTAGE IS WIDTH-LOCKED ON THE WORD "muted", which is the one number in
// this file with a reason that is not a look. The reading swaps between `93%`
// and `muted` as the button is pressed, and those are different widths; left to
// size itself the text would jog sideways every time, and the slider under it --
// which is anchored to this text's right edge -- would change length with it.
// Pinning the width to the wider of the two strings, measured in the font it is
// actually drawn in, holds both still.
//
// A HIDDEN Text AND NOT A TextMetrics, and that is measured rather than
// preferred: the two do not agree about the width of one string in one font, and
// the Text is the one that is right, because the Text is the one that draws.
// Measured offscreen, the string "muted":
//
//   fontSize 11   TextMetrics 39.00   Text 38.98    <- a wash
//   fontSize 14   TextMetrics 49.00   Text 50.94    <- 1.94 short
//   fontSize 16   TextMetrics 58.00   Text 59.92    <- 1.92 short
//
// So the shipped size was the one size a TextMetrics happened to get right, and
// the fault only appeared for somebody who had turned the type up. A reservation
// that is short does not clip here -- there is no elide -- it paints the word out
// past its own left edge and into the gap the name beside it was bounded to
// leave. That finding is about Qt and not about genesis, so it carries over
// whole; what changed with the theme is the FONT it is measured in, and the
// measurement follows it because the hidden Text copies the visible one's.
//
// THE SLIDER IS components/VolumeSlider.qml AND THIS FILE DOES NOT DRAW ONE.
// Its rail, its handle and its notch are that component's; what is here is where
// it sits and what it is told.

import QtQuick
import qs
import qs.components
import qs.themes.windows

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in genesis's ToggleRow.qml on why it is `required`, why it is typed rather
    // than `var`, and why `StreamRow` here is the facade and not this file.
    required property StreamRow row

    // Read once at the top level, where rule 1's typed `row` still checks it,
    // rather than in each of the six places below.
    readonly property bool muted: root.row.muted

    // WHAT THE FACADE READS BACK. Two stacked bands, always -- the name above and
    // the slider below -- and the sum rather than a constant, because the second
    // band's height is the VolumeSlider's own and this theme's is not genesis's.
    // The facade floors at 52, which is what 32 plus a 20-tall slider comes to;
    // a taller slider makes a taller row and the floor never bites.
    //
    // Not derived from `root.height`, which would be rule 2's loop: the two terms
    // are a constant and a child's implicit size.
    implicitHeight: band.height + volume.implicitHeight

    Item {
        id: band

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Fluent.controlHeight

        Rectangle {
            id: mute

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.controlHeight
            height: Fluent.controlHeight
            radius: Fluent.controlRadius

            // The subtle ramp: nothing at rest, brighter on hover, dimmer on
            // press. No Behavior -- Windows swaps the brush at time zero and
            // Fluent.hoverMs is 0 to say so.
            color: muteMouse.pressed ? Theme.surfaceContainer
                : muteMouse.containsMouse ? Fluent.fillSubtleHover
                : "transparent"

            Text {
                anchors.centerIn: parent
                text: root.muted ? root.row.mutedGlyph : root.row.glyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: root.muted ? Theme.outline : Theme.textOnSurface
            }

            MouseArea {
                id: muteMouse

                anchors.fill: parent
                enabled: root.enabled
                hoverEnabled: true

                // The arrow, like every other control in Windows: the hand is a
                // web idiom and the shell does not use it.
                cursorShape: Qt.ArrowCursor

                // THE FACADE DOES IT, not this file. See the header.
                onClicked: root.row.toggleMute()
            }
        }

        Text {
            id: percent

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            // See the header: this is the whole reason the hidden Text below
            // exists.
            width: mutedMetrics.implicitWidth
            horizontalAlignment: Text.AlignRight

            text: root.muted ? mutedMetrics.text : `${Math.round(root.row.volume * 100)}%`
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            color: root.muted ? Theme.outline : Theme.textOnSurfaceVariant

            Text {
                id: mutedMetrics

                visible: false
                font: percent.font
                text: "muted"
            }
        }

        // The name and where the sound is going, on ONE line. They were two for a
        // version, with the route underneath, and it made every application three
        // rows tall for a fact that fits in the gap at the end of the first one.
        Row {
            anchors.left: mute.right
            anchors.leftMargin: Theme.itemSpacing
            anchors.right: percent.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                id: name

                anchors.verticalCenter: parent.verticalCenter

                // Bounded rather than left to elide against the Row, which hands
                // every child the width it asks for -- an application with a long
                // name would push the route off the end instead of giving way to
                // it.
                width: Math.min(implicitWidth, parent.width * 0.5)
                elide: Text.ElideRight

                text: root.row.label
                font.family: Theme.fontFamily

                // Body at NORMAL weight. Windows 11's typography rule is Semibold
                // for emphasis and never for running text, and an application's
                // name in a list of applications is not emphasis; genesis set
                // Theme.fontWeight here, which under this theme is 600.
                font.pointSize: Fluent.bodySize
                font.weight: Fluent.normalWeight
                color: root.muted ? Theme.outline : Theme.textOnSurface
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.row.route !== ""

                width: Math.min(implicitWidth, parent.width - name.width - parent.spacing)
                elide: Text.ElideRight

                text: `· ${root.row.routePrefix} ${root.row.route}`
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                font.weight: Fluent.normalWeight
                color: Theme.textOnSurfaceVariant
            }
        }
    }

    VolumeSlider {
        id: volume

        wheelEnabled: false

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding + Fluent.controlHeight + Theme.itemSpacing
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.top: band.bottom

        value: root.row.volume
        maximum: 1.5
        notch: 1
        accent: root.muted ? Theme.outline : Theme.primary

        // Straight through to the facade, for the reason on the mute button
        // above.
        onMoved: value => root.row.setVolume(value)
    }
}
