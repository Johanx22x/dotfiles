// How the windows theme draws one fact about a monitor: the name on the left,
// the value on the right. The public half -- the two properties, why the facade
// did not move up into components/, and why `label` stayed on it -- is
// modules/settings/pages/display/Reading.qml.
//
// THERE IS NOTHING TO CLICK AND IT MUST NOT LOOK AS THOUGH THERE IS. No
// MouseArea, no HoverHandler, no TapHandler, no cursorShape, and no colour that
// changes because a pointer is over it. That is the whole contract of this
// component and it is an ABSENCE, which is the one thing the facade had no way
// to require -- it declares no signal to leave unconnected. It is rule 7 in
// themes/genesis/components/README.md; components/InfoRow.qml one directory up
// keeps the same promise for the same reason.
//
// AND THIS ONE IS NOT A CARD, which is the only place in this set where the
// SettingsCard shape was deliberately declined. Nine of these stack on a single
// monitor card and the facade's own floor is 24 for exactly that reason: nine
// 68-pixel cards, each with its own stroke, inside a card, is 612 pixels of
// nested boxes and is not a shape Windows has. What Windows has for this is the
// detail list on the Advanced display page -- plain two-column lines inside ONE
// card, no fill of their own and no stroke -- and that is what this is. The
// card around them belongs to whoever draws MonitorTile and SettingsSection.
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
import qs.themes.windows

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `Reading` here is the facade and not
    // this file.
    required property Reading row

    // WHAT THE FACADE READS BACK. The floor is the facade's own 24 -- what this
    // row was outright before the split -- and the two line boxes are what
    // decides above it, because Windows' Body ramp is 14 and a line of it is
    // taller than 24 at some font sizes and shorter at others. Derived from the
    // children and never from `root.height`, which is the loop rule 2 is about.
    implicitHeight: Math.max(24, name.implicitHeight, reading.implicitHeight)

    // Body 14 in TextFillColorSecondary. Both halves of a detail line are Body
    // in Windows; what separates them is the ink, not the size.
    Text {
        id: name

        anchors.left: parent.left
        anchors.leftMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        color: Theme.textOnSurfaceVariant
    }

    Text {
        id: reading

        anchors.right: parent.right
        anchors.rightMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        // WHATEVER IS LEFT AFTER THE LABEL, AND NOT A FRACTION OF THE ROW.
        // Genesis capped this at 0.62 of the width; the number that is actually
        // available is the row less both paddings, less the label, less the
        // gutter Windows puts in front of a card's right-hand content --
        // SettingsCardHeaderIconMargin's sibling, HeaderPanel's own "0,0,24,0".
        //
        // MEASURED AGAINST THE FACADE AND NOT AGAINST THIS ITEM, which is the
        // same number today and says the right thing: the Loader anchors-fills
        // the facade, so `root.width` and `root.row.width` agree, and the space
        // being divided is the row the card laid out.
        width: Math.min(implicitWidth, root.row.width - Fluent.cardPadding * 2 - name.width - Fluent.cardActionGutter)
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle

        text: root.row.value
        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        // The card's own choice between two meanings -- ordinary or singled out
        // -- and the only thing that knows is the card. See the facade's header
        // on why a colour crossing the seam here is not rule 5 being bent.
        color: root.row.tone
    }
}
