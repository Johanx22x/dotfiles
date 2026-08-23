// ONE ANSWER IN THE SETTINGS WINDOW'S SEARCH.
//
// THERE IS NO PHOTOGRAPH OF THIS SCREEN and this file says so rather than
// inventing a metric. Windows' settings search answers into a dropdown under
// the search box, not into the content pane, and the one screen that is
// shaped like this -- the shell's search results -- is a WebView2 surface with
// no XAML behind it at all.
//
// So it is drawn as the thing Windows DOES put in the content pane and that
// this already is: a clickable SettingsCard. The "Related settings" cards at
// the foot of every page are exactly this shape -- glyph, a name, a muted line
// under it saying where it goes, and a chevron at the right end -- and they
// are in ref/settings-touchpad-mica.png and ref/settings-flyout-menu.jpg to be
// measured off. A result IS a link to a row on a page, so drawing it as the
// link card the rest of the window uses is the honest answer to a screen
// nobody has a picture of.
//
// The trail says the page and the section, and drops the section when it only
// repeats the page -- which is what a page whose one section is itself looks
// like.

import QtQuick
import qs
import qs.modules.settings
import qs.themes.windows

Item {
    id: root

    required property SettingsResult row

    readonly property string trail: {
        const page = root.row.pageTitle;
        const section = root.row.section;
        if (section === "" || section === page)
            return page;
        if (page === "")
            return section;
        return `${page}  ${Icons.chevronRight}  ${section}`;
    }

    implicitHeight: Fluent.cardMinHeight + 2 * Fluent.cardGapInset

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.topMargin: Fluent.cardGapInset
        anchors.bottomMargin: Fluent.cardGapInset

        radius: Fluent.controlRadius
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, Fluent.cardStrokeAlpha)

        color: {
            if (pointer.pressed)
                return Fluent.fillPress;
            if (pointer.containsMouse)
                return Fluent.fillHover;
            return Fluent.fillRest;
        }

        // The one animation a card gets. SettingsCard's own visual states
        // carry a transition at ControlFastAnimationDuration over the fill;
        // everything else in this theme swaps its brush at time zero.
        Behavior on color {
            ColorAnimation { duration: Fluent.fasterMs }
        }

        Text {
            id: glyph

            anchors.left: parent.left
            anchors.leftMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            width: Fluent.cardIconMax
            horizontalAlignment: Text.AlignHCenter

            visible: root.row.glyph !== ""
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSize
            color: Theme.textOnSurface
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Fluent.cardPadding + (root.row.glyph !== "" ? Fluent.cardIconMax + Fluent.cardIconGap : 0)
            anchors.right: chevron.left
            anchors.rightMargin: Fluent.cardActionGutter
            anchors.verticalCenter: parent.verticalCenter

            spacing: 0

            Text {
                width: parent.width

                text: root.row.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.bodySize
                color: Theme.textOnSurface
            }

            Text {
                width: parent.width

                text: root.trail
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }
        }

        Text {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Fluent.cardPadding
            anchors.verticalCenter: parent.verticalCenter

            text: Icons.chevronRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.glyphSmallSize
            color: Theme.textOnSurfaceVariant
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true

            onClicked: root.row.clicked()
        }
    }
}
