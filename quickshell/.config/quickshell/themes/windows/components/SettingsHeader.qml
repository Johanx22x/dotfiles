// How the windows theme draws the settings window's header line: the page's
// name in Title, and the caption button that closes the window. The public
// half -- `heading`, `closeRequested`, and the note on why the box's height is
// the facade's -- is modules/settings/SettingsHeader.qml.
//
// THE CLOSE BUTTON IS THE ONLY POINTER-REACHABLE WAY OUT OF THIS WINDOW, and
// that is the promise this file inherited. There is no title bar: Qt offers to
// draw decorations, Hyprland answers that it will handle them server-side and
// then draws none. A theme that leaves the button out leaves Escape and
// SUPER + W, which is a keyboard-only window and not what this one promises.
// Rule 7 in themes/genesis/components/README.md.
//
// `heading` AND NOT `title`, and this file must not declare either: `title` on
// the FloatingWindow is the string the compositor puts in its window list, and
// modules/settings/SettingsSearch.qml duck-types a section as anything
// carrying a non-empty `title` by walking the live tree straight through the
// facade's Loader and into this item. Rule 3.
//
// ---------------------------------------------------------------------------
// THE TWO PIECES, AND WHERE THEIR NUMBERS COME FROM
// ---------------------------------------------------------------------------
//
// THE NAME IS `Title`: 28 / 36 line, Semibold -- Fluent.titleSize,
// Fluent.titleLine and Fluent.strongWeight. Semibold and never Bold is
// Windows 11's typography rule in as many words, which is why genesis's
// Font.Bold is gone rather than tuned.
//
// THE BUTTON IS A CAPTION BUTTON, 46 wide, radius 0, with a 10x10 glyph box.
// Read out of Windows Terminal's MinMaxCloseControl.xaml, which is the
// shell-styled caption control Microsoft ships as source: `Width="46.0"`, a
// `Viewbox Width="10" Height="10"` around the glyph, and two heights --
// `CaptionButtonHeightWindowed` 40 and `CaptionButtonHeightMaximized` 32. The
// 32 is the one used, because this is a header inside a content pane and not a
// title bar across the top of a window; at 40 the button would be taller than
// the line of text beside it.
//
// The four numbers are declared in this file rather than in Fluent.qml because
// they have exactly one reader -- this component is the only caption button in
// the theme -- and because the fifth thing they come with is not a number at
// all but the red below, which no scheme role can hold. If a second surface
// ever draws a caption button, they move up.

import QtQuick
import qs
// SettingsHeader is modules/settings/SettingsHeader.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings
// Fluent lives one directory up; see the note at the top of Fluent.qml on the
// ReferenceError this line prevents.
import qs.themes.windows

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property SettingsHeader row

    // Caption button geometry. Microsoft's; see the header for the file each
    // one is read out of.
    readonly property int captionWidth: 46
    readonly property int captionHeight: 32
    readonly property int captionGlyph: 10

    // ---------------------------------------------------------------------
    // THE ONE HEX LITERAL IN THIS THEME, AND WHY IT IS THE RIGHT ANSWER HERE
    // ---------------------------------------------------------------------
    //
    // Everywhere else in this theme colour comes from Theme, because
    // schemes/windows-11-dark.json already composites Microsoft's alpha
    // overlays onto Microsoft's base and the roles it publishes ARE the WinUI
    // brushes. This red is not one of them.
    //
    // `CloseButtonColor` is #C42B1C in MinMaxCloseControl.xaml's Light
    // dictionary AND in its Dark one -- the same literal, written twice, one
    // in each. IT DOES NOT THEME. There is no role for it and there must not
    // be one: Theme.critical is `SystemFillColorCritical`, which IS #C42B1C in
    // the light dictionary and #FF99A4 in the dark one
    // (Common_themeresources_any.xaml), so reading the role here would paint
    // the close button pink in dark mode and would be a real Microsoft colour
    // while it did it -- the classic recreation failure, arriving through the
    // one door this theme leaves open.
    //
    // The rest of the button's states are that colour's, out of the same file:
    // hover is the colour, opaque, with a WHITE glyph; pressed is the same
    // brush at Opacity 0.9 with the glyph at 0.7. Press dims, as everywhere
    // else in Windows.
    readonly property color closeRed: "#C42B1C"

    // The glyph that goes with it, and it does not theme either:
    // `CloseButtonForegroundPointerOver` is `Color="White"` in both
    // dictionaries. A `color` property rather than the string at the call site
    // because Qt.alpha() takes a colour and not a name.
    readonly property color closeWhite: "white"

    // WHAT THE FACADE READS BACK. The Title style's line box, floored by the
    // caption button so the button never overflows the header it sits in. The
    // facade floors again at Theme.groupHeight; the larger of the three wins.
    implicitHeight: Math.max(Fluent.titleLine, root.captionHeight)

    // ---------------- The page's name ----------------
    //
    // NO LEFT MARGIN. modules/settings/Settings.qml anchors this whole item
    // with `anchors.margins: Theme.groupPadding` off the rail's right edge, so
    // the inset from the content pane is already spent and a second one here
    // would be counted twice.
    //
    // IT ELIDES AGAINST THE BUTTON and not against the pane's right edge, so a
    // long page title stops before the button rather than under it.
    Text {
        anchors.left: parent.left
        anchors.right: closeButton.left
        anchors.rightMargin: Fluent.controlPaddingH
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.heading
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Fluent.titleSize
        font.weight: Fluent.strongWeight
        color: Theme.textOnSurface
    }

    // ---------------- Close ----------------
    //
    // SQUARE, AND THAT IS NOT AN OVERSIGHT. Every other control in this theme
    // is ControlCornerRadius 4; a caption button is radius 0, because it is
    // meant to run into the corner of a window.
    //
    // NO `Behavior on color` and no hand cursor. The brush swap is instant
    // everywhere in Windows, and Windows shows the arrow over a caption
    // button -- the pointing hand belongs to hyperlinks and this shell's own
    // controls, not to this one.
    Rectangle {
        id: closeButton

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: root.captionWidth
        implicitHeight: root.captionHeight
        radius: 0

        color: closeMouse.pressed ? Qt.alpha(root.closeRed, 0.9)
            : closeMouse.containsMouse ? root.closeRed
            : "transparent"

        Text {
            anchors.centerIn: parent

            text: Icons.close
            font.family: Theme.fontFamily
            // The glyph is a 10x10 box, which is a size and not type; see the
            // note on the icon in SettingsNavItem.qml for why that is
            // pixelSize.
            font.pixelSize: root.captionGlyph

            // White on the red; at rest the window's own foreground, which is
            // what CaptionButtonForeground resolves to (the base-high brush).
            color: closeMouse.pressed ? Qt.alpha(root.closeWhite, 0.7)
                : closeMouse.containsMouse ? root.closeWhite
                : Theme.textOnSurface
        }

        // The button asks the facade; it does not act. Rule 4: a theme reads
        // `row` and emits through it, and has no idea that there is a window
        // behind this, let alone how it is closed.
        MouseArea {
            id: closeMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.row.closeRequested()
        }
    }
}
