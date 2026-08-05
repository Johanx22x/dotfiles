// A settings row with a small closed set of answers, shown as segments.
//
// SEGMENTS AND NOT A DROPDOWN. A dropdown hides every option but the chosen
// one behind a click, which is the right trade when there are twenty of them
// and the wrong one when there are three: here the alternatives are the
// information. It also needs a popup surface, a focus grab and a way out of
// it, none of which this shell has -- the tray menus are the only popup in it
// and they come off D-Bus.
//
// The ceiling is about four options at this width. Past that the segments get
// too narrow to label and the answer is a different control, not a smaller
// font.

import QtQuick
import "root:/"

Rectangle {
    id: root

    property string glyph: ""
    property string label: ""

    // Either plain strings, or objects with `label` and `value` when what is
    // shown and what is stored differ -- which they do for font families,
    // where "Propo" is the useful label and "JetBrainsMono Nerd Font Propo"
    // is the value.
    property var options: []
    property var value: null

    property string hint: ""

    signal chosen(var value)

    function valueOf(option: var): var {
        return option !== null && typeof option === "object" ? option.value : option;
    }

    function labelOf(option: var): string {
        return option !== null && typeof option === "object" ? option.label : String(option);
    }

    // See the note in ToggleRow: the parent supplies the width.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320
    // Taller than the other rows, because the segments sit under the label
    // rather than beside it. Side by side they were squeezed into whatever
    // was left after "Interface font", which made a three-way choice look
    // like an afterthought.
    implicitHeight: Theme.groupHeight + segments.height - 4

    radius: Theme.groupRadius
    color: mouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

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
            visible: root.glyph !== ""
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
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
            visible: root.hint !== ""
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

    Tooltip {
        text: root.hint
        shown: hintMouse.containsMouse

        x: Theme.groupPadding
        y: labelRow.y + labelRow.height + 2
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
                model: root.options

                Rectangle {
                    id: segment

                    required property var modelData
                    required property int index

                    readonly property bool current: root.valueOf(modelData) === root.value

                    // Equal shares of the track, minus nothing: the segments
                    // touch, which is what makes them one control. A gap here
                    // and it is a row of pills again.
                    width: segments.width / Math.max(1, root.options.length) - 6 / Math.max(1, root.options.length)
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
                        text: root.labelOf(segment.modelData)
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
                        onClicked: root.chosen(root.valueOf(segment.modelData))
                    }
                }
            }
        }
    }
}
