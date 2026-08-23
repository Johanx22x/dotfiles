// NOT DRAWN YET.
//
// The interface asks every theme for this file, so it exists and it loads. It
// draws nothing, and that is the honest state rather than a placeholder
// pretending to be a design: this theme is being built one surface at a time
// against a photograph of the real thing, and this component's turn has not
// come.
//
// When it does: read SettingsChrome from qs.modules.settings, and read
// themes/genesis/components/README.md first. `row` is typed on purpose --
// through `property var` a misspelled read is checked by nothing at all.

import QtQuick
import qs.modules.settings

Item {
    required property SettingsChrome row
}
