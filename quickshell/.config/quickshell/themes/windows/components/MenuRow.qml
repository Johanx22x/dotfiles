// How the windows theme draws one row of a menu: a MenuFlyoutItem. The public
// half -- the two kinds of icon, and why the width crosses the seam upwards
// here -- is components/MenuRow.qml.
//
// THE WHOLE ROW IS THE TARGET, which is the same promise ToggleRow's header
// makes and the same one a facade cannot require. A menu row that only answered
// to a click on its label would be a menu you have to aim at, and this is the
// component every tray menu in the shell is built out of.
//
// ---------------------------------------------------------------------------
// THE HIGHLIGHT IS INSET AND THE ROW IS NOT
// ---------------------------------------------------------------------------
//
// `MenuFlyoutItemMargin` is 4,2,4,2, and it is the one piece of Windows' menu
// geometry that is published rather than measured. It means the backplate that
// lights up under the pointer stops FOUR PIXELS SHORT of each side of the menu:
// the flyout's own padding is not where the inset comes from, the item's margin
// is. So this row is as wide as the menu and the rectangle inside it is not,
// which is why the fill below is on a child and not on this item.
//
// It is also what makes a Windows menu read the way it does: the highlights sit
// in a column with air either side, and THE SEPARATORS RUN WIDER THAN THEY DO --
// `MenuFlyoutSeparator` carries a negative -4 padding that cancels the item
// margin exactly, so a divider spans the full menu while every highlight is
// inset from it.
//
// THAT SECOND HALF IS NOT OURS. components/MenuView.qml draws the separator and
// has no theme half at all -- it is a Repeater delegate end to end, so a theme
// half would get no checking from the seam and would take the D-Bus mapping
// with it. Its separator is one pixel of `Theme.outlineVariant` across the full
// width in nine pixels of room, and the 2px vertical half of the item margin is
// its `spacing: 2`. Both are close enough to Windows that nothing here has to
// pretend otherwise; neither is this file's to move.
//
// THE ROOT IS A Rectangle AND THE FACADE'S IS AN Item: `radius` and the hover
// fill are the two reasons this was ever a Rectangle, and both are drawing.
//
// AND THE ICON IS RESOLVED HERE. `Icons.resolve` is a host service reached the
// way rule 5 says host services are reached -- straight off `import qs` --
// rather than handed down as a finished URL. It is read ONCE, into a typed
// property at the top of this file, rather than inline where it is drawn: the
// same hoist LevelMeter.qml makes for its delegate, and here it also means the
// icon theme is asked once per model change instead of once per binding
// evaluation.

