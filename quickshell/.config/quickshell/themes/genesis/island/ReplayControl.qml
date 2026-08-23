// Instant replay: is it running, and keep the last thirty seconds.
//
// TWO CONTROLS, AND IT USED TO BE FIVE. The switch and the save button are
// what is here; a row of four length chips with the buffer's size in RAM
// beside them, and a row of monitor chips with the connector name beside
// those, are what left. They were not wrong -- each was added to fix something
// real -- they simply stopped being the only way to reach those settings.
//
// WHERE THEY WENT. modules/settings/pages/RecordingPage.qml owns the buffer's
// configuration now: the length, whether it lives in RAM or on disk, which
// screen, the codec, the container, the bitrate and its mode, the framerate
// and the microphone. It explains each one beside the control, it can offer
// the codecs THIS card actually has an encoder for, and it does not have to
// fit in a column of a popout.
//
// WHAT A KEYSTROKE-OPENED PANEL IS FOR is the other half of it: the act, not
// the settings. Whether the buffer is running, and the button that turns the
// last thirty seconds into a file.
//
// TWO ROWS BECAME ONE. The dashboard's actions strip is a single line shared
// with the three capture targets, so the header line this used to carry is
// gone and everything it said had to find a place on the button:
//
//   "Instant replay"     the switch is on -- so the button offers the save
//   "Replay elsewhere"   another shell holds the buffer. THREE ANSWERS AND
//                        NOT TWO: a shell that stood down for another one has
//                        the switch ON and no buffer, and calling that "off"
//                        would send somebody to a switch already where they
//                        want it. See ReplayState.heldElsewhere
//   "Replay off"         the switch is off
//
// THE CONNECTOR NAME STAYED, on the button's right, and that is deliberate
// rather than an oversight in the trimming. The monitor chips were added
// because their absence cost a clip: the buffer followed the shell's own
// screen with nothing on screen saying which one that was. CHOOSING the screen
// belongs with the rest of the configuration; SEEING which one it is belongs
// wherever the save button is.
//
// AND THE SAVE BUTTON LOOKS LIKE A BUTTON NOW. It was a bare label with a
// background that only appeared on hover, which on a photographic ground is
// indistinguishable from a caption -- see the long note in RecordControl.qml
// for why that happens and what the rule is. It carries a fill at rest, and a
// stronger one than the three capture targets beside it: this is the control
// that produces a file, and it is the reason the buffer is running at all.
//
// THE COLOURS COME FROM THE CALLER, for the reason RecordControl.qml gives.
//
// The state, the process and the persisted duration live in
// modules/recorder/ReplayState.qml.

import QtQuick
import qs
import qs.modules.island
import qs.modules.recorder

