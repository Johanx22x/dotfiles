// ChoiceRow, as the probe draws it: the label, the value as it stringifies,
// and a click that moves to the next option. No menu, no popout, no animation.

import QtQuick
import qs
import qs.components

Rectangle {
    id: root

    required property ChoiceRow row

    implicitHeight: 24
    color: "#ff00ff"
    border.width: 2
    border.color: "#000000"
    opacity: root.enabled ? 1 : 0.4

    Text {
        anchors.fill: parent
        anchors.margins: 4
        verticalAlignment: Text.AlignVCenter

        text: `${root.row.label} = ${root.row.value}`
        color: "#ffff00"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled

        // Rule 4: ask, never write. `chosen` is the request; whatever the row
        // is wired to is what decides.
        onClicked: {
            const options = root.row.options;
            if (!options || options.length === 0)
                return;

            let index = 0;
            for (let i = 0; i < options.length; i++)
                if (root.row.valueOf(options[i]) === root.row.value)
                    index = i;

            root.row.chosen(root.row.valueOf(options[(index + 1) % options.length]));
        }
    }
}
