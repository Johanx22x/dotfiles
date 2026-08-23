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
//
// ---------------------------------------------------------------------------
// THIS ONE HAS NO THEME HALF, AND THAT WAS A DECISION
// ---------------------------------------------------------------------------
//
// Every other shared widget in this directory was split when themes arrived --
// components/MenuRow.qml, the file this one is built out of, is split. This
// one was looked at and left whole. Three things decided it, in order of
// weight.
//
// THERE IS ALMOST NOTHING HERE TO DRAW. Count it: `spacing: 2`, a separator
// one pixel tall in Theme.outlineVariant, and the nine pixels of room the
// separator sits in. That is the entire visual contribution of this file --
// everything else on screen is a MenuRow, which a theme already draws. A
// facade and an implementation is sixteen copied lines and a second file for a
// horizontal rule.
//
// AND THE SPLIT WOULD HAVE TO HAND THE MODEL ACROSS. The other 85% of this
// file is the QsMenuOpener, the submenu stack, the discrimination between a
// separator and a row, and the mapping from D-Bus fields -- `text`, `icon`,
// `enabled`, `hasChildren`, `checkState` -- onto MenuRow's properties. A theme
// that owned the layout would own the Repeater, and a theme that owns the
// Repeater does that mapping itself. That is exactly the behaviour a split is
// supposed to keep on this side: get `checkState === Qt.Checked` wrong and a
// tray menu shows the wrong item ticked, in somebody else's application, where
// nothing in this repository would ever see it.
//
// A DELEGATE IS WHERE THE TYPE CHECKING RUNS OUT. Rule 1 of
// themes/genesis/components/README.md is that a typed `required property
// <Facade> row` turns every read in a theme file into a checked one. Measured
// since, in themes/genesis/components/LevelMeter.qml: that holds at the top
// level of a theme file and NOT inside a Repeater delegate, where a misspelt
// `row.something` produces no warning of any category. This file is a Repeater
// delegate almost end to end. A theme half for it would be the one place in
// the tree where the seam gives up its checking and takes the D-Bus mapping
// with it.
//
// So a theme that wants a different menu does not restyle this one -- it
// builds its own out of MenuRow, which is the piece worth sharing. That is
// already the shape of it: the only call site is themes/genesis/bar/Tray.qml,
// a theme file, which reaches for this the way it reaches for ScrollList.
//
// WHAT IT COSTS, said plainly: a theme cannot change the separator's colour,
// its height, or the spacing between entries without editing this host file.
// If a second theme ever wants to, the thing to split is the separator, and
// the answer is probably a MenuSeparator component beside MenuRow rather than
// a facade around all of this.

import Quickshell
import QtQuick
import qs

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
