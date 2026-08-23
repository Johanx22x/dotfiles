// THE RIGHT-HAND COLUMN OF THE SEARCH FLYOUT.
//
// A big icon, the name, what kind of thing it is, a divider, and then a list
// of what you can do with it -- Open, Run as administrator, Open file
// location, Pin to Start, Uninstall. That column is half of what makes the
// screen recognisable, and the first attempt at this theme had no preview at
// all: it drew one narrow list and stopped.
//
// AND THE ACTIONS ARE REAL. A desktop entry carries `actions` -- a list of
// DesktopAction, each with a name, an icon and a command -- so the right-hand
// column is the entry's own actions rather than a panel of plausible verbs
// invented to fill the space. "Open" is prepended because every entry has that
// one and none of them declares it.
//
// The pane is a CARD ON THE PANEL rather than more panel: it takes its own
// slightly lighter fill and a 1px stroke, which is the layering rule this
// whole theme runs on -- every surface that comes forward gets lighter, not
// darker. A dark theme built by darkening as things stack reads inverted, and
// that was one of the three things a photograph corrected.

import QtQuick
import qs
import qs.themes.windows

Rectangle {
    id: root

    property var entry: null
    property bool command: false

    signal launched
    signal actionChosen(var action)

    radius: Fluent.controlRadius
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.outlineVariant

    // Hoisted at the top level, where reads through them are checked.
    readonly property string title: root.entry?.name ?? ""
    readonly property string kind: root.command
        ? (root.entry?.description ?? "Command")
        : (root.entry?.genericName || "App")
    readonly property string iconSource: root.command
        ? ""
        : Icons.resolve(root.entry?.icon ?? "")
    readonly property string glyph: root.command ? (root.entry?.glyph ?? "") : ""
    readonly property var actions: root.command ? [] : (root.entry?.actions ?? [])

    Item {
        id: hero

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 40

        height: heroIcon.height + heroName.height + heroKind.height + 20

        Item {
            id: heroIcon

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: Fluent.previewIcon
            height: Fluent.previewIcon

            Image {
                id: heroImage

                anchors.fill: parent
                source: root.iconSource
                visible: !root.command && status === Image.Ready
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Text {
                anchors.centerIn: parent
                visible: root.command
                text: root.glyph
                font.family: Theme.fontFamily
                font.pointSize: Fluent.subtitleSize
                color: Theme.primary
            }

            // The fallback when a desktop file names no icon, which is common
            // enough among terminal applications that the hero cannot be left
            // as an empty square. A rounded plate with the first letter, which
            // is what Windows does for a file type it has no icon for.
            //
            // OFF THE IMAGE'S STATUS AND NOT OFF `iconSource === ""`, which is
            // what it used to test. The two are not the same set: a desktop
            // file that NAMES an icon this icon theme does not have gives a
            // non-empty source that never loads, and that case showed neither
            // the image nor the plate. Error covers it; Null covers the empty
            // name this originally handled.
            Rectangle {
                anchors.fill: parent
                visible: !root.command
                    && (heroImage.status === Image.Null || heroImage.status === Image.Error)
                radius: Fluent.controlRadius
                color: Theme.surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: (root.title || "?").charAt(0).toUpperCase()
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.subtitleSize
                    font.weight: Fluent.strongWeight
                    color: Theme.textOnSurfaceVariant
                }
            }
        }

        Text {
            id: heroName

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: heroIcon.bottom
            anchors.topMargin: 14
            width: parent.width - 32

            text: root.title
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodyLargeSize
            color: Theme.textOnSurface
        }

        Text {
            id: heroKind

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: heroName.bottom
            width: parent.width - 32

            text: root.kind
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurfaceVariant
        }
    }

    Rectangle {
        id: rule

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: hero.bottom
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 24

        height: 1
        color: Theme.outlineVariant
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: rule.bottom
        anchors.topMargin: 8

        spacing: 0

        // The row shape the action list is made of. An inline component rather
        // than a delegate: its instances are ordinary children, so what they
        // read is still checked.
        component ActionRow: Item {
            id: line

            property string label: ""
            property string lineGlyph: ""

            signal triggered

            width: parent?.width ?? 0
            height: Fluent.resultRowHeight

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: Fluent.controlRadius
                color: linePointer.containsMouse ? Theme.surfaceContainerHigh : "transparent"
            }

            Text {
                id: lineIcon

                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                text: line.lineGlyph
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.textOnSurfaceVariant
            }

            Text {
                anchors.left: lineIcon.right
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: line.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.textOnSurface
            }

            MouseArea {
                id: linePointer

                anchors.fill: parent
                hoverEnabled: true
                onClicked: line.triggered()
            }
        }

        ActionRow {
            label: root.command ? "Run" : "Open"
            lineGlyph: Icons.arrowExpand
            onTriggered: root.launched()
        }

        Repeater {
            model: root.actions

            ActionRow {
                required property var modelData

                label: modelData?.name ?? ""
                lineGlyph: Icons.chevronRight
                onTriggered: root.actionChosen(modelData)
            }
        }
    }
}
