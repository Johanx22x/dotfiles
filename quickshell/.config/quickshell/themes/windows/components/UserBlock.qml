// WHO THIS DESKTOP BELONGS TO, at the top of the navigation pane.
//
// A ROUND PORTRAIT, BIG, WITH TWO LINES BESIDE IT. Measured off
// ref/settings-personalization-taskbar.jpg, which is a 1:1 shot -- the nav
// pills in it are exactly 36 tall: the circle is 60 across, sits at the pane's
// own padding, and the name starts 20 past it with a muted second line under
// it. It is much larger than anything else in the rail and that is the point:
// it is the one entry that is a person rather than a subject.
//
// IT TAKES THE RAIL'S PILL ANYWAY. Windows' block is not a navigation entry
// and does not light up; this shell's is -- it opens the User page, and the
// facade publishes `selected` and a `clicked` signal for it. So it is drawn as
// what it is here, with the same brush and the same accent bar
// SettingsNavItem uses, rather than inventing a fourth selected state for the
// one entry that would have it.
//
// `cache: false` ON THE Image IS A HARD REQUIREMENT and not a tidying. The
// facade reloads the portrait by assigning its URL twice -- empty, then the
// path -- because the path never changes and only the file behind it does.
// With the pixmap cache on, the second assignment is answered out of the first
// and the picture silently stops updating after the first change, in a window
// that otherwise works perfectly.
//
// THE MouseArea IS HERE, unlike SettingsNavItem's: that facade keeps its own
// because it needs preventStealing on it, this one keeps none, so the theme
// owns the hit target.

import QtQuick
import QtQuick.Effects
import qs
import qs.modules.settings
import qs.themes.windows

Item {
    id: root

    required property UserBlock row

    implicitHeight: Fluent.userAvatar + 2 * Fluent.cardGapInset

    Rectangle {
        id: pill

        anchors.fill: parent
        anchors.topMargin: Fluent.cardGapInset
        anchors.bottomMargin: Fluent.cardGapInset

        radius: Fluent.controlRadius

        // The rail's rule: selection and hover are the same brush, and the
        // accent bar is what tells them apart.
        color: root.row.selected || pointer.containsMouse ? Fluent.fillSubtleHover : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.indicatorWidth
            height: Fluent.indicatorHeight
            radius: Fluent.indicatorRadius

            visible: root.row.selected
            color: Theme.primary
        }

        Item {
            id: avatar

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.userAvatar
            height: Fluent.userAvatar

            // The fallback, and it is the normal case on a fresh machine:
            // there is no AccountsService record here and no GECOS field, so
            // there is often neither a picture nor a full name.
            Rectangle {
                anchors.fill: parent

                radius: height / 2
                visible: picture.status !== Image.Ready
                color: Theme.primary

                Text {
                    anchors.centerIn: parent

                    text: SessionInfo.displayName.charAt(0).toUpperCase()
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.subtitleSize
                    font.weight: Fluent.strongWeight
                    color: Theme.textOnPrimary
                }
            }

            // ROUND, AND THAT TAKES AN EFFECT: an Image is a rectangle, and
            // `clip` clips to the bounding box rather than to the curve. The
            // mask is a Rectangle with its own layer -- the layer texture comes
            // from the item the property is set on, so a bare Item wrapping one
            // renders an empty mask -- and maskThresholdMin is what makes the
            // cut happen at all: without it the mask is stepped at zero and a
            // fully opaque texture passes everything through.
            Image {
                id: picture

                anchors.fill: parent

                source: root.row.avatarSource
                cache: false
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                smooth: true

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
            anchors.left: avatar.right
            anchors.leftMargin: Fluent.cardIconGap
            anchors.right: parent.right
            anchors.rightMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            spacing: 0

            Text {
                width: parent.width

                text: SessionInfo.displayName
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                font.weight: Fluent.strongWeight
                color: Theme.textOnSurface
            }

            // Windows puts the account's mail address here. This machine has a
            // user and a host and no account, so it says which of those you are
            // on -- the same sentence the shell's own prompt makes.
            Text {
                width: parent.width

                text: `${SessionInfo.user}@${SessionInfo.host}`
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            cursorShape: Qt.PointingHandCursor
            onClicked: root.row.clicked()
        }
    }
}
