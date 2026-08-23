// One answer in the settings window's search. THIS IS THE HALF THE WINDOW
// SEES; the card, the glyph and the two lines of text are in
// themes/<theme>/components/SettingsResult.qml.
//
// RESULTS ARE ROWS, NOT PAGES, which is the shape this component is. "Where do
// I change the notification timeout" is answered by the row, and offering
// "Notifications" instead makes the user do the last step themselves -- so a
// result carries the row's own name and the trail that places it, and the
// theme draws both.
//
// `label` AND `glyph` LIVE ON THIS SIDE, and here that is a convention rather
// than a load-bearing rule. modules/settings/SettingsSearch.qml duck-types on
// those names, but its walk starts inside the pages and this component is not
// in one -- the results pane is a sibling of the page host, so nothing walks
// into it and a mirrored name here would double nothing. It is spelled the way
// every other facade in the interface spells it anyway, because the day
// somebody points a walk at this pane is not the day to discover that this one
// was the exception. Rule 3 in themes/genesis/components/README.md.
//
// The height is floored at what a result was before the split -- one row plus
// eight -- and read off the Loader rather than off `Loader.item`, for the
// reason in ToggleRow's header.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property string glyph: ""
    property string label: ""

    // Where the row lives: the page's own name, and the section inside it when
    // there is one worth saying. The theme decides how to join them -- and
    // whether to say the section at all when it repeats the page's title,
    // which is what a page whose only section is itself looks like.
    property string section: ""
    property string pageTitle: ""

    signal clicked

    // The list gives the width; see the note at the top of ToggleRow.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 200
    implicitHeight: Math.max(Theme.groupHeight + 8, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/SettingsResult.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()
    }
}
