// NOT DRAWN YET -- BUT NOT EMPTY EITHER, AND THAT IS THE POINT.
//
// This is one of the two SLOT components: the facade owns a real object and
// publishes it, and the theme's only job is to put it somewhere. Here the
// object is the `TextInput`, because its `text` is a two-way alias read at
// four call sites and a Loader cannot host an alias target.
//
// AN EMPTY IMPLEMENTATION OF THIS FILE IS NOT SAFE. Leave the input unplaced
// and it has no parent, so its own anchors resolve against null and the shell
// says so three times on every start:
//
//     WARN scene: @components/SearchField.qml[133:-1]:
//                 TypeError: Cannot read property 'left' of null
//
// That is the empty-implementation rule's second clause failing: a component
// may only be empty if nothing has to come back across the seam, and this one
// hands an object across. `SettingsSection` is the other.

import QtQuick
import qs.components

Item {
    id: root

    required property SearchField row

    // The one line that has to be here whatever this ends up looking like.
    data: [root.row.input]

    implicitHeight: 0
}
