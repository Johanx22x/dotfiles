// One row of a menu: an optional icon, a label, and an optional trailing mark
// for submenus. THIS IS THE HALF THE CALLERS SEE; the pixels are in
// themes/<theme>/components/MenuRow.qml.
//
// Shared by the tray menus and by the shell's own popouts, so a menu written
// by hand and a menu coming off D-Bus are the same object on screen. That is
// what the two `glyph` / `iconSource` properties are for and why both survive
// the split: a row the shell writes names a Nerd Font glyph, and a row that
// came off D-Bus carries an icon name the icon theme has to be asked about.
//
// WHY THE ROOT IS AN Item AND NOT A Rectangle. The usual test: a property of
// the current root type is public API if and only if a call site sets it. Both
// sites are in components/MenuView.qml, at :39 and :71, and between them they
// set `visible`, `label`, `glyph`, `iconSource`, `enabled`, `trailing`,
// `checked` and `onActivated`. Neither sets `color` or `radius`; both are
// drawing and both moved.
//
// AND THIS ONE REPORTS A WIDTH, which rule 2 of
// themes/genesis/components/README.md forbids for rows and for a reason that
// does not reach here. A settings row is a child of a Column that has a width,
// so a row taking its width from that Column and the Column taking its width
// from the row is the loop rule 2 exists to stop. A menu row is the other way
// round: MenuView is a Column with NO width of its own, it is as wide as its
// widest row, and its entries read `implicitWidth` off these rows to say so.
// Nothing below binds to the width it is given, so the circle never closes --
// which is the same thing rule 2 actually asks, read as a question about
// direction rather than as a ban on a property name.
//
// WHO RESOLVES THE ICON, and the answer is the theme. `Icons.resolve` turns a
// D-Bus icon name into a URL out of the current icon theme, and the obvious
// alternative was to do it here and hand the theme a finished URL. Rule 5
// settles it: `Theme` and `Icons` are the two things a theme implementation
// reads directly from `qs`, precisely so the facade does not end up
// re-exporting host services one property at a time. There is a second reason
// that is particular to this component -- whether a row draws an icon AT ALL
// is a theme's decision, and a theme that draws none should not be making the
// host resolve one for it on every model change.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property string label: ""
    property string glyph: ""
    property string iconSource: ""
    property bool trailing: false
    property bool checked: false

    signal activated

    // BOTH FLOORED, and the width's floor is the interesting one. The height's
    // is Theme.groupHeight, which is what this row was before the split. The
    // width's cannot be what it was -- that was the content's own width plus
    // padding, and the content is what moved -- so what is left is the term
    // that is not the theme's: the padding a row has whether or not it has
    // anything in it. A theme that reported nothing gives a menu that is
    // narrow rather than a menu that is nothing, and Quickshell has already
    // named the file that did not load.
    implicitWidth: Math.max(Theme.groupPadding * 2, drawing.implicitWidth)
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/MenuRow.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()

        // See ToggleRow for why there is no status handler here either.
    }
}
