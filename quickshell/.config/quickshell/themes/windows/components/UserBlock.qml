// How the windows theme draws the person at the top of the settings sidebar: a
// round portrait, the display name in Body Strong, and user@host under it. The
// public half -- and the long note on why the picture's URL is handed over as
// a property rather than built here -- is modules/settings/UserBlock.qml.
//
// ---------------------------------------------------------------------------
// MICROSOFT SPECIFIES NONE OF THIS, SO EVERY METRIC BELOW IS MARKED `OURS`
// ---------------------------------------------------------------------------
//
// This block is NOT part of NavigationView. Windows' Settings app puts the
// account in its pane header -- the slot NavigationView leaves for an
// application to fill -- and the pane header's contents are the app's business
// in the same way this shell's are. There is no published avatar size, no
// published gap and no published two-line rule.
//
// What third-party recreations converge on, and what this draws: a CIRCULAR
// portrait, a 16px gap, and two stacked lines -- the name in Body Strong (14,
// Semibold) and the second line in Caption (12) in the secondary text colour.
// Only those two type styles are Microsoft's; the geometry around them is
// ours.
//
// THE SELECTION IS THE RAIL'S AND NOT THIS BLOCK'S OWN. It is one entry of the
// navigation pane even though it does not look like the others, so it says
// "this one" the way the others do: the same 3x16 accent indicator at radius
// 2, flush left and vertically centred, over a backplate that does NOT change
// with selection. See SettingsNavItem.qml for why inventing a selected fill
// would be inventing a state Windows does not have.
//
// `cache: false` ON THE Image BELOW IS A HARD REQUIREMENT. The facade reloads
// the portrait by setting `avatarSource` to nothing and back, because an Image
// caches by URL and this URL never changes. Without `cache: false` the second
// assignment is answered out of Qt's pixmap cache, and the portrait silently
// stops updating after the first change -- a window that works perfectly and a
// picture that is somebody's old one. There is no property the facade could
// have made `required` to prevent it. Rule 7.
//
// THE WHOLE BLOCK IS THE TARGET, not the portrait and not the name. An entry
// you have to aim at is an entry that reads as decoration.
//
// THE PICTURE IS OPTIONAL AND THE FALLBACK IS THE INITIAL OVER THE ACCENT.
// Both are drawn; which one is visible is decided by the Image's own status,
// so there is no third state where neither is up. Note the letter's colour:
// TEXT ON AN ACCENT FILL IS BLACK in dark mode, because Windows' dark accent
// is the LIGHT shade of the accent ramp. Theme.textOnPrimary is that black and
// it is not a mistake to be fixed to white.

