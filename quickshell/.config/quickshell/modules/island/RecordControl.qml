// Start a screen recording, and choose what to record.
//
// Three buttons and not a button plus a dialog: the target IS the choice, so
// asking it as a second step would be a dialog whose only content is what
// these three already say. While a recording is running the same row collapses
// to one stop button -- there is nothing else to decide at that point.
//
// THEY NOW LOOK LIKE BUTTONS, WHICH THEY DID NOT, and the reason they did not
// is worth writing down because it is a trap this whole panel can fall into
// again. On an ordinary card a button can be a bare label, because the card's
// own edge tells you where the surface is and the label is simply what is
// written on it. The dashboard's ground is a PHOTOGRAPH -- there is no edge
// anywhere -- so a label whose background only appears on hover is
// indistinguishable from a caption until the pointer is already on it. It read
// as text because it was text.
//
// So every one of these carries a fill AT REST, one step brighter on hover.
// The rule that goes with it, and the half that does the real work: nothing
// that cannot be pressed gets a surface. The readings, the clock, the date and
// the elapsed time stay bare, and the contrast between them is what makes
// these read as controls.
//
// THE GLYPH WENT AND THE WORD STAYED. They were a glyph stacked over a label
// in a 56-pixel tile, and the note here used to say the glyph was what stopped
// the three buttons from being "mostly text". The fill does that job now, and
// it does it at rest rather than on hover -- so the glyph was paying for a
// problem that no longer exists, in the one dimension this row has none of.
// The word is what anybody actually reads.
//
// THE COLOURS COME FROM THE CALLER, because Theme is the WALLPAPER's palette
// and the wallpaper is not what is behind this. The defaults are the roles
// that used to be read here, so the component still works anywhere else.
//
// The state, the command and the reasoning about SIGINT live in
// modules/recorder/RecorderState.qml.

import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/modules/recorder"

Item {
    id: root

    property color ink: Theme.textOnSurface
    property color rest: Theme.surfaceContainerHighest
    property color wash: Theme.primary
    property color stroke: Theme.outlineVariant
    property color danger: Theme.critical

    // THE WIDER OF THE TWO STATES AND NOT THE ONE CURRENTLY SHOWING. The
    // panel's width is derived from the row this sits in, so a control that
    // reports only its live width moves the edge of the dashboard every time
    // its state changes -- which is exactly what the replay's save button was
    // doing when the switch was flipped. Starting a recording swaps three
    // targets for one stop button; reserving the maximum means the panel does
    // not jump when it does.
    implicitWidth: Math.max(targets.implicitWidth, stop.implicitWidth)
    implicitHeight: 40

    // ---------------- Idle: pick a target ----------------
    RowLayout {
        id: targets

        anchors.fill: parent
        spacing: 6
        visible: !RecorderState.recording

        Repeater {
            model: [
                {
                    id: "display",
                    label: "Display"
                },
                {
                    id: "window",
                    label: "Window"
                },
                {
                    id: "region",
                    label: "Region"
                }
            ]

            Rectangle {
                id: option

                required property var modelData

                // FILL THE ROW, but never below what the word needs: the
                // panel's own width is derived from this row's implicit
                // width, so a larger Theme.fontSize widens the panel rather
                // than eliding "Display" down to "Disp...".
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                implicitWidth: label.implicitWidth + 22
                implicitHeight: 40
                radius: 10

                color: optionMouse.containsMouse ? root.wash : root.rest
                border.width: 1
                border.color: root.stroke
                antialiasing: true

                scale: optionMouse.pressed ? 0.97 : 1

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                Behavior on scale {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }

                Text {
                    id: label

                    anchors.centerIn: parent
                    text: option.modelData.label
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize * 0.85
                    font.weight: Font.Bold
                    color: root.ink
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    // The panel has to go BEFORE the selection tool appears:
                    // the dashboard is held open by a focus grab, and slurp
                    // cannot take a click while that grab is live. The waiting
                    // is done by RecorderState and not here, because this
                    // component is destroyed by the very close it just asked
                    // for. See the note on startDelayed.
                    onClicked: {
                        IslandState.closeDashboard();
                        RecorderState.startDelayed(option.modelData.id);
                    }
                }
            }
        }
    }

    // ---------------- Recording: one way out ----------------
    Rectangle {
        id: stop

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: stopRow.implicitWidth + 26
        implicitHeight: 40
        radius: 10

        visible: RecorderState.recording
        color: stopMouse.containsMouse ? root.danger : Qt.alpha(root.danger, 0.28)
        border.width: 1
        border.color: Qt.alpha(root.danger, 0.5)
        antialiasing: true

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Row {
            id: stopRow

            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.stop
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: root.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Stop and save"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize * 0.85
                font.weight: Font.Bold
                color: root.ink
            }
        }

        MouseArea {
            id: stopMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: RecorderState.stop()
        }
    }
}
