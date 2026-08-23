// The notification area: other applications' icons (StatusNotifierItem).
//
// ONE HOVER TARGET FOR THE WHOLE STRIP, not one per icon. That is the
// difference between this and genesis's row of loose glyphs, and it is what
// Windows does: the notification area washes as a unit, so hovering it tells
// you where the region ENDS -- which matters, because the icons inside it
// belong to programs that had no say in how far apart they sit. Each icon still
// takes its own click.
//
// HOW THE TWO COEXIST. The wash comes from a HoverHandler on the strip and the
// clicks from a MouseArea per icon. It has to be that way round: a MouseArea
// with hoverEnabled stops hover propagating to the item under it, so a second
// MouseArea across the strip would go dark the moment the pointer reached an
// icon. Pointer handlers are delivered independently of that, so an ancestor's
// HoverHandler keeps firing while a descendant's MouseArea has the hover. The
// TaskbarItem below is therefore `interactive: false`: it is a backplate, and
// its own MouseArea would be a third thing competing for the same press.
//
// 16px, which is `Fluent.navIcon` and is the size WinUI gives every icon in a
// list or a pane. Tray icons arrive at whatever size the application felt like.
//
// Left click activates the item, right click opens its D-Bus menu -- inside the
// bar's own popout, drawn with the shell's widgets. That is possible because
// StatusNotifierItem hands over a menu TREE rather than a rendered menu, so
// nothing here is embedding someone else's GTK or Qt popup.

import Quickshell.Services.SystemTray
import QtQuick
import qs
import qs.components
import qs.themes.windows

TaskbarItem {
    id: root

    // The bar's shared popout, handed down by Bar.qml.
    required property Popout popout

    // Which item's menu the popout is currently showing. Held here rather than
    // passed into the component because a Component cannot take arguments; the
    // view reads it when it is built.
    property var menuHandle: null

    interactive: false
    washed: strip.hovered

    // OURS. Windows' notification area sits its icons on about a 24px pitch and
    // insets them from the region's edge by about the same gap; Theme.barPadding
    // is that 8, so the strip reads it rather than writing a second copy of it.
    boxWidth: icons.implicitWidth + Theme.barPadding * 2

    // AN EMPTY NOTIFICATION AREA IS NOT AN EMPTY HOVER TARGET SITTING IN THE
    // CORNER. It is nothing.
    //
    // A PLAIN PROPERTY AND NOT `visible`, and the reason is the one
    // PeripheralBattery.qml spells out beside its own `hasAny`: Bar.qml has to
    // hide this for its own reason as well -- the `tray` switch -- and an
    // assignment at the instantiation site REPLACES a binding written in here
    // rather than adding to it. Two conditions, one binding, and it has to be
    // written where both of them are visible.
    readonly property bool hasItems: SystemTray.items.values.length > 0

    HoverHandler {
        id: strip
    }

    Row {
        id: icons

        anchors.centerIn: parent
        spacing: Theme.barPadding

        Repeater {
            model: SystemTray.items

            Item {
                id: entry

                required property SystemTrayItem modelData

                implicitWidth: Fluent.navIcon
                implicitHeight: Fluent.navIcon

                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent

                    source: Icons.resolve(entry.modelData.icon)
                    // Asking for the exact target size makes Qt scale on load
                    // instead of at paint time.
                    sourceSize.width: width
                    sourceSize.height: height

                    visible: status === Image.Ready

                    // Passive items are still there but asking for no
                    // attention. Fluent.disabledOpacity is the dim WinUI gives
                    // anything that is present and not participating.
                    opacity: entry.modelData.status === Status.Passive
                        ? Fluent.disabledOpacity
                        : 1
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: event => {
                        const wantsMenu = event.button === Qt.RightButton
                            || entry.modelData.onlyMenu;

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
    }

    Component {
        id: menuComponent

        MenuView {
            handle: root.menuHandle
            onRequestClose: root.popout.close()
        }
    }
}
