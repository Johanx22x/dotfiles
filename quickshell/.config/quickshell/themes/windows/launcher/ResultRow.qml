// ONE ROW IN THE SEARCH RESULTS, AND ITS SECTION HEADER WHEN IT STARTS ONE.
//
// Read off a photograph rather than off the control documentation, because the
// documentation describes a ListViewItem and this screen is not made of them:
// Windows' search results are a WebView2 surface, so there is no XAML to copy
// and no published metric to look up.
//
// What the photograph shows:
//
//   the top hit is TALLER, with a bigger icon and a second line naming its kind
//   every other row is one line with a 24px icon
//   the section header carries a COUNT and a chevron, not a bare word
//   the selected row is INSET from the column and takes a 3px accent bar on
//     its LEFT edge -- and its fill is the same brush as hover, which is the
//     rule the navigation rail follows too
//
// That last clause is the one worth stating twice: selection here is the bar,
// not a colour of its own. A recreation that gives it a distinct backplate has
// invented a state Windows does not have.

import QtQuick
import qs
import qs.themes.windows

Column {
    id: root

    required property int rowIndex
    required property var entry
    required property bool command
    required property bool current
    required property string header
    required property int headerCount

    signal hovered
    signal chosen

    // The top hit gets the taller treatment, and only the top hit.
    readonly property bool best: root.header === "Best match"

    // Hoisted here rather than read inside the row, so every one of them is
    // checked: inside a delegate these would be as unchecked as `property var`
    // would have made the whole file.
    readonly property string title: root.command
        ? (root.entry?.name ?? "")
        : (root.entry?.name ?? "")
    readonly property string subtitle: root.command
        ? (root.entry?.description ?? "")
        : (root.entry?.genericName ?? "App")
    readonly property string iconSource: root.command
        ? ""
        : Icons.resolve(root.entry?.icon ?? "")
    readonly property string glyph: root.command ? (root.entry?.glyph ?? "") : ""

    spacing: 0

    // ---------------- the section header ----------------
    Item {
        width: parent.width
        height: root.header === "" ? 0 : 34
        visible: root.header !== ""

        Text {
            id: headerText

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6

            // BODY SIZE AND NOT CAPTION, which is what it was. MEASURED off
            // search-flyout-results.jpg rather than reasoned from "a heading
            // is small and dim": the ink height of "Best match" is 16 rows and
            // the ink height of the row title under it is 16-17, so the header
            // is the SAME size as the results it heads and carries its weight
            // in the semibold, not in being a different size. The count beside
            // it measures 13 for a digit against that 16, which is the same
            // face's cap height -- so it is the same size too, and only the
            // colour separates it.
            text: root.header
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.strongWeight
            color: Theme.textOnSurface
        }

        // The count beside it, which Windows shows as a plain number and not a
        // badge -- "Folders 4", "Search the web 11+".
        Text {
            anchors.left: headerText.right
            anchors.leftMargin: 8
            anchors.baseline: headerText.baseline

            visible: root.headerCount > 0
            text: root.headerCount
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            color: Theme.outline
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.baseline: headerText.baseline

            visible: root.headerCount > 0
            text: Icons.chevronRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.outline
        }
    }

    // ---------------- the row ----------------
    Item {
        width: parent.width
        height: root.best ? Fluent.resultBestHeight : Fluent.resultRowHeight

        Rectangle {
            id: plate

            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            anchors.topMargin: 1
            anchors.bottomMargin: 1

            radius: Fluent.controlRadius
            color: root.current || pointer.containsMouse
                ? Theme.surfaceContainerHigh
                : "transparent"

            // No Behavior. Windows swaps the brush on a discrete keyframe at
            // time zero, and a fade here is the tell that gives a Fluent
            // recreation away faster than any wrong colour.

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Fluent.indicatorWidth
                height: Fluent.indicatorHeight
                radius: Fluent.indicatorRadius
                visible: root.current
                color: Theme.primary
            }
        }

        Item {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: root.best ? Fluent.resultBestIcon : Fluent.resultIcon
            height: width

            Image {
                id: rowIcon

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
                font.pointSize: Fluent.bodySize
                color: root.current ? Theme.primary : Theme.textOnSurfaceVariant
            }

            // THE SAME PLATE THE PREVIEW PANE DRAWS, and it was missing here.
            // The Image above shows only when it is Ready, so a desktop file
            // that names no icon -- or names one this icon theme does not have
            // -- left a 24px hole with the label indented past it. Six rows in
            // one photograph of the "All apps" list: Avahi's three browsers,
            // Advanced Network Configuration and two more.
            //
            // Null OR Error, not `!== Ready`. Loading is a state an
            // asynchronous Image passes THROUGH, and gating on it would flash
            // a letter plate under every icon on the way in.
            Rectangle {
                anchors.fill: parent
                visible: !root.command
                    && (rowIcon.status === Image.Null || rowIcon.status === Image.Error)
                radius: Fluent.controlRadius
                color: Theme.surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: (root.title || "?").charAt(0).toUpperCase()
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.captionSize
                    font.weight: Fluent.strongWeight
                    color: Theme.textOnSurfaceVariant
                }
            }
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                width: parent.width
                text: root.title
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.textOnSurface
            }

            // The second line is the kind, and only the top hit and the
            // commands carry one -- an ordinary application row in the
            // photograph is a single line.
            Text {
                width: parent.width
                visible: root.best || root.command
                text: root.subtitle
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            onEntered: root.hovered()
            onClicked: root.chosen()
        }
    }
}
