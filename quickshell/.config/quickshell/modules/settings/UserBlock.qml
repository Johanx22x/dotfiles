// Who this desktop belongs to, at the top of the sidebar.
//
// The macOS arrangement, and it earns its place for the same reason there: a
// settings window is where you go to change things about YOUR session, and
// the name at the top is what says whose session it is. It is also the only
// entry in the rail that is a person rather than a subject, which is why it
// sits above the list with a gap rather than inside it.
//
// THE PICTURE IS OPTIONAL, and the fallback is the initial over the accent --
// what every application that has ever had this problem settles on. It is
// what a fresh machine shows: there is no AccountsService user record here and
// the GECOS field in /etc/passwd is empty, so there is no full name either and
// the username stands in for both.
//
// The picture itself is ~/.face, set from the User page of this window through
// the `desktop-avatar` script. It is deliberately NOT a path of this shell's
// own: ~/.face is the freedesktop convention, so a display manager finds the
// same picture.

import Quickshell
import QtQuick
import QtQuick.Effects
import "root:/"

Rectangle {
    id: root

    property bool selected: false

    signal clicked

    readonly property string avatarPath: SessionInfo.avatarPath

    // RELOADED BY HAND, because an Image will not do it on its own: it caches
    // by URL, and the URL of the profile picture never changes -- only its
    // contents do. Setting the source to nothing and back is what makes it
    // read the file again, and `cache: false` on the Image is what stops the
    // second assignment being answered out of the cache anyway.
    //
    // A query string on the URL would be the shorter trick, and it is not used
    // here: appending ?v=2 to a file:// URL asks the filesystem for a file
    // whose name ends in "?v=2".
    readonly property int revision: SessionInfo.avatarRevision

    onRevisionChanged: {
        picture.source = "";
        picture.source = `file://${root.avatarPath}`;
    }

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

            // ROUND, AND THAT TAKES AN EFFECT. An Image is a rectangle: put
            // inside a rounded parent it keeps its own square corners, and
            // `clip` does not help because it clips to the bounding box and
            // not to the curve. The first version of this used MultiEffect
            // with only maskSpreadAtMin set, and the result was a perfectly
            // square photograph sitting in a circular hole.
            //
            // What was missing is maskThresholdMin. Without it the mask is
            // cut at a hard step at zero, which for a fully opaque mask
            // texture means everything passes and nothing is masked at all.
            // The pair below -- 0.5 and 1.0 -- is copied verbatim from
            // the wallpaper carousel, which took it from CornerWedge.qml, where
            // the note says the spread is what keeps the antialiasing on the
            // cut edge instead of throwing it away.
            //
            // The mask is a Rectangle with a colour and its own layer, not an
            // Item wrapping one: the layer texture comes from the item the
            // property is set on, so a bare wrapper renders an empty mask.
            Image {
                id: picture

                anchors.fill: parent
                source: `file://${root.avatarPath}`
                cache: false
                fillMode: Image.PreserveAspectCrop
                // Asked for at twice the size it is drawn at, so it stays
                // sharp on a scaled output without a 1024px portrait being
                // held in memory to be shown at 38.
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                smooth: true

                // A missing file is the normal case here, not an error.
                visible: false
                layer.enabled: true
            }

            Rectangle {
                id: pictureMask

                anchors.fill: parent
                radius: height / 2
                antialiasing: true
                color: "black"

                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: picture
                visible: picture.status === Image.Ready
                maskEnabled: true
                maskSource: pictureMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
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
