// ONE ANSWER IN THE SETTINGS WINDOW'S SEARCH.
//
// Read off search-flyout-results.jpg, which is Windows' own list of answers to
// a typed query. It is not XAML -- the results screen is a WebView2 surface,
// so there is no control to look up and no published metric -- and everything
// below was measured off that photograph and lives under THE SEARCH FLYOUT in
// Fluent.qml.
//
// What the photograph shows, and the last clause is the one worth stating
// twice:
//
//   an icon at the left, a title beside it, and a second line for the rows
//     that have more to say than their name
//   the backplate is INSET from the column, not flush with it, and rounded at
//     the control radius
//   the hover fill and the current-row fill are THE SAME BRUSH -- selection is
//     carried by a 3px accent bar at the left edge and by nothing else. A
//     recreation that gives selection a colour of its own has invented a state
//     Windows does not have.
//
// THIS ROW HAS NO SELECTED STATE TO CARRY. modules/settings/SettingsSearch.qml
// builds these in a plain Column and keeps no cursor, so there is no accent
// bar in here: what is left of the pair is the hover fill, and it is drawn at
// exactly the brush the bar would have shared.
//
// WHERE IT DEPARTS FROM THE PHOTOGRAPH, AND IT IS ONE PLACE. Windows puts the
// location on the SAME line as the title for its one-line rows -- "OneDrive -
// in thema" -- and gives a second line only to the top hit, which is also
// eighteen pixels taller and takes a bigger icon. A settings result always has
// a trail, so a second line here is the shape that always applies, at the
// one-line row's height and the one-line row's icon: two lines of type inside
// resultRowHeight, which is what the facade's floor of Theme.groupHeight + 8
// already comes to under this theme.
//
// ---------------------------------------------------------------------------
// THE HOVER AND THE HIT TARGET ARE THIS FILE'S, WHICH IS NOT TRUE NEXT DOOR
// ---------------------------------------------------------------------------
//
// components/SettingsNavItem.qml keeps its own MouseArea on the facade because
// the rail needs the pointer for more than a click. This one does not: the
// facade declares one signal, `clicked`, and nothing else about the pointer,
// so the MouseArea is here -- and it covers the WHOLE row rather than the
// backplate, so that the two pixels of gap between rows still answer.
//
// `row.section` MAY REPEAT THE PAGE'S OWN TITLE, which is what a page whose
// only section is itself looks like, and the facade leaves the choice here.
// Saying "Display > Display" reads as a bug in the search rather than as a
// trail, so the section is dropped when it is the page's name again.

import QtQuick
import qs
import qs.themes.windows
import qs.modules.settings

Item {
    id: root

    required property SettingsResult row

    // The trail, joined. See the header for the repeat.
    readonly property string trail: root.row.section === "" || root.row.section === root.row.pageTitle
        ? root.row.pageTitle
        : `${root.row.pageTitle} > ${root.row.section}`

    implicitHeight: Math.max(Fluent.resultRowHeight, lines.implicitHeight + 2 * Fluent.textLeading)

    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    Rectangle {
        id: plate

        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: 1
        anchors.bottomMargin: 1

        radius: Fluent.controlRadius
        color: pointer.containsMouse ? Fluent.fillSubtleHover : "transparent"

        // No Behavior. Windows swaps the brush on a discrete keyframe at time
        // zero, and a fade here is the tell that gives a Fluent recreation
        // away faster than any wrong colour.
    }

    Text {
        id: icon

        anchors.left: parent.left
        anchors.leftMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.resultIcon
        horizontalAlignment: Text.AlignHCenter

        text: root.row.glyph
        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        color: Theme.textOnSurfaceVariant
    }

    Column {
        id: lines

        anchors.left: icon.right
        anchors.leftMargin: Fluent.cardIconGap
        anchors.right: parent.right
        anchors.rightMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        spacing: 0

        Text {
            width: parent.width

            text: root.row.label
            elide: Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }

        // WHERE IT LIVES, AND IT IS THE HALF THAT MAKES THE ROW AN ANSWER
        // RATHER THAN A NAME. A result that said only "Timeout" would leave
        // the last step to be worked out; "Notifications > Behaviour" is the
        // step.
        Text {
            width: parent.width

            text: root.trail
            elide: Text.ElideRight

            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurfaceVariant
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true

        // NO cursorShape, WHICH IS A DECISION AND NOT AN OMISSION. Windows
        // does not put a hand over a list row -- not in Settings, not in the
        // search flyout, not in Explorer. The arrow stays an arrow and the
        // backplate is what says the row answers. A pointing hand here is a
        // web page's idea of a list and it is one of the cheapest tells there
        // is.

        onClicked: root.row.clicked()
    }
}
