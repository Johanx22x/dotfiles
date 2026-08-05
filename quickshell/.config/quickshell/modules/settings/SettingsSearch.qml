// What the search field shows instead of a page.
//
// IT WALKS THE PAGES RATHER THAN READING AN INDEX. The obvious design is a
// list of {page, row, keywords} written by hand somewhere, and it is wrong
// for the same reason a second copy of anything is wrong: the day someone
// adds a row and forgets the list, the row becomes unfindable and nothing
// says so. The pages are already objects with the labels in them, so they are
// the index.
//
// The walk duck-types. A row is anything with a non-empty string `label`; a
// section is anything with a non-empty string `title` that is not a page.
// That is fragile in the way all duck-typing is, and it is still better than
// the alternative, because the failure is visible -- a row that stops being
// found is a row you notice the next time you look for it.
//
// RESULTS ARE ROWS, NOT PAGES. "Where do I change the notification timeout"
// is answered by the row, and offering "Notifications" instead makes the user
// do the last step themselves.

import QtQuick
import "root:/"
import "root:/components"

Item {
    id: root

    property string query: ""
    property var pages: []

    signal picked(int page, string row)

    // Rebuilt on every keystroke. Measured against the alternative of caching
    // it: there are a few dozen rows, the walk is microseconds, and a cache
    // would have to be invalidated by page contents that change at runtime --
    // which several of them do.
    readonly property var results: {
        const query = root.query.trim();
        if (!query)
            return [];

        const found = [];

        for (let i = 0; i < root.pages.length; i++) {
            const page = root.pages[i];
            if (!page || page.title === undefined)
                continue;

            collect(page, i, page.title, "", found);
        }

        found.sort((a, b) => b.score - a.score);
        // Twelve is about what fits without scrolling at this window's
        // height. Past that the list stops being an answer and becomes
        // another thing to read.
        return found.slice(0, 12);
    }

    function collect(item: var, pageIndex: int, pageTitle: string, section: string, out: var): void {
        for (const child of item.children) {
            if (!child)
                continue;

            let childSection = section;

            // A section, by its own title. Pages have one too, which is why
            // the walk starts inside a page rather than at it.
            if (typeof child.title === "string" && child.title !== "" && child.label === undefined)
                childSection = child.title;

            if (typeof child.label === "string" && child.label !== "") {
                const score = Fuzzy.scoreAny([child.label, childSection, pageTitle].concat(root.pages[pageIndex].keywords ?? []), root.query);
                if (score >= 0) {
                    out.push({
                        label: child.label,
                        section: childSection,
                        page: pageIndex,
                        pageTitle: pageTitle,
                        glyph: child.glyph ?? "",
                        score: score
                    });
                }
            }

            collect(child, pageIndex, pageTitle, childSection, out);
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.results.length === 0
        text: `Nothing matches “${root.query}”`
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    Flickable {
        anchors.fill: parent

        contentWidth: width
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list

            width: parent.width
            spacing: 2

            Repeater {
                model: root.results

                Rectangle {
                    id: result

                    required property var modelData

                    width: list.width
                    implicitHeight: Theme.groupHeight + 8
                    radius: Theme.cardRadius

                    color: resultMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Text {
                        id: resultGlyph

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.groupPadding
                        anchors.verticalCenter: parent.verticalCenter

                        text: result.modelData.glyph
                        visible: text !== ""
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.iconSize
                        color: Theme.textOnSurfaceVariant
                    }

                    Column {
                        anchors.left: resultGlyph.visible ? resultGlyph.right : parent.left
                        anchors.leftMargin: resultGlyph.visible ? Theme.itemSpacing : Theme.groupPadding
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.groupPadding
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: result.modelData.label
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            font.weight: Theme.fontWeight
                            color: Theme.textOnSurface
                        }

                        // The trail, so a row with a generic name is placed:
                        // "Default timeout" alone could be three things.
                        Text {
                            width: parent.width
                            text: result.modelData.section !== "" && result.modelData.section !== result.modelData.pageTitle
                                ? `${result.modelData.pageTitle} › ${result.modelData.section}`
                                : result.modelData.pageTitle
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 3
                            color: Theme.textOnSurfaceVariant
                        }
                    }

                    MouseArea {
                        id: resultMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(result.modelData.page, result.modelData.label)
                    }
                }
            }
        }
    }
}
