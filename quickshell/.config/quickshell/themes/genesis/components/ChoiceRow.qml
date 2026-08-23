// How genesis draws a small closed choice. The public half -- what the pages
// write, what an option is, and what `chosen` means -- is
// components/ChoiceRow.qml, and this file is everything that was below those
// comments before the split, moved unchanged.
//
// SEGMENTS AND NOT A DROPDOWN, which is this theme's answer and is now written
// where the answer is given. A dropdown hides every option but the chosen one
// behind a click, which is the right trade when there are twenty of them and
// the wrong one when there are three: here the alternatives are the
// information. It also needs a popup surface, a focus grab and a way out of
// it, none of which this shell has -- the tray menus are the only popup in it
// and they come off D-Bus.
//
// THE CEILING IS ABOUT FOUR OPTIONS AT THIS WIDTH, and it is a promise this
// file keeps rather than one the facade can require. Past four the segments get
// too narrow to label and the answer is a different control, not a smaller
// font. Two pages say in as many words that they are inside that ceiling --
// see the headers of BarPage.qml and RecordingPage.qml -- so a theme that
// widens or narrows the track is answering them.
//
// IT READS `row` AND NEVER WRITES TO IT. `row.value` is what the page handed
// down; a click on a segment calls `row.chosen(...)` to ask for a different
// one. And the unpacking of an option is the facade's: `row.valueOf()` and
// `row.labelOf()` are called, never reimplemented here, because they are the
// API's contract about what a caller may put in `options` and getting them
// backwards would mean drawing the right control around the wrong answer.
//
// TWO STOREYS, AND THE HEIGHT SAYS SO. The label line on top, the segment
// track underneath: side by side the segments were squeezed into whatever was
// left after "Interface font", which made a three-way choice look like an
// afterthought. That arrangement is what implicitHeight below reports back to
// the facade, which has no way to work it out for itself.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `ChoiceRow` here is the facade and not
    // this file.
    required property ChoiceRow row

    // WHAT THE FACADE READS BACK. The label line plus the segment track less
    // their overlap, which is a number about this theme's two-storey layout and
    // nothing the host could reconstruct. It is what the row was before the
    // split, term for term.
    implicitHeight: Theme.groupHeight + segments.height - 4

    radius: Theme.groupRadius
    color: mouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    // The dim is drawing and it lives here; `enabled` itself arrives down the
    // item tree with nothing forwarded by hand. See rule 6 in README.md --
    // including why the MouseAreas below still say `enabled: root.enabled`
    // while this line does not say `row.enabled`.
    opacity: root.enabled ? 1 : 0.4

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Row {
        id: labelRow

        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.row.glyph !== ""
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.row.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Item {
            id: hintMark

            anchors.verticalCenter: parent.verticalCenter
            visible: root.row.hint !== ""
            implicitWidth: Theme.groupHeight - 12
            implicitHeight: Theme.groupHeight - 12

            Text {
                anchors.centerIn: parent
                text: Icons.info
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: hintMouse.containsMouse ? Theme.primary : Theme.outline

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            MouseArea {
                id: hintMouse

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }
    }

    // THE BAND IS THE LABEL LINE AND NOT THE WHOLE ROW, which is what makes
    // this row different from the others. A ChoiceRow is two storeys: the
    // label with its mark on top, the segment track underneath. A note
    // measured off the whole row would open below the segments, a long way
    // from the mark that asked for it and with a control in between; measured
    // off the label line it opens right under the words it is explaining, and
    // covers the segments, which is fine -- they are still there when it
    // fades.
    //
    // Which is also why the band matters rather than just a y: when there is
    // no room below, Tooltip flips it above the LABEL LINE, not above the
    // segments, so the note stays attached to the same end of the row either
    // way.
    //
    // Tooltip is still the host's component and not a themed one -- it has not
    // been split, and until it is, this instantiates components/Tooltip.qml.
    // The extra Loader between this item and the row changes nothing it
    // depends on: Tooltip sums `y` up the parent chain to whatever ancestor
    // clips, and both of the items the split inserted sit at y=0.
    Tooltip {
        text: root.row.hint
        shown: hintMouse.containsMouse

        x: Theme.groupPadding
        anchorY: labelRow.y
        anchorHeight: labelRow.height
        gap: 2
        z: 200
    }

    // The track behind the segments, so the unchosen ones read as part of one
    // control rather than as three loose buttons.
    Rectangle {
        id: segments

        anchors.top: labelRow.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding

        height: Theme.groupHeight - 8
        radius: height / 2
        color: Qt.alpha(Theme.surfaceContainerHighest, 0.5)

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 3

            Repeater {
                model: root.row.options

                Rectangle {
                    id: segment

                    required property var modelData
                    required property int index

                    readonly property bool current: root.row.valueOf(modelData) === root.row.value

                    // Equal shares of the track, minus nothing: the segments
                    // touch, which is what makes them one control. A gap here
                    // and it is a row of pills again.
                    width: segments.width / Math.max(1, root.row.options.length) - 6 / Math.max(1, root.row.options.length)
                    height: parent.height
                    radius: height / 2

                    color: segment.current ? Theme.primary
                        : segmentMouse.containsMouse ? Theme.surfaceContainerHigh
                        : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.row.labelOf(segment.modelData)
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        font.weight: segment.current ? Font.Bold : Theme.fontWeight
                        color: segment.current ? Theme.textOnPrimary : Theme.textOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }
                    }

                    MouseArea {
                        id: segmentMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.enabled
                        onClicked: root.row.chosen(root.row.valueOf(segment.modelData))
                    }
                }
            }
        }
    }
}
