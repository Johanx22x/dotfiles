// THE HIDDEN-ICONS FLYOUT, which the chevron at the left of the taskbar
// corner opens.
//
// Windows keeps the tray icons it is not showing behind that chevron and
// spills them into a small grid when you click it -- a plain panel, three
// across, each icon its own square target with the same 4px backplate
// everything else on the bar uses. No labels, no headings, no close button.
//
// OURS in every measurement: this is shell chrome and Microsoft publishes
// nothing about it. The grid is three wide because that is what the photograph
// shows and because it keeps the flyout roughly as wide as the corner it
// hangs under.
//
// EVERY SNI ICON LIVES HERE AND ONLY HERE. Out of the box Windows hides all
// application icons behind the chevron -- promotion onto the corner is a
// per-icon user setting this shell does not have -- so hiding the whole set
// is the default being copied, not a shortfall. An earlier version of this
// file said the opposite: the corner drew every icon and the chevron opened
// the same set again, a second route dressed up as a reveal, which put
// Discord, Steam and the rest on screen twice. The fix was to stop the
// corner promoting, not to stop the chevron.
//
// TWO CLICKS PER ICON, the same pair genesis's tray answers. Left activates
// the item and closes the flyout; right asks the bar to swap the popout over
// to the icon's own D-Bus menu -- an item that is onlyMenu treats left as
// right, and one with no menu at all answers right with nothing. The menu
// Component lives in Bar.qml, because the popout it swaps is the bar's, and
// the signal carries the ITEM rather than its menu handle: `.menu` is a
// DBusMenuHandle, a type qmllint cannot see, and reading it off the typed
// delegate here is a warning that reading it off a var parameter in Bar.qml
// is not.

import QtQuick
import Quickshell.Services.SystemTray
import qs
import qs.themes.windows

Item {
    id: root

    readonly property int columns: 3

    implicitWidth: root.columns * Fluent.trayOverflowCell + Fluent.quickPadding * 2
    implicitHeight: grid.height + Fluent.quickPadding * 2

    // THE PANEL, WHICH THIS FILE DID NOT DRAW AND HAD TO. `components/Popout.qml`
    // is the window and nothing else -- it stopped painting a ground of its own
    // so that each of the three things it opens can have the shape the
    // photograph gives it, Quick Settings and the notification centre being two
    // different shapes over the same window. Those two grew their own grounds
    // at the time. This one did not, and what reached the screen was "No hidden
    // icons" printed on the wallpaper with no flyout around it at all.
    //
    // The same material as its siblings: acrylic over surface, the overlay
    // radius, one pixel of outlineVariant. A flyout that agrees with the other
    // two is the whole point of them being constants.
    Rectangle {
        anchors.fill: parent

        radius: Fluent.overlayRadius
        antialiasing: true
        color: Fluent.acrylic(Theme.surface)
        border.width: 1
        border.color: Theme.outlineVariant
    }

    Grid {
        id: grid

        x: Fluent.quickPadding
        y: Fluent.quickPadding
        width: parent.width - Fluent.quickPadding * 2

        columns: root.columns

        Repeater {
            model: SystemTray.items

            Item {
                id: cell

                required property SystemTrayItem modelData

                width: Fluent.trayOverflowCell
                height: Fluent.trayOverflowCell

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Fluent.controlRadius
                    color: {
                        if (cellPointer.pressed)
                            return Theme.surface;
                        if (cellPointer.containsMouse)
                            return Theme.surfaceContainerHigh;
                        return "transparent";
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: Fluent.trayIcon
                    height: Fluent.trayIcon
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    source: Icons.resolve(cell.modelData?.icon ?? "")
                }

                MouseArea {
                    id: cellPointer

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    // Right-click used to call modelData.display(), which
                    // wants a QsWindow and was being handed this Item: it did
                    // nothing, silently, and then dismissRequested() closed
                    // the flyout -- which from a chair is exactly what a
                    // broken right-click looks like. The menu now goes the
                    // way genesis's tray menus go: through the bar's popout
                    // and the host's MenuView, off the menu HANDLE the item
                    // publishes rather than a window it wants to own.
                    onClicked: mouse => {
                        const item = cell.modelData;
                        if (!item)
                            return;

                        const wantsMenu = mouse.button === Qt.RightButton || item.onlyMenu;
                        if (!wantsMenu) {
                            item.activate();
                            root.dismissRequested();
                            return;
                        }

                        // Some items expose no menu at all. Genesis answers
                        // that with nothing, and so does this -- the flyout
                        // stays up, since nothing happened.
                        if (!item.hasMenu)
                            return;

                        // WINDOW coordinates, deliberately. Genesis maps its
                        // icon to null and uses the result as a screen x
                        // because its tray sits on the bar, which spans the
                        // screen from x = 0. This grid sits inside the
                        // popout's own window, which starts wherever the
                        // popout was clamped to -- so the bar adds the
                        // popout's left margin back before handing the number
                        // to openAt(). See the handler in Bar.qml.
                        root.menuRequested(item, cell.mapToItem(null, cell.width / 2, 0).x);
                    }
                }
            }
        }
    }

    // Nothing in the tray at all. Windows simply does not offer the chevron in
    // that case, and neither does the corner -- but a panel that opens empty
    // is worse than one that says why.
    Text {
        anchors.centerIn: parent
        visible: SystemTray.items.values.length === 0
        text: "No hidden icons"
        font.family: Theme.fontFamily
        font.pointSize: Fluent.captionSize
        color: Theme.textOnSurfaceVariant
    }

    signal dismissRequested

    // A request to show one icon's context menu: the item is the
    // SystemTrayItem itself (the bar takes `.menu` off it -- see the header),
    // the x is the clicked cell's centre in THIS WINDOW's coordinates -- see
    // the note in the click handler.
    signal menuRequested(var item, real windowX)
}
