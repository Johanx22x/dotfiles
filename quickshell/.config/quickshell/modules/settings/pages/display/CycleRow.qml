// A value picked by stepping through a list, in the shape of a settings
// row. THIS IS THE HALF THE CARDS SEE; the pixels are in
// themes/<theme>/components/CycleRow.qml.
//
// StepperRow itself does not fit: it holds an int over a numeric
// range, and these are strings out of a list the compositor supplies.
// Its buttons do fit, so those are reused rather than redrawn.
//
// Its own file rather than a promotion into components/: the only thing that
// steps through a list of strings on this desk is a monitor's mode and its
// scale, and a component in components/ is a claim that the next page will
// want it too. THE SPLIT DID NOT CHANGE THAT and the facade stayed here --
// themes/genesis/components/README.md is explicit that the seam does not care
// where a facade lives, and modules/settings/SettingsSection.qml is the other
// one that lives outside components/. What crossed is the drawing, not the
// file's address.
//
// AND IT IS NOT ListRow EITHER, which was checked rather than overlooked and is
// written down in components/ListRow.qml's own header: this takes no clicks by
// design and holds two StepperButtons around a width-pinned value. Its relative
// is StepperRow.
//
// WHY THE ROOT IS AN Item AND NOT A Rectangle. It was a Rectangle for `radius`
// and a hover fill, and both are drawing. The test components/ToggleRow.qml's
// header sets out was run over both call sites -- the Mode row and the Scale
// row in MonitorCard.qml -- and NEITHER SETS `color`, `radius` OR `border`, so
// all three moved behind the seam. What the call sites do set stayed: `glyph`,
// `label`, `value`, `onStepped`, and the ordinary Item property `enabled`.
//
// WHAT A STEP MEANS IS THE CALLER'S, and unlike StepperRow there is no
// clamping rule on this side to keep: the signal carries a DIRECTION and the
// card owns the list. Both call sites wrap rather than clamp, for the reason
// written beside the Mode row. A theme calls `stepped(-1)` and `stepped(1)` and
// reads nothing back.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property string value: ""

    signal stepped(int delta)

    // See the note in ToggleRow: the parent supplies the width, and binding
    // implicitWidth to it instead would be a loop.
    width: parent ? parent.width : implicitWidth
    implicitWidth: 320

    // THE THEME DRIVES THE HEIGHT, WITH A FLOOR UNDER IT. This row was
    // Theme.groupHeight tall before the split and this theme's still is, so the
    // number the Loader reports and the floor under it agree today -- which is
    // the point rather than a redundancy: a theme that stacked the buttons
    // under the label would report a bigger one and the card would grow to fit.
    // See components/ToggleRow.qml for the two ways a theme reports nothing,
    // and for why this reads the Loader's implicit size rather than the loaded
    // item's.
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type. The theme's file
    // is under components/ even though this one is not, for the reason
    // Reading.qml gives beside its own Loader: that directory is the one
    // shell.qml imports for the file watcher.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/CycleRow.qml")

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
