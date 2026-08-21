// How many things this machine has fallen behind on, on the bar, next to the
// gear that opens the page explaining them.
//
// THIS IS THE PART THAT ANSWERS THE COMPLAINT. The installer could already
// tell anybody what was out of date; what it could not do was say so without
// being asked. So the work was remembering to ask -- and remembering a
// sequence of terminal steps every time an update might have arrived is
// exactly the tedium this exists to end. Nobody has to remember now: the
// desktop says so, and the number is the whole message.
//
// IT STAYS ON THE BAR WHEN THERE IS NOTHING TO SAY, muted, showing no number.
// The other way round was considered and it is worse for two reasons. A
// control that only appears when something is wrong is a control nobody has
// ever seen before the day it matters, so the first sighting of it is also the
// first time anybody has to work out what it is; and this is the door to the
// page, which somebody may well want to open on a machine that is perfectly up
// to date -- to tick a pack, or to look at what `etc` is reporting. A widget
// that vanishes when everything is fine cannot be clicked when everything is
// fine.
//
// WIDER WHEN IT HAS A NUMBER, rather than a superscript badge over the glyph.
// A badge is unreadable at the size a bar glyph is drawn, and this shell has
// no badge component; growing the pill sideways is what the notification bell
// does with its unread count and it is the shape that fits a bar.
//
// THE COLOUR IS THE CLI'S. `drift` is red and `missing` is yellow in the table
// `./install.sh check` prints, because something that is there and wrong is
// worth more attention than something that is not there yet. The same two
// answers should not be a different colour depending on which of the three
// frontends you are looking at.

import QtQuick
import "root:/"
import "root:/modules/installer"

Item {
    id: root

    readonly property int discSize: Theme.groupHeight - 6
    readonly property int outstanding: InstallerState.outstanding

    // The one colour this widget has to spend. Neutral -- and answering to the
    // pointer like every other control on the bar -- when there is nothing
    // outstanding; the CLI's own colour when there is, and NOT changed by
    // hover in that case, because hovering a warning should not turn the
    // warning off.
    readonly property color tint: {
        if (root.outstanding === 0)
            return mouse.containsMouse ? Theme.primary : Theme.textOnSurfaceVariant;

        return InstallerState.worst === "drift" ? Theme.critical : Theme.warning;
    }

    implicitWidth: root.outstanding > 0 ? content.implicitWidth + 16 : root.discSize
    implicitHeight: Theme.groupHeight

    // The number arriving and leaving moves the two controls to the right of
    // this one, so it is worth animating: a bar that jumps is a bar somebody
    // clicks the wrong thing on.
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.centerIn: parent

        width: parent.width
        height: root.discSize
        radius: height / 2
        color: mouse.containsMouse ? Qt.alpha(root.tint, 0.18) : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: Icons.update
            font.family: Theme.fontFamily
            font.pointSize: Theme.controlSize
            color: root.tint

            // Dimmed while the check is running, which is this shell's way of
            // saying "busy": there is no spinner anywhere in it, and adding
            // one for a three-second command that runs five times a day would
            // be a component nothing else uses.
            opacity: InstallerState.checking ? 0.45 : 1

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: root.outstanding > 0
            text: root.outstanding
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            font.weight: Font.Bold
            color: root.tint

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Open and not toggle, unlike the gear beside it. The gear's job is
        // the window itself, so clicking it again should put it away; this one
        // is a request to look at one particular page, and a second click on a
        // number you are already reading about should not close it.
        //
        // The page re-checks as it comes up, so clicking this is also the way
        // to ask for a fresh answer.
        onClicked: InstallerState.openPage()
    }
}
