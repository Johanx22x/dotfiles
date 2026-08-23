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
// WE HAVE NO REAL OVERFLOW, and that is worth saying rather than pretending.
// Windows hides icons past a threshold; this shell shows them all in the
// corner. So the chevron opens the same set the corner is already displaying,
// which makes it a second route rather than a reveal. The alternative was to
// draw a chevron that opens an empty panel, or no chevron at all and a corner
// that is visibly short a control the real one has.

import QtQuick
import Quickshell.Services.SystemTray
import qs
import qs.themes.windows

Item {
    id: root

    readonly property int columns: 3

    implicitWidth: root.columns * Fluent.trayOverflowCell + Fluent.quickPadding * 2
    implicitHeight: grid.height + Fluent.quickPadding * 2

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

                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            cell.modelData?.display(root, cell.x, cell.y);
                        else
                            cell.modelData?.activate();
                        root.dismissRequested();
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
}
