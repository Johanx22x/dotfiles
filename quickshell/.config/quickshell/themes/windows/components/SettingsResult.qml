// How the windows theme draws one answer in the settings window's search: the
// row's own name over the trail that places it, and the row's glyph beside
// them when it has one. The public half is modules/settings/SettingsResult.qml.
//
// THE THEME OWNS THE HOVER AND THE HIT TARGET HERE, which is the opposite of
// SettingsNavItem next door and is worth knowing before copying either. That
// entry's MouseArea stays on the facade because a `preventStealing` flag is
// load-bearing there; nothing of the sort applies to a result, so the target
// is drawn with the shape, where it belongs.
//
// THE WHOLE ROW IS THE TARGET. A result you have to hit on the words is a
// result you have to aim at, and picking one is the only thing anybody does
// in this pane.
//
// THE TRAIL IS WHAT PLACES A ROW WITH A GENERIC NAME: "Default timeout" alone
// could be three things. It is dropped when the section repeats the page's own
// title, because "Notifications › Notifications" says the same word twice and
// places nothing.
//
// ---------------------------------------------------------------------------
// WHICH OF WINDOWS' ROWS THIS IS, AND WHERE ITS NUMBERS COME FROM
// ---------------------------------------------------------------------------
//
// A result is a SETTINGS ROW SHOWN OUT OF CONTEXT, so it is drawn with the
// Community Toolkit's SettingsCard metrics rather than with a list item's:
// SettingsCardPadding 16 (Theme.groupPadding under this theme), an icon box of
// 20 (Fluent.cardIconMax) and 20 between it and the text (Fluent.cardIconGap).
// The two lines are the card's own pair -- Header in Body 14 and Description
// in Caption 12 secondary -- which is what a settings row looks like on the
// page this result is pointing at.
//
// WHAT IS NOT THE CARD'S is the backplate. A card sits at
// CardBackgroundFillColorDefault and does not react to a pointer; this is a
// list of answers, so it is a SUBTLE row: transparent at rest,
// SubtleFillColorSecondary on hover, and DARKER than hover when pressed. Press
// dims. ControlCornerRadius 4, because an in-page element is 4 and only
// overlays are 8.
//
// THE GLYPH IS OPTIONAL AND ITS COLUMN GOES WITH IT. Most rows in this shell
// have none, so a kept column would be a strip of air down the left of the
// usual case.

import QtQuick
import qs
// SettingsResult is modules/settings/SettingsResult.qml -- the facade -- and
// not this file, even though a QML document implicitly imports its own
// directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings
// Fluent lives one directory up; see the note at the top of Fluent.qml on the
// ReferenceError this line prevents.
import ".."

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required` and why it is
    // typed rather than `var`.
    required property SettingsResult row

    // OURS. Microsoft's own row is a fixed 68 tall (SettingsCardMinHeight) and
    // this one is not: the result list is capped at twelve and a fixed 68
    // would spend the whole pane on four answers. So the two lines set the
    // height and this is what is left above and below them.
    readonly property int paddingV: 8

    // Hoisted, because the two things that use it read it twice each and
    // because `row.glyph` is the name rule 3 is about -- it is read here and
    // never declared.
    readonly property bool hasGlyph: root.row.glyph !== ""

    // WHAT THE FACADE READS BACK: the two lines plus the padding. The facade
    // floors it at one row plus eight, which is what a result was before the
    // split, so the floor and this agree rather than being two opinions.
    implicitHeight: labels.implicitHeight + 2 * root.paddingV

    radius: Fluent.controlRadius

    // NO `Behavior on color`: the brush swap is instant in Windows, and
    // Fluent.hoverMs is 0 on purpose. fillPress is the level BELOW rest --
    // hover brightens, press dims.
    color: resultMouse.pressed ? Fluent.fillPress
        : resultMouse.containsMouse ? Fluent.fillSubtleHover
        : "transparent"

    Text {
        id: resultGlyph

        anchors.left: parent.left
        anchors.leftMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.cardIconMax
        horizontalAlignment: Text.AlignHCenter
        visible: root.hasGlyph

        text: root.row.glyph
        font.family: Theme.fontFamily
        // A box and not type; see the note on the icon in SettingsNavItem.qml.
        font.pixelSize: Fluent.cardIconMax
        color: Theme.textOnSurfaceVariant
    }

    Column {
        id: labels

        anchors.left: root.hasGlyph ? resultGlyph.right : parent.left
        anchors.leftMargin: root.hasGlyph ? Fluent.cardIconGap : Theme.groupPadding
        anchors.right: parent.right
        anchors.rightMargin: Theme.groupPadding
        anchors.verticalCenter: parent.verticalCenter

        Text {
            width: parent.width
            text: root.row.label
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }

        // The trail, so a row with a generic name is placed. Caption 12 in the
        // secondary text colour: the card's Description, exactly.
        Text {
            width: parent.width
            text: root.row.section !== "" && root.row.section !== root.row.pageTitle
                ? `${root.row.pageTitle} › ${root.row.section}`
                : root.row.pageTitle
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Fluent.captionSize
            color: Theme.textOnSurfaceVariant
        }
    }

    // The row asks the facade; it does not act. Rule 4: a theme reads `row`
    // and emits through it, and has no idea that the window answers this by
    // highlighting a row on a page it is about to select.
    //
    // No hand cursor: Windows keeps the arrow over a list row. See the same
    // note on the caption button in SettingsHeader.qml.
    MouseArea {
        id: resultMouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.row.clicked()
    }
}
