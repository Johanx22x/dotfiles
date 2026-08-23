// How the windows theme draws the settings window's own surfaces. The public
// half -- the rail's two numbers, where they come from, and the long note on
// why they are published there rather than read back off this file -- is
// modules/settings/SettingsChrome.qml.
//
// TWO RECTANGLES AND NOTHING ELSE, IN THE ORDER THE FACADE STATES: the
// window's glass first, the second surface over it. That order is not covered
// by any rule in themes/genesis/components/README.md and no test asserts it;
// it is the sequence the window painted in before the split, the facade's
// header states it, and this file keeps it deliberately rather than by
// accident.
//
// WHAT CHANGED IS WHICH RECTANGLE THE SECOND ONE IS, and it is the one thing
// about Windows' layering that surprises everybody who comes from a Linux
// sidebar: THE CONTENT PANE IS LIGHTER THAN THE NAVIGATION PANE.
//
//   layer                     Windows resource                     dark
//   ------------------------  -----------------------------------  -------
//   the window, and the pane  Mica -> SolidBackgroundFillColorBase  #202020
//   the pane's own fill       SolidBackgroundFillColorTransparent   nothing
//   the content pane          LayerFillColorDefault #4C3A3A3A       #282828
//   the content pane's edge   CardStrokeColorDefault                a stroke
//
// So the navigation pane has NO fill of its own -- it is the window's own
// ground, unpainted -- and the lift is on the other side. Genesis tints the
// rail because a Linux sidebar is darker than the pane beside it; this file
// tints the content, and the rail is what is left over.
//
// THE CONTENT PANE'S GEOMETRY IS SPECIFIC AND IS COPIED EXACTLY, from
// NavigationView_themeresources.xaml:
//
//   NavigationViewContentGridCornerRadius     8,0,0,0   top-left only
//   NavigationViewContentGridBorderThickness  1,1,0,0   top and left only
//
// The asymmetry people photograph off a Settings window is THIS pane and not
// the frame: Microsoft draws no top-vs-bottom radius distinction for the
// window itself, so nothing here rounds a window corner. Hyprland rounds the
// window, at the `rounding` in hyprland.lua that everything else agrees with.
//
// NO SIZE CONTRACT AT ALL. This item is anchors.fill'ed by the window and
// nothing is read back off it -- no implicitHeight, no implicitWidth. It is
// one of the two components for which reporting nothing is right rather than
// forgotten; the facade's header has the account.

import QtQuick
import qs
// SettingsChrome is modules/settings/SettingsChrome.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings
// Fluent lives one directory up and a file under components/ has an implicit
// import of components/ and of nothing else. Without this line the failure is
// at runtime, per read: `ReferenceError: Fluent is not defined`.
import qs.themes.windows

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property SettingsChrome row

    // THE ALPHA THAT PUTS MICROSOFT'S LAYER OVER THIS GROUND.
    //
    // LayerFillColorDefault is #4C3A3A3A -- thirty per cent of a MID GREY, not
    // of white -- and over SolidBackgroundFillColorBase it composites to
    // #282828, which is between Theme.surface (#202020) and a card
    // (Theme.surfaceContainer, #2b2b2b). No scheme role holds #3A3A3A and none
    // should: a layer is not a colour until it lands on something, which is
    // the same reason Fluent.qml keeps the lit edge's two ALPHAS rather than
    // two colours. Microsoft's recipe therefore cannot be written here.
    //
    // SO THIS REPRODUCES THE RESULT AND NOT THE RECIPE. surfaceContainerHighest
    // is #454545 in windows-11-dark, and 0.22 of it over #202020 lands on
    // #282828 exactly -- Microsoft's composite, out of two roles and one
    // number. Of the roles that can land on it, that is the one that needs the
    // LEAST alpha to get there, which is the whole of why it is the one used:
    // the tint is painted over the glass, so every point of alpha it spends is
    // a point by which the content side comes out more solid than the rail.
    // 0.22 against Microsoft's own 0.30 keeps the two sides reading as one
    // sheet.
    //
    // OURS: the alpha. The colour it lands on is Microsoft's.
    readonly property real layerAlpha: 0.22

    // ---------------- The window ----------------
    //
    // Mica's documented fallback IS SolidBackgroundFillColorBase, which is
    // Theme.surface, and glass() is the one number in this shell that is a
    // preference rather than a decision -- the same opacity kitty, Zen and
    // Hyprland read, and the one this very window edits. A Windows window is
    // a material and not a flat fill, so the dial is the closest thing this
    // theme has to Mica and it stays wired up.
    Rectangle {
        anchors.fill: parent

        color: Theme.glass(Theme.surface)
    }

    // ---------------- The content pane ----------------
    //
    // A TINT OVER THE GLASS AND NOT A SECOND GLASS LAYER, which is the promise
    // this file inherited from the rail it replaced. An opaque fill at its own
    // alpha would compound with the window's and the content side would come
    // out noticeably more solid than the pane beside it -- the two would stop
    // looking like one window seen through one sheet. A tint is what Windows
    // does anyway: LayerFillColorDefault is itself a translucent overlay over
    // whatever material is behind it.
    //
    // THE RIGHT AND BOTTOM EDGES HANG ONE PIXEL OUT OF THE WINDOW ON PURPOSE.
    // A Rectangle's border is drawn on all four sides and Windows asks for
    // top and left only (1,1,0,0), so the two that are not wanted are pushed
    // past the window's own edge, where nothing composites them. The
    // alternative -- two hairline Rectangles -- cannot follow the 8px arc in
    // the top-left corner, which is the one corner that is rounded.
    //
    // `railPadding` is NOT read here. It insets the pane's own contents -- it
    // is NavigationViewAutoSuggestBoxMargin, and the window applies it to the
    // user block, the search field and the rail list -- and neither of these
    // two rectangles is inset by anything.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: root.row.railWidth
        anchors.right: parent.right
        anchors.rightMargin: -1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -1

        color: Qt.alpha(Theme.surfaceContainerHighest, root.layerAlpha)

        radius: 0
        topLeftRadius: Fluent.overlayRadius

        border.width: 1
        border.color: Theme.outlineVariant
    }
}
