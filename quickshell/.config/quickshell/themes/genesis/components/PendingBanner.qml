// How genesis draws a change that is about to undo itself: an amber frame, an
// hourglass, the question with the seconds counting down inside it, and the two
// ways out. The public half -- why this is not a ConfirmButton, why the clock
// that counts the seconds is nowhere near this file, and why the arrangement's
// identical banner is NOT built from it -- is
// modules/settings/pages/display/PendingBanner.qml.
//
// THE AMBER IS A STATE AND NOT AN ERROR. It is the shell's warning colour, the
// same one the Wi-Fi hardware-switch line uses: nothing has gone wrong, and
// what is on screen is about to end by itself.
//
// THE FRAME IS INSET FOUR PIXELS from the facade, which spans the card. That is
// this theme's decision and it is here rather than in the width the card hands
// over, so a theme with a rounder card can pull it in further -- the same trade
// SettingsSection makes with the margin around its slot.
//
// "Keep" AND A SAVE GLYPH, because that one press does both things: it stops
// the countdown AND it is what writes the change to the generated file. A tick
// here would say the change was merely accepted. The second chip does what the
// timer is about to do anyway, for when you can already see it is wrong and
// would rather not sit through the countdown.
//
// NEITHER CHIP DECIDES ANYTHING. `row.kept()` and `row.reverted()` are
// requests; what they mean -- a write, or a spec sent back to the compositor --
// is the page's, and rule 4 in README.md is why it stayed there.

import QtQuick
import qs
import qs.components
// PendingBanner is modules/settings/pages/display/PendingBanner.qml -- the
// facade -- and not this file, even though a QML document implicitly imports
// its own directory. The explicit import wins; see the note in ToggleRow.qml.
import qs.modules.settings.pages.display

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `PendingBanner` here is the facade and
    // not this file.
    required property PendingBanner row

    // WHAT THE FACADE READS BACK. One line tall, always: the question and the
    // chips sit side by side. The facade floors at the same number, so this is
    // what the banner was before the split rather than a second opinion.
    implicitHeight: Theme.groupHeight

    // AN Item ROOT WITH THE FRAME INSIDE IT, AND NOT AN ANCHORED Rectangle. The
    // facade's Loader anchor-fills the facade and assigns this item's width and
    // height directly, so a root that also anchored itself to its parent would
    // be two writers to the same two properties. The inset lives one level in,
    // where nothing is fighting it for the geometry.
    Rectangle {
        anchors.fill: parent
        // Four pixels in from each edge, which is where this rectangle was
        // before the split -- it was `x: 4` with `width: parent.width - 8` on
        // the card's own Column, and the facade spans the card now.
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        radius: Theme.groupRadius

        // The shell's amber, the same one the Wi-Fi hardware-switch line uses:
        // this is not an error, it is a state that is about to end by itself.
        color: Qt.alpha(Theme.warning, 0.16)
        border.width: 1
        border.color: Theme.warning

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.timerSand
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: Theme.warning

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // THE QUESTION IS THE CALLER'S AND THE COUNTDOWN IS THIS FILE'S.
            // Both call sites end the same way -- "Reverting in 7s" -- and only
            // the question in front of it changes, so the sentence is assembled
            // once here rather than spelled out at each site.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${root.row.question} Reverting in ${root.row.seconds}s`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                font.weight: Font.Bold
                color: Theme.textOnSurface

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding - 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.itemSpacing

            Chip {
                anchors.verticalCenter: parent.verticalCenter
                label: "Keep"
                glyph: Icons.contentSave
                filled: true
                onActivated: root.row.kept()
            }

            Chip {
                anchors.verticalCenter: parent.verticalCenter
                label: "Revert now"
                onActivated: root.row.reverted()
            }
        }
    }
}
