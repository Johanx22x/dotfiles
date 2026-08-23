// A settings row that is on or off: glyph, label, switch. THIS IS THE HALF THE
// PAGES SEE; the pixels are in themes/<theme>/components/ToggleRow.qml.
//
// THE WHOLE ROW IS THE TARGET, not just the switch. A 42x22 pill is a small
// thing to hit for a decision this cheap, and every other row in this shell
// -- MenuRow, the quick toggles on the dashboard -- already answers to a
// click anywhere on it. The switch is feedback, not the button. That is a
// promise this file can no longer keep by itself: it is written down in
// themes/genesis/components/README.md, next to the half that can keep it.
//
// It knows nothing about Config: it takes a value and emits a request to
// change it. That keeps the row reusable and, more to the point, keeps the
// binding one-directional -- `checked` follows the config, and the click asks
// the config to move. A row that wrote to Config itself would be a second
// writer to a value it also displays. The theme inherits that rule whole: it
// reads `row.checked` and calls `row.toggled()`, and writes to neither.
//
// WHY THE ROOT IS AN Item AND NOT A Rectangle, which is the question every
// other facade in this shell has to answer for itself. It was a Rectangle for
// `radius` and a hover fill, and both of those are drawing. The test that
// decided it is the one to reuse: NOTHING OUTSIDE THIS FILE SETS `color`,
// `radius` OR `border` -- checked over all 30 call sites -- so none of the
// three is part of the public API and all three can move behind the seam.
// What the call sites DO set stayed here: `glyph`, `label`, `checked`,
// `onToggled`, and the ordinary Item properties `enabled`, `visible` and
// `width`, which an Item carries too.
//
// `enabled` IS THE ONE THAT LOOKS LIKE IT MOVED AND DID NOT. Qt propagates it
// down the item tree, through the Loader to the theme's root, so six call sites
// keep working with nothing forwarded from here. The DIM that goes with it is
// drawing and lives in the theme -- and so does the MouseArea's own `enabled`,
// which is NOT the same property and does not follow the tree. See rule 6 in
// themes/genesis/components/README.md; it was measured and it is the opposite
// of what it looks like.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property bool checked: false

    signal toggled(bool value)

    // IT TAKES ITS WIDTH FROM ITS PARENT, which therefore has to have one of
    // its own -- SettingsSection gives its column an explicit width for
    // exactly this. Binding implicitWidth to the parent instead would be a
    // loop: a Column sizes itself to its widest child, and the child would be
    // sizing itself to the Column. The theme is filled to this width and never
    // reports one back.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320

    // THE THEME DRIVES THE HEIGHT, WITH A FLOOR UNDER IT. Height is the one
    // measurement that has to come back across the seam: an InfoRow grows to
    // fit its second line and the Column above it has to be told. The floor is
    // what this row was before the split -- Theme.groupHeight -- and it covers
    // the two ways a theme reports nothing. A file that did not load is loud:
    // Quickshell names the missing path, once per row. A root Item whose author
    // never gave it an implicitHeight is not: 0 is a legal answer, nothing
    // warns, and without this floor the row would drop out of its section in
    // silence. That second one is what the Math.max is really for.
    //
    // THROUGH THE LOADER AND NOT THROUGH `Loader.item`, which is the difference
    // between a checked read and an unchecked one. A Loader adopts the implicit
    // size of what it loaded and keeps following it -- measured, not assumed:
    // raising the loaded item's implicitHeight moves the Loader's in the same
    // frame -- and `Loader.implicitHeight` is a real number on a real type,
    // where `Loader.item` is declared QObject and `item.implicitHeight` is a
    // member qmllint cannot find. Same value, and one fewer warning per facade.
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // WHAT THE THEME IS HANDED, AND WHEN. `row` arrives as an initial property
    // rather than as an assignment in onLoaded, which is the difference
    // between the theme's bindings being evaluated once against a null row and
    // never being evaluated against one at all. modules/ThemeSurface.qml hands
    // a surface its screen the same way and for the same reason.
    //
    // THE GUARD IN build() IS NOT DEFENSIVE. setSource is a call and not a
    // binding, so this has to notice the URL changing for itself -- and the
    // first read of `drawingUrl` emits its own change signal, so
    // Component.onCompleted plus onDrawingUrlChanged would build twice and
    // throw the first one away. Comparing against what is loaded makes the
    // pair idempotent, which at 28 of these rows in an open settings window is
    // 28 objects not built and thrown away.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/ToggleRow.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()

        // AND NO onStatusChanged HANDLER, which was written, measured and
        // taken out again. A theme that does not draw this row leaves the
        // Loader at Loader.Error and Quickshell says so itself, once per row:
        //
        //   WARN scene: file://.../themes/genesis/components/ToggleRow.qml
        //               [-1:-1]: No such file or directory
        //
        // That line already names the theme, the component and the path, which
        // is everything a warning here could add. Four lines of logging per
        // facade, twenty-one times over, to reprint what is already printed is
        // not a diagnosis, it is a second copy.
    }
}
