// How many things this machine has fallen behind on, in the notification area,
// beside the gear that opens the page explaining them.
//
// THIS IS THE PART THAT ANSWERS THE COMPLAINT. The installer could already tell
// anybody what was out of date; what it could not do was say so without being
// asked. Nobody has to remember now: the desktop says so, and the number is the
// whole message.
//
// IT STAYS ON THE BAR WHEN THERE IS NOTHING TO SAY, muted, showing no number. A
// control that only appears when something is wrong is a control nobody has ever
// seen before the day it matters; and this is the door to the page, which
// somebody may well want to open on a machine that is perfectly up to date.
//
// WIDER WHEN IT HAS A NUMBER, rather than a superscript badge over the glyph. A
// badge is unreadable at the size a taskbar glyph is drawn, and Windows' own
// answer to the same problem is the same one: the notification centre's count
// sits beside its bell, not on top of it.
//
// THE COLOUR IS THE CLI'S. `drift` is red and `missing` is yellow in the table
// `./install.sh check` prints, because something that is there and wrong is
// worth more attention than something that is not there yet. The same two
// answers should not be a different colour depending on which of the three
// frontends you are looking at. Theme.critical and Theme.warning are
// SystemFillColorCritical and SystemFillColorCaution under this theme, so the
// CLI's two colours arrive as Windows' two colours.

import QtQuick
import qs
import qs.modules.installer
import ".."

TaskbarItem {
    id: root

    readonly property int outstanding: InstallerState.outstanding

    // OURS: the inset a taskbar item gives content that is wider than a glyph.
    // Half of Theme.barPadding either side of the reading, doubled below.
    readonly property int padH: Theme.barPadding

    // The one colour this widget has to spend. Neutral -- and answering to the
    // pointer like every other control in this corner -- when there is nothing
    // outstanding; the CLI's own colour when there is, and NOT changed by hover
    // in that case, because hovering a warning should not turn the warning off.
    readonly property color tint: {
        if (root.outstanding === 0)
            return root.hovered ? Theme.primary : Theme.textOnSurfaceVariant;

        return InstallerState.worst === "drift" ? Theme.critical : Theme.warning;
    }

    boxWidth: root.outstanding > 0
        ? content.implicitWidth + root.padH * 2
        : root.boxHeight

    // Open and not toggle, unlike the gear beside it. The gear's job is the
    // window itself, so clicking it again should put it away; this one is a
    // request to look at one particular page, and a second click on a number you
    // are already reading about should not close it. The page re-checks as it
    // comes up, so clicking this is also how to ask for a fresh answer.
    onActivated: InstallerState.openPage()

    // The number arriving and leaving moves everything to the right of this, so
    // it is worth animating: a bar that jumps is a bar somebody clicks the wrong
    // thing on. WinUI's one spline, over its fast duration -- and note that this
    // is a LAYOUT change and not a hover, which is the only reason it is allowed
    // to move at all.
    Behavior on boxWidth {
        NumberAnimation {
            duration: Fluent.fastMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Fluent.easeOut
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.itemSpacing

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: Icons.update
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.tint

            // Dimmed while the check is running, which is this shell's way of
            // saying "busy": there is no spinner anywhere in it, and adding one
            // for a three-second command that runs five times a day would be a
            // component nothing else uses.
            opacity: InstallerState.checking ? Fluent.disabledOpacity : 1
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: root.outstanding > 0
            text: root.outstanding

            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.strongWeight
            font.features: ({ "tnum": 1 })
            color: root.tint
        }
    }
}
