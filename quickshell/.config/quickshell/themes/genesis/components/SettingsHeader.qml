// How genesis draws the settings window's header line: the page's name in bold
// on the left, and a round close button in the corner. The public half --
// `heading`, `closeRequested`, and the note on why the box's height is the
// facade's -- is modules/settings/SettingsHeader.qml.
//
// THE CLOSE BUTTON IS THE ONLY POINTER-REACHABLE WAY OUT OF THIS WINDOW, and
// that is the promise this file inherited. There is no title bar: Hyprland
// draws none and Qt does not either. A theme that leaves the button out leaves
// Escape and SUPER + W, which is a keyboard-only window and not what this one
// promises. Rule 7 in this directory's README.
//
// IT IS A BARE GLYPH ON THE GLASS AND NOT A PILL. It is the only control in
// this window that is not a setting, and everything that IS a setting in here
// is a pill -- so the one thing that closes the window is drawn as the one
// thing that is not one of them.
//
// THE NAME ELIDES AGAINST THE BUTTON and not against the pane's right edge, so
// a long page title stops before the button rather than under it.

import QtQuick
import qs
// SettingsHeader is modules/settings/SettingsHeader.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property SettingsHeader row

    // WHAT THE FACADE READS BACK. A header of this theme is one row tall,
    // always -- the facade floors at the same number, so this is what it was
    // before the split rather than a second opinion about it.
    implicitHeight: Theme.groupHeight

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.right: closeButton.left
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.heading
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize + 3
        font.weight: Font.Bold
        color: Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    // Close. In the corner, round, and the only control in this window that is
    // not a setting -- which is why it is a bare glyph on the glass rather
    // than a pill like everything else.
    Rectangle {
        id: closeButton

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: Theme.groupHeight
        implicitHeight: Theme.groupHeight
        radius: height / 2

        color: closeMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        Text {
            anchors.centerIn: parent
            text: Icons.close
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: closeMouse.containsMouse ? Theme.textOnSurface : Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        // The button asks the facade; it does not act. Rule 4: a theme reads
        // `row` and emits through it, and has no idea that there is a window
        // behind this, let alone how it is closed.
        MouseArea {
            id: closeMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.row.closeRequested()
        }
    }
}