Item {
    id: root

    property color ink: Theme.textOnSurface
    property color inkMuted: Theme.textOnSurfaceVariant

    // One step brighter than RecordControl's pair, at rest and on hover
    // alike.
    property color rest: Theme.surfaceContainerHighest
    property color wash: Theme.primary
    property color stroke: Theme.outlineVariant

    // What is legible ON the switch's own fill when it is on.
    property color inkInverse: Theme.textOnPrimary

    implicitWidth: line.implicitWidth
    implicitHeight: 40

    // ---- EVERY LABEL IN HERE RESERVES ITS WIDEST FORM ----
    //
    // Toggling the replay resized the whole dashboard. The panel's width is
    // derived from the row this control sits in -- deliberately, so that a
    // larger Theme.fontSize widens the panel instead of eliding "Display"
    // down to "Disp..." -- and the save button's label changes length with
    // the state:
    //
    //   armed            "Save last 30s"
    //   held elsewhere   "Replay elsewhere"
    //   off              "Replay off"
    //
    // Deriving a container's size from live content is right. It is only SAFE
    // when the content reserves its own widest case, and this did not: it
    // reserved whichever string happened to be showing, so flipping a switch
    // moved the edge of the panel.
    //
    // Measured rather than guessed at, because the widest of the three is not
    // the one with the most characters at every font: "Replay elsewhere" is
    // sixteen and "Save last 120s" is fourteen, and which draws wider depends
    // on the face.
    //
    // THE SECONDS ARE PART OF THE CANDIDATE SET, so the reservation follows a
    // change to the configured buffer length. That is a settings change made
    // twice a year rather than a switch flipped daily, and it is the one case
    // where the panel is allowed to resize.
    //
    // THROUGH THE GROUP PROPERTIES AND NOT Qt.font(), WHICH TAKES AN INT POINT
    // SIZE AND THIS ONE IS NOT AN INT. `Theme.fontSize * 0.85` is 9.35 at the
    // shipped size of 11 and 11.9 at 14, and the error moved with the setting.
    // Measured offscreen against this theme's own tokens, this face came back
    // 9.0 through Qt.font() and comes back 9.35 through the spelling below --
    // the one a FontMetrics uses, the one components/Chip.qml in this theme
    // argues for at length, and the one mNoScreen further down has always had.
    //
    // THAT TRUNCATION WAS SELF-CONSISTENT, which is why it survived three
    // passes over this file: the same 9.0 fed the reservation and the label,
    // so nothing ever drifted and nothing ever clipped. It was silently not
    // what this line asked for rather than a layout that was wrong.
    //
    // NOT `readonly`, which grouped syntax does not allow, and which is the
    // one thing given up here. Nothing outside writes it -- Dashboard.qml
    // instantiates this control with six colours and nothing else -- and the
    // three lines below are the only bindings on it, live in the same way the
    // single Qt.font() binding was.
    property font labelFont
    labelFont.family: Theme.fontFamily
    labelFont.pointSize: Theme.fontSize * 0.85
    labelFont.weight: Font.Bold

    // ---- AND THE RESERVATION IS MEASURED BY THE THING THAT DRAWS ----
    //
    // These were three TextMetrics and had to stop being, because a
    // TextMetrics AND A Text DISAGREE ABOUT THE SAME FONT at a fractional
    // point size, and the size above became fractional the moment Qt.font()
    // went. That is not a subtlety about bounding boxes against advances; it
    // is a whole pixel size apart. Measured offscreen against this theme's own
    // tokens, "Replay elsewhere" in this face:
    //
    //   pointSize 9.0    TextMetrics 115.00   Text 115.00   ink 113 px
    //   pointSize 9.35   TextMetrics 115.00   Text 124.75   ink 123 px
    //
    // The ink is the row that settles it -- the string rendered onto a white
    // ground and the painted pixels counted -- and it follows the Text. A
    // TextMetrics quantises 9.35 back onto the very face it uses for 9.0, to
    // the hundredth of a pixel; the Text lays out on a larger one and paints
    // ten pixels wider. The gap is not monotonic either, so it cannot be
    // corrected with a factor: at 10.2 the TextMetrics is the one that reads
    // HIGH, 134.25 against the Text's 124.75.
    //
    // So the reservation would have gone on reporting 115.00 while the widest
    // state painted 124.75 into it -- the button's padding falling from 13 px
    // a side to 8.1 in that one state, with the whole point of this block
    // being that the reserved width IS the drawn width. Three hidden Texts
    // cannot have that fault: the object that measures is the object that
    // draws, at any size, whatever Qt does with the face underneath.
    //
    // THE CONNECTOR PAIR FURTHER DOWN IS STILL A TextMetrics, and that is not
    // an oversight: its face, `Theme.fontSize * 0.78`, is one the two sides do
    // agree on -- 59.34 both ways for "no screen". It has a DIFFERENT fault,
    // older than this change and not fixed by it: `connectorReserve` is built
    // from `.width`, the bounding box, where the label draws to the ADVANCE.
    // Measured, "no screen" wants 59.34 in a reservation of 58.00 and the
    // readout's `elide: Text.ElideRight` fires -- `truncated` comes back true.
    // That is the fallback string eliding inside a box sized for it, and it
    // wants its own change rather than a ride on this one.
    //
    // `visible: false` and nothing else. They are children of this Item and
    // not of the Row below, so they are outside the layout, and an invisible
    // item is not drawn. It still lays its string out: measured here, all
    // three answer implicitWidth -- 101.36, 124.75 and 77.97 at the shipped
    // font size -- with nothing on screen.
    Text {
        id: mSave

        visible: false
        font: root.labelFont
        text: `Save last ${ReplayState.seconds}s`
    }

    Text {
        id: mElsewhere

        visible: false
        font: root.labelFont
        text: "Replay elsewhere"
    }

    Text {
        id: mOff

        visible: false
        font: root.labelFont
        text: "Replay off"
    }

    readonly property real widestLabel: Math.max(mSave.implicitWidth,
        mElsewhere.implicitWidth, mOff.implicitWidth)

    // The connector readout is the other one, and it cannot reserve its own
    // widest form because a connector name is whatever the kernel says.
    // So it reserves a CONSTANT instead -- the wider of the two fixed strings
    // it can be measured against -- and anything longer elides. A name that
    // elides is a readout that is still there; a name that moves the panel's
    // edge is the bug this is fixing.
    TextMetrics {
        id: mNoScreen

        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize * 0.78
        text: "no screen"
    }

    TextMetrics {
        id: mConnector

        font: mNoScreen.font
        text: "HDMI-A-1"
    }

    readonly property real connectorReserve: Math.max(mNoScreen.width, mConnector.width)

    Row {
        id: line

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        spacing: Theme.itemSpacing

        // ---------------- Save ----------------
        //
        // The one control in the panel that produces a file, and the reason
        // the buffer is running at all. THE LENGTH IS ON THE BUTTON: the
        // number was always the useful half of the chips that carried it --
        // what this is about to hand you -- and it is the half that has to be
        // visible at the moment of pressing.
        Rectangle {
            id: save

            anchors.verticalCenter: parent.verticalCenter

            // Built from the RESERVED label width rather than from the row,
            // so it is the same number in all three states.
            implicitWidth: saveGlyph.implicitWidth + saveRow.spacing + root.widestLabel + 26
            implicitHeight: 40
            radius: 10

            opacity: ReplayState.armed ? 1 : 0.45
            color: saveMouse.containsMouse && ReplayState.armed ? root.wash : root.rest
            border.width: 1
            border.color: root.stroke
            antialiasing: true

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            // Pressed state, so the click lands somewhere rather than only in
            // the island a moment later.
            scale: saveMouse.pressed ? 0.97 : 1

            Behavior on scale {
                NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
            }

            Row {
                id: saveRow

                anchors.centerIn: parent
                spacing: 7

                Text {
                    id: saveGlyph

                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.replay
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: ReplayState.armed ? root.ink : root.inkMuted
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    // The reserved width, with the text centred in it, so the
                    // shorter states sit in the middle of the button rather
                    // than leaving all the slack on one side.
                    width: root.widestLabel
                    horizontalAlignment: Text.AlignHCenter

                    text: ReplayState.armed ? `Save last ${ReplayState.seconds}s`
                        : ReplayState.heldElsewhere ? "Replay elsewhere" : "Replay off"
                    font: root.labelFont
                    color: root.ink
                }
            }

            MouseArea {
                id: saveMouse

                anchors.fill: parent
                enabled: ReplayState.armed
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                // The panel goes away with the click. Watching a dashboard
                // while it saves the last thirty seconds -- of a dashboard --
                // is not what anyone wants the clip to contain, and the island
                // confirms the save on its own.
                onClicked: {
                    IslandState.closeDashboard();
                    ReplayState.save();
                }
            }
        }

        // The connector gpu-screen-recorder was actually handed, not the
        // monitor as a person names it. Those two disagree in exactly one case
        // -- a chosen monitor that is not plugged in -- and that is the case
        // worth being able to see. Amber then: the buffer is running, it is
        // simply not running where it was told to.
        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: Screens.all.length > 1 || ReplayState.monitorMissing

            // Constant, so a connector name cannot move the panel's edge.
            width: root.connectorReserve
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight

            text: ReplayState.monitor === "" ? "no screen" : ReplayState.monitor
            font: mNoScreen.font
            color: ReplayState.monitorMissing ? Theme.warning : root.inkMuted

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        // ---------------- The switch ----------------
        //
        // THE DRAWING PUT A DOT HERE, and a dot is a state rather than a
        // control: it says whether the buffer is running and gives you nothing
        // to press. Arming it is one of the two things this panel is for, so
        // it keeps the switch it had -- same size, same travel, in the panel's
        // ink rather than in an accent that could land on a ground of its own
        // colour.
        Rectangle {
            id: toggle

            anchors.verticalCenter: parent.verticalCenter

            width: 40
            height: 22
            radius: height / 2
            color: ReplayState.armed ? Qt.alpha(root.ink, 0.92) : Qt.alpha(root.ink, 0.2)

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Rectangle {
                x: ReplayState.armed ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter

                width: 16
                height: 16
                radius: height / 2
                color: ReplayState.armed ? root.inkInverse : Qt.alpha(root.ink, 0.6)

                Behavior on x {
                    NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ReplayState.toggle()
            }
        }
    }
}
