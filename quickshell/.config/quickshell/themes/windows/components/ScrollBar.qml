// NOT DRAWN YET.
//
// The interface asks every theme for this file, so it exists and it loads. It
// draws nothing, and that is the honest state rather than a placeholder
// pretending to be a design: this theme is being built one surface at a time
// against a photograph of the real thing, and this component's turn has not
// come.
//
// When it does: read ScrollBar from qs.components, and read
// themes/genesis/components/README.md first. `row` is typed on purpose --
// through `property var` a misspelled read is checked by nothing at all.

import QtQuick
import qs.components

Item {
    required property ScrollBar row

    implicitWidth: 0
    implicitHeight: 0
}
