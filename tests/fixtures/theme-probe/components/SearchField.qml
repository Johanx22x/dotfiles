// SearchField, as the probe draws it: a magenta box whose border goes green
// while the field has the focus.
//
// THIS FILE PLACES AN OBJECT IT DOES NOT OWN. `slot` below has
// `data: [root.row.input]`, and appending the facade's TextInput to this
// item's own data list is what moves it here; the input's anchors are bound to
// `parent`, so they re-evaluate against the slot the moment it arrives. The
// font and the ink inside that input are the facade's and no theme can change
// them -- that is what keeping the alias costs, and it is paid here.
//
// A theme that leaves the `data:` line out still loads and still draws. The
// slot is the one thing a facade cannot require: it is an item and not a
// value, so there is no property that could have been made `required`.

import QtQuick
import qs.components

Rectangle {
    id: root

    required property SearchField row

    implicitHeight: 22
    color: "#ff00ff"
    border.width: 2
    border.color: root.row.focused ? "#00ff00" : "#000000"

    Item {
        id: slot

        anchors.fill: parent
        anchors.margins: 4

        data: [root.row.input]
    }
}
