// The line across the top of the settings window's content pane: the page's
// name, and the way out. THIS IS THE HALF THE WINDOW SEES; the text and the
// close button are in themes/<theme>/components/SettingsHeader.qml.
//
// THIS IS THE ONLY TITLE BAR THE WINDOW HAS, and that is not a style choice.
// Qt offers to draw its own decorations, Hyprland answers that it will handle
// them server-side, and then draws none -- which is what every other window on
// this desktop gets. So the close button below is the only pointer-reachable
// way out of this window, and a theme that draws no button leaves Escape and
// the compositor's own SUPER + W. That is rule 7 in
// themes/genesis/components/README.md: a promise about behaviour that only an
// implementation can keep, and the theme file says so where it draws it.
//
// THE BOX IS THIS ONE AND THE WINDOW ANCHORS TO IT. `pages` and the search
// results both hang off `header.bottom`, so the height has to be a number this
// side can be asked for before anything has drawn. It is floored at
// Theme.groupHeight -- what this box was before the split -- and read off the
// Loader rather than off `Loader.item`, for the reason in ToggleRow's header.
//
// `heading` AND NOT `title`. modules/settings/SettingsSearch.qml duck-types a
// section as anything carrying a non-empty string `title`, and although its
// walk starts inside the pages and cannot reach this item, the name is the one
// this window has already reserved for a different meaning: `title` on the
// FloatingWindow is the string the compositor puts in its window list. One
// name, one meaning.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    // What the pane below is showing. The window computes it -- "Search" while
    // the field has something in it, the selected page's own title otherwise
    // -- because which of the two panes is up is the window's business and not
    // this component's.
    property string heading: ""

    // Asked for, not done. The theme has no idea what this window is or how it
    // closes; rule 4.
    signal closeRequested

    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/SettingsHeader.qml")

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
