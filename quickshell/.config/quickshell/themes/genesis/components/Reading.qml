// How genesis draws one fact about a monitor: the name on the left, the value
// on the right. The public half -- the two properties, why the facade did not
// move up into components/, and why `label` stayed on it -- is
// modules/settings/pages/display/Reading.qml, and this file is everything that
// was below those comments before the split, moved unchanged.
//
// THERE IS NOTHING TO CLICK AND IT MUST NOT LOOK AS THOUGH THERE IS. No
// MouseArea, no HoverHandler, no TapHandler, no cursorShape, and no colour that
// changes because a pointer is over it. That is the whole contract of this
// component and it is an ABSENCE, which is the one thing the facade had no way
// to require -- it declares no signal to leave unconnected. It is rule 7 in
// README.md; components/InfoRow.qml one directory up keeps the same promise for
// the same reason, and components/ActionRow.qml exists precisely so that a
// reading with something to press is a different type.
//
// THE VALUE ELIDES IN THE MIDDLE AND THAT IS NOT A DEFAULT LEFT AS IT FELL. The
// longest thing this row ever shows is the full EDID description, which is a
// manufacturer, a model and a serial: ElideRight keeps the manufacturer and
// throws the serial away, which is the half that tells two identical panels
// apart. ElideMiddle keeps both ends.

import QtQuick
import qs
// Reading is modules/settings/pages/display/Reading.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings.pages.display

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `Reading` here is the facade and not
    // this file.
    required property Reading row

    // WHAT THE FACADE READS BACK. A reading of this theme is one line tall,
    // always, and 24 rather than Theme.groupHeight because nine of them stack
    // on a single monitor card and a card of nine 36-pixel rows is a card
    // nobody reads to the bottom of. The facade floors at the same number, so
    // this is what the row was before the split rather than a second opinion
    // about it.
    implicitHeight: 24

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        color: Theme.textOnSurfaceVariant

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter
        // Half the row at most, so a long description elides instead of
        // sliding under its own label.
        //
        // MEASURED AGAINST THE FACADE AND NOT AGAINST THIS ITEM, which is the
        // same number today and says the right thing: the Loader anchors-fills
        // the facade, so `root.width` and `root.row.width` agree, and the
        // fraction is of the row the card laid out.
        width: Math.min(implicitWidth, root.row.width * 0.62)
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle

        text: root.row.value
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        font.weight: Theme.fontWeight
        color: root.row.tone

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }
}
