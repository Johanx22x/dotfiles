// System tray (StatusNotifierItem).
//
// Left click activates the item, right click opens its D-Bus menu -- inside
// the bar's own popout, drawn with the shell's widgets.
//
// That is possible because StatusNotifierItem hands over a menu TREE rather
// than a rendered menu: nothing here is embedding someone else's GTK or Qt
// popup, so the menu can look welded to the bar like everything else.

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "root:/"
import "root:/components"

Row {
    id: root

    // The bar's shared popout, handed down by Bar.qml.
    required property var popout

    spacing: 10

    Repeater {
        model: SystemTray.items

        Item {
            id: entry

            required property SystemTrayItem modelData

            implicitWidth: Theme.imageSize
            implicitHeight: Theme.imageSize
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: Icons.resolve(entry.modelData.icon)
                // Tray icons arrive at whatever size the app felt like; asking
                // for the exact target size makes Qt scale on load instead of
                // at paint time.
                sourceSize.width: width
                sourceSize.height: height
                // Passive items are still there but asking for no attention.
                visible: status === Image.Ready
                opacity: entry.modelData.status === Status.Passive ? 0.5 : 1

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animDuration }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    const wantsMenu = mouse.button === Qt.RightButton || entry.modelData.onlyMenu;

                    if (!wantsMenu) {
                        entry.modelData.activate();
                        return;
                    }

                    // Nothing to show: some items expose no menu at all.
                    if (!entry.modelData.hasMenu)
                        return;

                    root.menuHandle = entry.modelData.menu;
                    root.popout.toggleAt(entry.mapToItem(null, entry.width / 2, 0).x, menuComponent);
                }
            }
        }
    }

    // Which item's menu the popout is currently showing. Held here rather
    // than passed into the component because a Component cannot take
    // arguments; the view reads it when it is built.
    property var menuHandle: null

    Component {
        id: menuComponent

        MenuView {
            handle: root.menuHandle
            onRequestClose: root.popout.close()
        }
    }
}
