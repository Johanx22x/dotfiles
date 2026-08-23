// How the windows theme draws one entry in the settings window's navigation
// rail. The public half -- and the long note on why the MouseArea did NOT come
// down here with the drawing -- is modules/settings/SettingsNavItem.qml.
//
// THERE IS NO MOUSEAREA IN THIS FILE AND THERE MUST NOT BE ONE. The facade
// keeps the hit target, because its `preventStealing: true` is the whole of a
// bug reported as "Updates does not open" and a theme that drew its own target
// would have to remember to set a flag it has no reason to know about. What
// this side gets instead is `hovered`, a readonly property the facade's one
// MouseArea writes. Rule 7 in themes/genesis/components/README.md: nothing
// checks this, and it is a promise all the same.
//
// ---------------------------------------------------------------------------
// SELECTION IS THE BAR AND NOTHING ELSE, WHICH IS THE WHOLE POINT OF THE ENTRY
// ---------------------------------------------------------------------------
//
// THE SELECTED PILL'S FILL IS IDENTICAL TO THE HOVER FILL. Both are
// SubtleFillColorSecondary, verbatim from NavigationView_themeresources.xaml,
// which is Theme.surfaceContainerHigh under this scheme and Fluent.fillSubtleHover
// by name. Selection is carried ENTIRELY by the 3x16 accent indicator at the
// pill's left edge. A recreation that gives selection a backplate colour of
// its own -- which is what genesis's drawing of this component does, correctly
// for genesis -- has invented a state Windows does not have.
//
// The consequence is worth stating because it looks like a bug when the mouse
// is over the selected entry: hovering the selected entry changes nothing at
// all. That is right. The bar is what says "this one".
//
// EVERY METRIC BELOW IS VERBATIM FROM NavigationView_themeresources.xaml and
// lives in Fluent.qml:
//
//   pill height            36   Fluent.navItemHeight
//   row pitch              40   Fluent.navItemPitch      (margin 4,2)
//   icon                16x16   Fluent.navIcon
//   icon column            40   Fluent.navIconColumn
//   label left edge        48   Fluent.navLabelLeft, from the item's left
//   indicator      3x16, r=2    Fluent.indicator*, accent, flush left, centred
//
// THERE IS NO PRESSED TONE HERE AND THERE CANNOT BE ONE. Windows has three:
// rest, hover (SubtleFillColorSecondary) and press (SubtleFillColorTertiary,
// which is DARKER than hover). The facade publishes `hovered` and nothing
// else, because the MouseArea that would know is on the other side of the
// seam and only its hover is exported. An entry of this theme therefore has
// two tones where Windows has three, and closing that would take a `pressed`
// on the facade beside `hovered` -- a change to the interface, not to a
// drawing.
//
// THE LABEL ELIDES against the rail's width rather than pushing the icon out
// of the pill. The width arrives from SettingsChrome's `railWidth` through the
// rail, the list and the facade, so there is one number and this file is not
// one of the places it is written.

import QtQuick
import qs
// SettingsNavItem is modules/settings/SettingsNavItem.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings
// Fluent lives one directory up; see the note at the top of Fluent.qml on the
// ReferenceError this line prevents.
import ".."

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property SettingsNavItem row

    // WHERE A LONG LABEL RUNS OUT. OURS: Microsoft publishes a left edge for
    // the label and no right inset for it, and this only decides where a name
    // too long for the rail is cut. ButtonPadding's 11 stands in.
    readonly property int labelRightInset: Fluent.controlPaddingH

    // WHAT THE FACADE READS BACK. The PITCH and not the pill: an entry is a
    // 36px pill inside a 40px row, from NavigationViewItemMargin's 4,2, and
    // the two vertical pixels at each end are what leave the gap between one
    // entry and the next.
    //
    // IT DOES NOT COME OUT AT 40 IN THE WINDOW, and that is not this file's to
    // fix: modules/settings/Settings.qml:268 gives the rail's Column
    // `spacing: 2`, a host literal no token reaches, so the real pitch is 42
    // and the gap between pills is 6 where Windows draws 4.
    implicitHeight: Fluent.navItemPitch

    // ---------------- The pill ----------------
    //
    // NO `Behavior on color`. Windows swaps a control's brush on a
    // DiscreteObjectKeyFrame at time zero -- Fluent.hoverMs is 0 and it is 0 on
    // purpose. A fade here is the tell that gives a recreation away fastest,
    // because every real control in the same session is swapping without one.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        height: Fluent.navItemHeight
        radius: Fluent.controlRadius

        color: root.row.selected || root.row.hovered ? Fluent.fillSubtleHover : "transparent"
    }

    // ---------------- The selection indicator ----------------
    //
    // Flush with the pill's left edge, vertically centred, accent, 3x16 at
    // radius 2.
    //
    // IT GROWS RATHER THAN APPEARING, and that is as much of Windows'
    // animation as this seam can hold. NavigationView animates ONE indicator
    // between entries over 600ms, stretching it toward the destination and
    // letting it settle -- which takes an indicator that outlives the entry it
    // is on. Here every entry draws its own and nothing on the facade says
    // which entry was selected before this one, so the travel is not
    // expressible: what is left is the stretch, on the axis the travel would
    // have used, at the point-to-point easing the shell spec gives for exactly
    // that kind of move. Selection DOES animate in Windows; hover does not,
    // and neither does this.
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

    // ---------------- The icon ----------------
    //
    // A 16x16 box centred in a 40px column measured from the item's left edge.
    // font.pixelSize AND NOT pointSize, alone in this file: Fluent.qml's rule
    // is that sizes are absolute and text is relative, and Windows specifies
    // this glyph as a 16 epx BOX rather than as type. The label below is text
    // and is sized the other way.
    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.navIconColumn
        horizontalAlignment: Text.AlignHCenter

        text: root.row.glyph
        font.family: Theme.fontFamily
        font.pixelSize: Fluent.navIcon
        color: Theme.textOnSurface
    }

    // ---------------- The label ----------------
    //
    // Body 14 at NORMAL weight, and it stays Normal when the entry is
    // selected: NavigationView emboldens nothing. Windows 11's typography rule
    // is Semibold for emphasis and never Bold, and an entry is not emphasis.
    Text {
        anchors.left: parent.left
        anchors.leftMargin: Fluent.navLabelLeft
        anchors.right: parent.right
        anchors.rightMargin: root.labelRightInset
        anchors.verticalCenter: parent.verticalCenter

        text: root.row.label
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Fluent.bodySize
        font.weight: Fluent.normalWeight
        color: Theme.textOnSurface
    }
}
