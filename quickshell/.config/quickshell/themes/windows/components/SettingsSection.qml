// NOT DRAWN YET -- AND LIKE SearchField, NOT EMPTY.
//
// The other SLOT component. The facade owns the `Column` the page's rows are
// parented into and publishes it as `readonly property Column rows`; this file
// has to place it or every row on every settings page lands at full width with
// no card and no heading, silently.
//
// Silently is the word: the facade's height floor reads
// `row.rows.implicitHeight` whether or not the Column was ever moved, so the
// seam measures the same 180 pixels either way. Nothing in tests/ can see it.
// It was measured -- with the slot: rows.y 0. Without: rows.y 34, sitting on
// top of the heading with an empty slot beneath.

import QtQuick
import qs.modules.settings

Item {
    id: root

    required property SettingsSection row

    data: [root.row.rows]

    implicitHeight: root.row.rows ? root.row.rows.implicitHeight : 0
}
