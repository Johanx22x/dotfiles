// Who this desktop belongs to, at the top of the sidebar.
//
// The macOS arrangement, and it earns its place for the same reason there: a
// settings window is where you go to change things about YOUR session, and
// the name at the top is what says whose session it is. It is also the only
// entry in the rail that is a person rather than a subject, which is why it
// sits above the list with a gap rather than inside it.
//
// THE PICTURE IS OPTIONAL AND THERE IS NONE ON THIS MACHINE. Checked, not
// assumed: there is no ~/.face, no AccountsService user record, and the GECOS
// field in /etc/passwd is empty -- so there is no full name to show either.
// Rather than an empty circle and a blank line, the fallback is the initial
// over the accent, which is what every application that has ever had this
// problem settles on. Drop a square image at ~/.face and it is used instead;
// nothing else has to change.

import Quickshell
import QtQuick
import QtQuick.Effects
import "root:/"

Rectangle {
    id: root

    property bool selected: false

    signal clicked

    readonly property string avatarPath: `${Quickshell.env("HOME")}/.face`

    width: parent ? parent.width : implicitWidth
    implicitWidth: 200
    implicitHeight: 56

    radius: Theme.cardRadius

    color: root.selected ? Theme.primaryContainer
        : mouse.containsMouse ? Theme.surfaceContainerHigh
        : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        Rectangle {
            id: avatar

            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38
            radius: height / 2

            color: root.selected ? Theme.primary : Theme.primaryContainer

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }

            Text {
                anchors.centerIn: parent
                visible: picture.status !== Image.Ready
                text: SessionInfo.user.charAt(0).toUpperCase()
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize + 4
                font.weight: Font.Bold
                color: root.selected ? Theme.textOnPrimary : Theme.textOnPrimaryContainer

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // ROUND, AND THAT TAKES AN EFFECT. An Image has no radius, and
            // clip on a rounded Rectangle clips to its bounding box and not
            // to its curve -- a photo in one would come out square with
            // rounded corners painted behind it. MultiEffect's mask is the
            // supported way to do this in Qt 6 (6.11 here), and it costs one
            // offscreen texture 38 pixels across.
            Image {
                id: picture

                anchors.fill: parent
                source: `file://${root.avatarPath}`
                fillMode: Image.PreserveAspectCrop
                // Asked for at twice the size it is drawn at, so it stays
                // sharp on a scaled output without a 1024px portrait being
                // held in memory to be shown at 38.
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                // A missing file is the normal case here, not an error.
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: picture
                visible: picture.status === Image.Ready
                maskEnabled: true
                maskSource: mask
                maskSpreadAtMin: 1
            }

            Item {
                id: mask

                anchors.fill: parent
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - avatar.width - parent.spacing
            spacing: 1

            Text {
                width: parent.width
                text: SessionInfo.displayName
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: root.selected ? Theme.textOnPrimaryContainer : Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                width: parent.width
                text: `${SessionInfo.user}@${SessionInfo.host}`
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 3
                color: root.selected ? Theme.textOnPrimaryContainer : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
