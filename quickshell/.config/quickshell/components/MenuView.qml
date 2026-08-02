// Renders a D-Bus menu (the one a tray icon exposes) with the shell's own
// widgets.
//
// This is why the tray menus can look like the rest of the bar at all: the
// StatusNotifierItem protocol hands over a menu TREE, not a rendered menu,
// so nothing here is drawing someone else's GTK or Qt popup. QsMenuOpener
// turns the handle into a model and every entry is an ordinary Rectangle.
//
// Submenus are entered in place rather than opening a second window: the
// view walks down into the child and shows a "back" row. A cascade of
// floating menus would break the one thing this design is for -- looking
// welded to the bar.

import Quickshell
import QtQuick
import "root:/"

Column {
    id: root

    // A QsMenuHandle, from SystemTrayItem.menu or any other menu source.
    required property var handle

    signal requestClose

    // The handle currently being shown: the root one, or a submenu the user
    // walked into.
    property var currentHandle: handle
    property var parentHandles: []

    spacing: 2

    QsMenuOpener {
        id: opener
        menu: root.currentHandle
    }

    // "Back" row, only while inside a submenu.
    MenuRow {
        visible: root.parentHandles.length > 0
        label: "Back"
        glyph: Icons.close
        onActivated: {
            const stack = root.parentHandles.slice();
            root.currentHandle = stack.pop();
            root.parentHandles = stack;
        }
    }

    Repeater {
        model: opener.children

        Item {
            id: entry

            required property var modelData

            implicitWidth: separator.visible ? Theme.popoutMinWidth : row.implicitWidth
            implicitHeight: separator.visible ? 9 : row.implicitHeight

            Rectangle {
                id: separator

                visible: entry.modelData.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                color: Theme.outlineVariant
            }

            MenuRow {
                id: row

                visible: !entry.modelData.isSeparator
                label: entry.modelData.text ?? ""
                iconSource: entry.modelData.icon ?? ""
                enabled: entry.modelData.enabled
                // A submenu says so rather than pretending to be an action.
                trailing: entry.modelData.hasChildren
                checked: entry.modelData.checkState === Qt.Checked

                onActivated: {
                    if (entry.modelData.hasChildren) {
                        root.parentHandles = root.parentHandles.concat([root.currentHandle]);
                        root.currentHandle = entry.modelData;
                        return;
                    }
                    entry.modelData.triggered();
                    root.requestClose();
                }
            }
        }
    }
}
