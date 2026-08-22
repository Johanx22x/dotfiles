// The settings rail, at the size it really is, out of the files it really is.
//
// This is the scene wheel-and-click.py drives; the whole account of what is
// being asked and why lives in that file's header. What matters here is that
// almost nothing below is a stand-in. `ScrollList` and `SettingsNavItem` are
// imported straight out of quickshell/ by relative path, so an edit to either
// is an edit to what this measures -- which is the one property the bench that
// preceded this one did not have, and the reason it agreed with a change that
// removed all scrolling from the settings window.
//
// THE GEOMETRY IS THE RAIL'S, AND IT IS THE WHOLE REASON THERE IS A BUG TO
// MEASURE. The settings window is pinned at 820x580 and the rail is 210 wide
// with 10 of padding, so the list is 190 across; under the user block and the
// search field it has 452 px of height left. Fourteen entries of
// Theme.groupHeight with 2 between them are 530 px tall. 530 over 452 leaves
// 78 px hidden, which is Updates and About -- the two entries anybody has ever
// reported as not opening, and the two that cannot be reached without
// scrolling first. Shrink this scene and the bug stops existing; the bench
// would still pass and would be measuring nothing.
//
// 452 IS COPIED AND NOT DERIVED, and that is deliberate. Deriving it would
// mean instantiating UserBlock and SearchField, which pull in the icon font,
// the config singleton and a text input -- a large amount of machinery for a
// number that has been measured three times and is a constant of a window that
// cannot be resized. If the window's size or the rail's furniture ever change,
// this number is wrong and the header of Settings.qml is where the new one is.
//
// THE PLAIN FLICKABLE BESIDE IT IS THE BENCH'S OWN CALIBRATION and not a
// second subject. It is bare QtQuick -- a Flickable with plain MouseAreas in
// it, no ScrollList, no SettingsNavItem, nothing from this repository at all --
// so it behaves the way Qt behaves and no change to this repository can alter
// it. The driver asserts that a click on it right after a wheel notch is LOST.
// That is what makes every "the click landed" above it mean something: a bench
// that cannot see a click go missing cannot report that one did not.

import QtQuick
import "../quickshell/.config/quickshell/components"
import "../quickshell/.config/quickshell/modules/settings"

Item {
    id: scene

    // The settings window, pinned. Settings.qml: implicitWidth 820,
    // implicitHeight 580.
    width: 820
    height: 580

    // The rail panel. Settings.qml: width 210, padding 10.
    readonly property int railWidth: 210
    readonly property int railPadding: 10

    // Measured off the real window; see the note at the top of this file.
    readonly property int listHeight: 452

    // Settings.qml: `spacing: 2` on the Column the Repeater fills.
    readonly property int entrySpacing: 2

    // The fourteen rail subjects, in the order the page host declares them --
    // index 0 there is the user page, which is reached through the user block
    // and takes no rail entry. Updates is 12 and About is 13, and those two are
    // the ones below the fold.
    readonly property var entryLabels: [
        "Appearance", "Wallpaper", "Bar", "Notifications", "Display", "Audio",
        "Recording", "Input", "Network", "Bluetooth", "Apps", "Keybinds",
        "Updates", "About"
    ]

    // --- what the driver reads back ------------------------------------
    //
    // A click is "heard" when the entry under the pointer emits its own
    // clicked signal. Not when the press was delivered to the window -- it
    // always is -- and not when some ancestor saw it. The whole bug is that
    // the press reaches the window and the entry never learns of it.
    property int railHeard: -1
    property int railHeardCount: 0
    property int plainHeard: -1
    property int plainHeardCount: 0

    // WHERE TO AIM, AND WHY IT IS A FIXED POINT IN THE VIEWPORT rather than
    // an entry chased down the list. The click is sent with the scroll
    // animation still running, so "the entry under the pointer" is whatever
    // contentY happens to be at that instant -- and a point pinned to an entry
    // would be off the bottom of the window entirely when the list has not
    // arrived yet, which is a click that misses rather than a click that was
    // taken. That distinction is the whole measurement.
    //
    // 200 IS CHOSEN AND NOT ARBITRARY. Entries are Theme.groupHeight tall with
    // 2 px between them, so 2 px in every 38 fall in a gap where no entry is.
    // At the two positions this bench ever clicks at -- contentY 0 and
    // contentY 78, the top of the list and the bottom -- 200 lands 10 px into
    // entry 5 and 12 px into entry 7. aimOnEntry says so out loud, and the
    // driver refuses to assert anything if it is ever false: a bench that
    // sometimes aims into a 2 px gap would report a missing click that nothing
    // took, which is the one failure mode worse than not measuring at all.
    readonly property int aimViewportY: 200

    readonly property real aimX: railList.x + 60
    readonly property real aimY: railList.y + scene.aimViewportY
    readonly property int aimIndex: Math.floor((railList.contentY + scene.aimViewportY)
        / (Theme.groupHeight + scene.entrySpacing))
    readonly property bool aimOnEntry: ((railList.contentY + scene.aimViewportY)
        % (Theme.groupHeight + scene.entrySpacing)) < Theme.groupHeight

    // The same aim, on the calibration Flickable.
    readonly property real plainAimX: plainList.x + 60
    readonly property real plainAimY: plainList.y + scene.aimViewportY
    readonly property bool plainAimOnEntry: ((plainList.contentY + scene.aimViewportY)
        % (Theme.groupHeight + scene.entrySpacing)) < Theme.groupHeight

    // --- the rail ------------------------------------------------------
    Rectangle {
        id: rail

        x: 0
        y: 0
        width: scene.railWidth
        height: scene.height
        color: Theme.surfaceContainerHigh

        // THE REAL ScrollList, out of quickshell/. showScrollBar is false for
        // the same reason it is false at the real call site: the rail places
        // its own bar in the panel padding beside the list, from outside.
        ScrollList {
            id: railList
            objectName: "railList"

            x: scene.railPadding
            y: scene.height - scene.listHeight - scene.railPadding
            width: rail.width - 2 * scene.railPadding
            height: scene.listHeight

            contentHeight: railItems.implicitHeight
            showScrollBar: false

            Column {
                id: railItems

                width: parent.width
                spacing: scene.entrySpacing

                Repeater {
                    model: scene.entryLabels

                    // THE REAL SettingsNavItem, out of quickshell/. Its
                    // preventStealing is half of what is under test.
                    SettingsNavItem {
                        required property var modelData
                        required property int index

                        glyph: ""
                        label: modelData
                        onClicked: {
                            scene.railHeard = index;
                            scene.railHeardCount += 1;
                        }
                    }
                }
            }
        }
    }

    // --- the calibration, which is bare Qt ------------------------------
    Flickable {
        id: plainList
        objectName: "plainList"

        x: 300
        y: railList.y
        width: railList.width
        height: railList.height

        contentWidth: width
        contentHeight: plainItems.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: plainItems

            width: parent.width
            spacing: scene.entrySpacing

            Repeater {
                model: scene.entryLabels

                // Deliberately NOT SettingsNavItem. This has no
                // preventStealing and no wheel handler above it, so it is what
                // an entry in a Flickable does when nothing in this repository
                // has intervened -- which is to lose the click.
                Rectangle {
                    required property int index

                    width: plainItems.width
                    height: Theme.groupHeight
                    color: "transparent"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            scene.plainHeard = parent.index;
                            scene.plainHeardCount += 1;
                        }
                    }
                }
            }
        }
    }
}