import QtQuick
import QtQuick.Effects
import qs
// UserBlock is modules/settings/UserBlock.qml -- the facade -- and not this
// file, even though a QML document implicitly imports its own directory. The
// explicit import wins; see the note in ToggleRow.qml. SessionInfo is a
// singleton in the same directory: rule 5 says host state is reached with
// `import qs.modules.<name>` and not through `row`.
import qs.modules.settings
// Fluent lives one directory up; see the note at the top of Fluent.qml on the
// ReferenceError this line prevents.
import ".."

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property UserBlock row

    // OURS, all three. See the header: Microsoft publishes nothing about this
    // block. The portrait is 32 because that is the size at which a face is
    // still a face beside two lines of text; the gap is 16, which is the same
    // inset the pane uses on its own contents; and the padding is what takes
    // the block to the 56 the facade floors at, so the drawing and the floor
    // agree rather than being two opinions.
    readonly property int portrait: 32
    readonly property int gap: 16
    readonly property int paddingV: 12

    // NOT OURS, and it is why the portrait is not simply flush. The rail below
    // puts its icons in a 40px column (Fluent.navIconColumn) measured from the
    // entry's left edge, and this block is inset by exactly the same
    // railPadding the rail list is -- so centring the portrait in that same
    // column lines the face up with the glyphs under it, and leaves the three
    // pixels the indicator needs at the left edge.
    readonly property int portraitInset: (Fluent.navIconColumn - root.portrait) / 2

    // WHAT THE FACADE READS BACK. The taller of the portrait and the two
    // lines, plus the padding above and below.
    implicitHeight: Math.max(root.portrait, labels.implicitHeight) + 2 * root.paddingV

    radius: Fluent.controlRadius

    // NO `Behavior on color`, and no selected fill: hover brightens, press
    // dims, and selection is the bar on the left. Fluent.hoverMs is 0 on
    // purpose.
    color: mouse.pressed ? Fluent.fillPress
        : mouse.containsMouse ? Fluent.fillSubtleHover
        : "transparent"

    // ---------------- The selection indicator ----------------
    //
    // The rail's, verbatim -- see SettingsNavItem.qml, which draws the same
    // three pixels for the same reason.
    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.indicatorWidth
        height: root.row.selected ? Fluent.indicatorHeight : 0
        radius: Fluent.indicatorRadius

        color: Theme.primary

        Behavior on height {
            NumberAnimation {
                duration: Fluent.normalMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Fluent.easePointToPoint
            }
        }
    }

    // ---------------- The portrait ----------------
    Rectangle {
        id: avatar

        anchors.left: parent.left
        anchors.leftMargin: root.portraitInset
        anchors.verticalCenter: parent.verticalCenter

        width: root.portrait
        height: root.portrait
        radius: height / 2

        color: Theme.primary

        Text {
            anchors.centerIn: parent
            visible: picture.status !== Image.Ready

            text: SessionInfo.user.charAt(0).toUpperCase()
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.strongWeight
            // BLACK on the accent, in dark mode. See the header.
            color: Theme.textOnPrimary
        }

        // ROUND, AND THAT TAKES AN EFFECT. An Image is a rectangle: put inside
        // a rounded parent it keeps its own square corners, and `clip` does
        // not help because it clips to the bounding box and not to the curve.
        // The first version of this in genesis used MultiEffect with only
        // maskSpreadAtMin set, and the result was a perfectly square
        // photograph sitting in a circular hole.
        //
        // What was missing is maskThresholdMin. Without it the mask is cut at
        // a hard step at zero, which for a fully opaque mask texture means
        // everything passes and nothing is masked at all. The pair below --
        // 0.5 and 1.0 -- is the one CornerWedge.qml arrived at, where the note
        // says the spread is what keeps the antialiasing on the cut edge
        // instead of throwing it away.
        //
        // The mask is a Rectangle with a colour and its own layer, not an Item
        // wrapping one: the layer texture comes from the item the property is
        // set on, so a bare wrapper renders an empty mask.
        Image {
            id: picture

            anchors.fill: parent
            source: root.row.avatarSource
            // NOT OPTIONAL. See the top of this file: the facade reloads this
            // picture by writing its URL twice, and Qt's pixmap cache answers
            // the second write out of the first unless this is false.
            cache: false
            fillMode: Image.PreserveAspectCrop
            // Asked for at twice the size it is drawn at, so it stays sharp on
            // a scaled output without a 1024px portrait being held in memory
            // to be shown at 32.
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            smooth: true

            // A missing file is the normal case here, not an error.
            visible: false
            layer.enabled: true
        }

        Rectangle {
            id: pictureMask

            anchors.fill: parent
            radius: height / 2
            antialiasing: true
            color: "black"

            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: picture
            visible: picture.status === Image.Ready
            maskEnabled: true
            maskSource: pictureMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    // ---------------- The two lines ----------------
    Column {
        id: labels

        anchors.left: avatar.right
        anchors.leftMargin: root.gap
        anchors.right: parent.right
        anchors.rightMargin: root.gap
        anchors.verticalCenter: parent.verticalCenter

        // Body Strong: 14, Semibold. Windows 11 says Semibold for emphasis and
        // never Bold, which is why genesis's Font.Bold is gone.
        Text {
            width: parent.width
            text: SessionInfo.displayName
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.strongWeight
            color: Theme.textOnSurface
        }

        // Caption: 12, secondary.
        Text {
            width: parent.width
            text: `${SessionInfo.user}@${SessionInfo.host}`
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurfaceVariant
        }
    }

    // The block asks the facade; it does not act. Rule 4: a theme reads `row`
    // and emits through it, and has no idea that the window answers this by
    // clearing the search and selecting page zero.
    //
    // No hand cursor: see the note on the caption button in SettingsHeader.qml.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.row.clicked()
    }
}
