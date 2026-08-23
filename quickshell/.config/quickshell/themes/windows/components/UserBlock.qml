// How genesis draws the person at the top of the settings sidebar: a round
// portrait, the display name in bold, and user@host under it. The public half
// -- and the long note on why the picture's URL is handed over as a property
// rather than built here -- is modules/settings/UserBlock.qml.
//
// `cache: false` ON THE Image BELOW IS A HARD REQUIREMENT. The facade reloads
// the portrait by setting `avatarSource` to nothing and back, because an Image
// caches by URL and this URL never changes. Without `cache: false` the second
// assignment is answered out of Qt's pixmap cache, and the portrait silently
// stops updating after the first change -- a window that works perfectly and a
// picture that is somebody's old one. There is no property the facade could
// have made `required` to prevent it. Rule 7.
//
// THE WHOLE BLOCK IS THE TARGET, not the portrait and not the name. It is one
// entry in the rail even though it does not look like the others, and an entry
// you have to aim at is an entry that reads as decoration.
//
// THE PICTURE IS OPTIONAL AND THE FALLBACK IS THE INITIAL OVER THE ACCENT --
// what every application that has ever had this problem settles on, and what a
// fresh machine shows. Both are drawn; which one is visible is decided by the
// Image's own status, so there is no third state where neither is up.

import QtQuick
import QtQuick.Effects
import qs
// UserBlock is modules/settings/UserBlock.qml -- the facade -- and not this
// file, even though a QML document implicitly imports its own directory. The
// explicit import wins; see the note in ToggleRow.qml. SessionInfo is a
// singleton in the same directory: rule 5 says host state is reached with
// `import qs.modules.<name>` and not through `row`.
import qs.modules.settings

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property UserBlock row

    // WHAT THE FACADE READS BACK. A block of this theme is 56 tall -- the
    // facade floors at the same number, so this is what it was before the
    // split rather than a second opinion about it.
    implicitHeight: 56

    radius: Theme.cardRadius

    color: root.row.selected ? Theme.primaryContainer
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

            color: root.row.selected ? Theme.primary : Theme.primaryContainer

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
                color: root.row.selected ? Theme.textOnPrimary : Theme.textOnPrimaryContainer

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
                source: root.row.avatarSource
                // NOT OPTIONAL. See the top of this file: the facade reloads
                // this picture by writing its URL twice, and Qt's pixmap cache
                // answers the second write out of the first unless this is
                // false.
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
                color: root.row.selected ? Theme.textOnPrimaryContainer : Theme.textOnSurface

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
                color: root.row.selected ? Theme.textOnPrimaryContainer : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }
    }

    // The block asks the facade; it does not act. Rule 4: a theme reads `row`
    // and emits through it, and has no idea that the window answers this by
    // clearing the search and selecting page zero.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.row.clicked()
    }
}