import QtQuick
import qs
// MenuRow is components/MenuRow.qml -- the facade -- and not this file. The
// explicit import wins over the directory a document implicitly imports.
import qs.components
// Fluent lives one directory up. Without this line every `Fluent.` below is a
// ReferenceError at runtime, once per read; tests/qml-rules.sh checks the pair.
import ".."

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. Typed and
    // `required` for the reason rule 1 of README.md sets out.
    required property MenuRow row

    // MenuFlyoutItemMargin = 4,2,4,2. Only the horizontal half is this file's:
    // the vertical half is MenuView's `spacing: 2`, which is a host file.
    readonly property int highlightInset: 4

    // The icon URL, resolved once. `row.iconSource` is a NAME off D-Bus and not
    // a path, and the icon theme is what turns one into the other.
    readonly property string iconUrl: Icons.resolve(root.row.iconSource)

    // What the submenu mark asks the row to be wider by, and nothing when there
    // is no submenu: a menu of plain entries does not reserve a chevron column
    // it will never draw in. Read off the Text's own implicit width rather than
    // guessed, so the number follows the glyph and the size it is drawn at.
    readonly property real trailingWidth: root.row.trailing
        ? trailing.implicitWidth + Theme.itemSpacing
        : 0

    // WHAT THE FACADE READS BACK, AND HERE IT IS A PAIR. The height is
    // MenuFlyoutItem's own 32. The width is the content plus the item's padding
    // plus the margin outside it -- `MenuFlyoutItemThemePadding` is 11 a side
    // and the margin is another 4, and both have to be in the number because a
    // menu is exactly as wide as its widest row asks to be. MenuView's Column
    // has no width of its own; this is where it comes from.
    //
    // Neither is derived from the size this item was given, which is what keeps
    // the pair out of a loop.
    //
    // AND 32 IS NOT WHAT ARRIVES. The facade floors the height at
    // `Theme.groupHeight`, which is `barHeight - 12` and is 36 under this
    // theme's 48-pixel taskbar -- measured, by building one of these in a bare
    // engine: it reports 36 with 32 written here. `groupHeight` is DERIVED and
    // not a token, so the only way a theme could reach 32 is by shortening the
    // taskbar, which is not a trade a menu row gets to make. The 32 stays
    // because it is what this drawing asks for; the 36 is the interface's
    // answer, and the four pixels go into the highlight, which fills whatever
    // height it is given.
    implicitWidth: contents.implicitWidth + root.trailingWidth
        + (Fluent.controlPaddingH + root.highlightInset) * 2
    implicitHeight: Fluent.controlHeight

    // The row itself paints nothing. See the header: what lights up is the
    // inset child below.
    color: "transparent"

    // Rule 6: this is Qt's effective-enabled, computed down the tree from the
    // facade through its Loader to here. The MouseArea below forwards it by
    // hand because MouseArea.enabled is a flag of its own and does not follow
    // the tree.
    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // ---------------- The highlight ----------------
    //
    // `SubtleFillColorSecondary` on hover and `SubtleFillColorTertiary` on
    // press: brighter under the pointer, DARKER while held, which is Windows'
    // state model and the opposite of most toolkits'. No Behavior on it --
    // Windows swaps the brush on a DiscreteObjectKeyFrame at time zero, and
    // Fluent.hoverMs is 0 to say so.
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: root.highlightInset
        anchors.rightMargin: root.highlightInset

        radius: Fluent.controlRadius
        antialiasing: true

        color: mouse.pressed && root.enabled ? Fluent.fillPress
            : mouse.containsMouse && root.enabled ? Fluent.fillSubtleHover
            : "transparent"
    }

    Row {
        id: contents

        anchors.left: parent.left
        anchors.leftMargin: root.highlightInset + Fluent.controlPaddingH
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        // A TICK IN THE ICON COLUMN AND NOT A PREFIX ON THE LABEL. genesis
        // writes "✓  " in front of the text, which moves every checkable row's
        // words sideways as it is ticked; Windows puts the check where an icon
        // would have gone and leaves the label where it was.
        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: root.row.checked
            text: Icons.check
            font.family: Theme.fontFamily
            font.pixelSize: Fluent.navIcon
            color: Theme.textOnSurface
        }

        // A Nerd Font glyph, for rows the shell writes itself. 16 epx, which is
        // a BOX and not type: Fluent.qml's rule is that sizes are absolute and
        // text is relative.
        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: root.row.glyph !== "" && !root.row.checked
            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pixelSize: Fluent.navIcon
            color: Theme.textOnSurface
        }

        // A themed icon, for rows that come from D-Bus. Sixteen, which is what
        // a MenuFlyoutItem's icon is -- Theme.imageSize is 20 and is the size of
        // a picture rather than of a glyph.
        Image {
            id: icon

            anchors.verticalCenter: parent.verticalCenter

            source: root.iconUrl
            // Ready and not just "non-empty": an icon the theme does not have
            // would otherwise leave the broken-image chequerboard behind.
            visible: icon.status === Image.Ready
            width: Fluent.navIcon
            height: Fluent.navIcon
            sourceSize.width: icon.width
            sourceSize.height: icon.height
        }

        // Body at REGULAR weight. A menu entry is not emphasis; Windows keeps
        // Semibold for headings and for the selected item in a list, and a menu
        // full of Semibold reads as a menu full of shouting.
        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: root.row.label
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }
    }

    // The submenu mark. Inside the highlight, so it is inset by the same 4 plus
    // the item's own padding.
    Text {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: root.highlightInset + Fluent.controlPaddingH
        anchors.verticalCenter: parent.verticalCenter

        visible: root.row.trailing
        text: Icons.chevronRight
        font.family: Theme.fontFamily
        font.pixelSize: Fluent.navIcon
        color: Theme.textOnSurfaceVariant
    }

    // THE WHOLE ROW, and that is the promise the facade's header makes and this
    // file keeps.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: root.row.activated()
    }
}
