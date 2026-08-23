// How genesis draws one application making noise. The public half -- why this
// is not a ListRow, and why the two writes to PipeWire are on the other side of
// the seam -- is components/StreamRow.qml.
//
// NO HOVER FILL ON THE ROW ITSELF, and that is the promise the facade cannot
// require. There is nowhere for a click on this row to go: the sound page
// cannot reroute a stream, so the row is a reading with two controls sitting on
// it rather than a control in its own right. InfoRow's rule applies whole --
// the cheapest way to tell a control from a reading is that a control lights
// up -- and the two things here that DO respond, the round mute button and the
// slider, light up on their own. A theme that gave this row a hover fill would
// load, pass every check in tests/, and offer a target that answers to nothing.
//
// THE PERCENTAGE IS WIDTH-LOCKED ON THE WORD "muted", which is the one number
// in this file with a reason that is not a look. The reading swaps between
// `93%` and `muted` as the button is pressed, and those are different widths;
// left to size itself the text would jog sideways every time, and the slider
// under it -- which is anchored to this text's right edge -- would change
// length with it. Pinning the width to the wider of the two strings, measured
// in the font it is actually drawn in, holds both still. The literal is here
// and not on the facade because the metric belongs to whoever chose the font.

import QtQuick
import qs
import qs.components

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `StreamRow` here is the facade and not
    // this file.
    required property StreamRow row

    // Read once at the top level, where rule 1's typed `row` still checks it,
    // rather than in each of the eight places below.
    readonly property bool muted: root.row.muted

    // WHAT THE FACADE READS BACK. Two stacked bands, always -- the name above
    // and the slider below -- so this is a constant and the facade floors at
    // the same number rather than holding a second opinion about it.
    implicitHeight: 52

    Rectangle {
        id: mute

        anchors.left: parent.left

        // Six inside the page's own padding, because this is a round target and
        // the row above it is a line of type: aligning the CIRCLE to the text's
        // left edge puts the glyph inside it visibly indented.
        anchors.leftMargin: Theme.groupPadding - 6
        anchors.top: parent.top
        anchors.topMargin: 3

        width: 30
        height: 30
        radius: height / 2
        color: muteMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Text {
            anchors.centerIn: parent
            text: root.muted ? root.row.mutedGlyph : root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize - 1
            color: root.muted ? Theme.outline : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        MouseArea {
            id: muteMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // THE FACADE DOES IT, not this file. `row.node` is a PipeWire node
            // and rule 5 in README.md says nothing under a theme directory may
            // know what one of those is. See the facade's header: the direction
            // is still the one ToggleRow's rule 4 sets out -- the theme asks,
            // and the half that owns the value acts.
            onClicked: root.row.toggleMute()
        }
    }

    Text {
        id: percent

        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: mute.verticalCenter

        // See the header: this is the whole reason the TextMetrics below
        // exists.
        width: mutedMetrics.width
        horizontalAlignment: Text.AlignRight

        text: root.muted ? mutedMetrics.text : `${Math.round(root.row.volume * 100)}%`
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        color: root.muted ? Theme.outline : Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        TextMetrics {
            id: mutedMetrics

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
        anchors.verticalCenter: mute.verticalCenter
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
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: root.muted ? Theme.outline : Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.row.route !== ""

            width: Math.min(implicitWidth, parent.width - name.width - parent.spacing)
            elide: Text.ElideRight

            text: `· ${root.row.routePrefix} ${root.row.route}`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 2
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    VolumeSlider {
        wheelEnabled: false

        anchors.left: mute.right
        anchors.leftMargin: Theme.itemSpacing
        anchors.right: percent.right
        anchors.top: mute.bottom
        anchors.topMargin: -2

        value: root.row.volume
        maximum: 1.5
        notch: 1
        accent: root.muted ? Theme.outline : Theme.primary

        // Straight through to the facade, for the reason on the mute button
        // above.
        onMoved: value => root.row.setVolume(value)
    }
}
