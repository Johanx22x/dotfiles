// The wallpaper page: which image is on the desktop, and whether it changes
// by itself.
//
// WHY THIS EXISTS WHEN THE LAUNCHER ALREADY HAS A PICKER. The launcher's strip
// is for choosing quickly and blind -- it opens, you walk it with the arrows,
// it closes. It cannot tell you which wallpaper you are looking at right now,
// because it never reads ~/.cache/wallpaper-current, and nothing else in this
// shell did either until this file. That reading is the whole point of the
// grid below: with fifty images in the folder, "which one is this?" is the
// question the picker leaves you with, and it is the one a settings window is
// the right place to answer.
//
// EVERYTHING HERE GOES THROUGH wallpaper-switch, the same script the keybinds
// and the rotation timer use, for the reason WallpaperPicker.qml already
// documents: the script is what sets the image AND regenerates the palette AND
// pushes the new border colour into Hyprland. Calling awww from here would
// change the picture and leave the rest of the desktop on the previous
// colours -- including this window, which is painted out of Theme.
//
// NOTHING ON THIS PAGE IS STORED IN Config. The two facts it shows already
// have owners outside the shell -- a state file written by the script, and a
// systemd timer -- so a copy in Config would be a second answer to a question
// that already has one, and the two would drift the first time the wallpaper
// was changed from a keybind.

import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import QtQuick.Effects
import "root:/"
import "root:/components"
// SettingsPage and SettingsSection live one directory UP, and QML's implicit
// import covers a file's own directory only.
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Wallpaper"
    glyph: Icons.image
    // "rotation" and "timer" appear nowhere on the page -- the switch says
    // "Change automatically" -- and they are what someone would type after
    // remembering that the desktop changes on its own.
    keywords: ["wallpaper", "background", "rotation", "timer", "random", "shuffle", "image"]

    // ---------------- What is applied right now ----------------
    //
    // IT IS A READING, NOT A CONTROL. The ring in the grid follows this
    // property, this property follows the state file, and the state file is
    // written by wallpaper-switch after awww has accepted the image. So the
    // ring lands on a thumbnail about a second and a half after it is clicked
    // -- the length of the crossfade -- and does not move at all if the script
    // fails. Moving it on click instead would be quicker and would be a lie in
    // exactly the case where the truth matters.
    readonly property string currentPath: stateFile.text().trim()

    readonly property string currentName: {
        if (root.currentPath === "")
            return "";
        return root.currentPath.split("/").pop().replace(/\.[^.]+$/, "");
    }

    // watchChanges only emits fileChanged(); reloading is the handler's job.
    // Without the reload this reads the file once at startup and then shows
    // whatever was applied when the shell launched -- the same trap Theme.qml
    // fell into with colors.json.
    FileView {
        id: stateFile

        path: `${Quickshell.env("HOME")}/.cache/wallpaper-current`
        watchChanges: true
        onFileChanged: {
            reload();
            // The wallpaper just changed. If that was the timer firing, the
            // next elapse moved with it. Harmless when the change came from a
            // click in the grid -- the schedule did not move -- and telling
            // the two cases apart is not worth more than the 4 ms this costs.
            root.probeRotation();
        }
        // A machine that has never changed its wallpaper has no state file.
        // That is a first run, not an error to print on every launch.
        printErrors: false
    }

    // ---------------- Rotation ----------------
    //
    // THE SWITCH IS A READING OF systemd TOO. It shows what `is-active` says,
    // not what was clicked: the click starts a process, the process finishes,
    // and only then is the state re-read. A few milliseconds, invisible in
    // use, and it means a failed enable leaves the switch where it was instead
    // of showing an "on" that nothing on the system agrees with.
    property bool rotating: false

    // A Date, or null when systemd has no next elapse for the unit.
    property var nextChange: null

    function probeRotation(): void {
        activeProbe.running = true;
        nextProbe.running = true;
    }

    // NO POLLING. The state is re-read when the page comes up, after the
    // switch is flipped, and when the wallpaper actually changes -- the three
    // moments it can have moved for a reason anyone is watching. A timer
    // ticking in the background would be spawning processes for a window that
    // is closed 99% of the time, which is the argument SessionInfo.qml makes
    // about /proc/uptime.
    //
    // `visible` is the flag the window drives from the selected page, and it
    // is the only thing that means "someone is reading this": every page is
    // built at startup and kept alive, so Component.onCompleted fires for
    // pages nobody has looked at. It is still worth one call below, for the
    // case where this page is the one the window opens on -- then `visible`
    // starts true and the handler never fires.
    onVisibleChanged: {
        if (!root.visible)
            return;

        root.probeRotation();
        Qt.callLater(root.revealCurrent);
    }

    Component.onCompleted: {
        if (root.visible)
            root.probeRotation();
    }

    // TURNING THIS ON ENABLES THE UNIT AS WELL AS STARTING IT, and that is a
    // decision, not a convenience.
    //
    // `start`/`stop` alone are runtime-only. Switch rotation off here, reboot,
    // and it is on again -- the timer is enabled in this install, verified
    // with `systemctl --user is-enabled wallpaper-rotate.timer`. A settings
    // window whose switches quietly revert is worse than one with no switch at
    // all: nothing on screen ever explains why.
    //
    // The cost is a write outside the dotfiles repo, and it was checked before
    // being accepted rather than assumed. The enablement is a single symlink
    // in ~/.config/systemd/user/timers.target.wants/, created by systemctl;
    // dotfiles/systemd carries the two unit FILES and nothing else, so that
    // symlink is machine-local state and flipping it cannot make the repo and
    // the machine disagree about a tracked file. Which is exactly what an
    // enablement is: this machine's answer, not the configuration's.
    //
    // --now does both halves in one call. Separately they can end up
    // disagreeing -- enabled but stopped, or the reverse -- and then "is
    // rotation on?" has two answers.
    function setRotation(on: bool): void {
        switcher.command = ["systemctl", "--user", on ? "enable" : "disable",
            "--now", "wallpaper-rotate.timer"];
        switcher.running = true;
    }

    Process {
        id: switcher

        // Whatever systemctl did or refused to do, the answer comes from
        // asking it again rather than from assuming the call worked.
        onExited: root.probeRotation()
    }

    Process {
        id: activeProbe

        command: ["systemctl", "--user", "is-active", "wallpaper-rotate.timer"]

        // Exits non-zero when the unit is not active, which is an answer and
        // not a failure -- so the exit code is ignored and the word on stdout
        // is what counts.
        stdout: StdioCollector {
            onStreamFinished: root.rotating = text.trim() === "active"
        }
    }

    // WHEN THE NEXT CHANGE IS DUE, AND NOT HOW OFTEN IT HAPPENS. The interval
    // lives in wallpaper-rotate.timer (OnActiveSec=5min, OnUnitActiveSec=30min)
    // and repeating "every 30 minutes" here would be a second copy that goes
    // stale the day the unit is edited -- in a window whose whole job is to
    // tell you what is true. systemd already folds both timers and the
    // accuracy window into one answer.
    //
    // --output=json rather than parsing the table: `next` comes back as
    // microseconds since the epoch, so there is nothing to parse and nothing
    // locale-dependent about it. The obvious alternative does not work --
    // `show -p NextElapseUSecRealtime` is EMPTY for this unit, because a
    // monotonic timer only fills NextElapseUSecMonotonic, which is measured
    // from boot and would need /proc/uptime to become a time of day.
    //
    // Measured at ~4 ms, which is why it is here at all: anything that made
    // opening the page wait would have been dropped instead.
    Process {
        id: nextProbe

        command: ["systemctl", "--user", "list-timers", "--output=json",
            "wallpaper-rotate.timer"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // An inactive timer is not listed at all, so an empty
                    // array is the normal case for rotation being off.
                    const rows = JSON.parse(text || "[]");
                    const next = rows.length > 0 ? rows[0].next : 0;
                    root.nextChange = next > 0 ? new Date(next / 1000) : null;
                } catch (e) {
                    console.warn("WallpaperPage: could not read list-timers --", e.message);
                    root.nextChange = null;
                }
            }
        }
    }

    // ---------------- The folder ----------------
    //
    // The same five extensions and the same sort as the launcher's picker,
    // which are the ones wallpaper-switch itself looks for. The path is the
    // literal one WallpaperPicker.qml uses rather than $WALLPAPER_DIR: the
    // script's variable is a per-invocation override, so reading it out of the
    // shell's own environment would only ever agree with the script by
    // accident, and two windows of this shell listing different folders is
    // worse than neither of them following the override.
    FolderListModel {
        id: folder

        folder: `file://${Quickshell.env("HOME")}/Pictures/wallpapers`
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderListModel.Name

        // The model fills asynchronously, so the current wallpaper cannot be
        // found in it until it reports a count.
        onCountChanged: Qt.callLater(root.revealCurrent)
    }

    // Scroll the applied wallpaper into view. At two columns this folder is
    // twenty-six rows deep, so the thumbnail wearing the ring is usually
    // nowhere near the top -- and a grid that opens on row one is a grid you
    // have to search to answer the question the page exists to answer.
    //
    // ONCE, AND THEN NEVER AGAIN. After the first look the scroll position
    // belongs to whoever is scrolling: taking it back on every visit would
    // undo their browsing each time they stepped off the page, and a rotation
    // firing while the window is open would yank the grid out from under the
    // pointer. The ring moving is notification enough.
    //
    // THREE THINGS HAVE TO BE TRUE and they arrive in no fixed order -- the
    // page has to be on screen, the state file has to have been read, and the
    // model has to have finished listing the folder. So all three callers just
    // call this and the guard below decides; Qt.callLater collapses the
    // duplicates and defers the call past the layout pass, without which
    // positionViewAtIndex has nothing laid out to position.
    property bool revealed: false

    function revealCurrent(): void {
        if (root.revealed || !root.visible || root.currentPath === "")
            return;

        for (let i = 0; i < folder.count; i++) {
            if (folder.get(i, "filePath") === root.currentPath) {
                // Contain and not Beginning: it leaves the view alone when the
                // thumbnail is already on screen.
                grid.positionViewAtIndex(i, GridView.Contain);
                root.revealed = true;
                return;
            }
        }
    }

    onCurrentPathChanged: Qt.callLater(root.revealCurrent)

    // ---------------- Mode ----------------
    SettingsSection {
        width: parent.width
        title: "Mode"

        ToggleRow {
            glyph: Icons.refresh
            label: "Change automatically"
            checked: root.rotating
            onToggled: value => root.setRotation(value)
        }

        Text {
            visible: text !== ""

            // Aligned with the row's LABEL is what this wants and not what it
            // gets: the label sits behind a glyph whose width is a font
            // measurement, and StepperRow's tooltip already documents why
            // measuring it with mapToItem does not work here. The section's
            // own padding is close enough and is never wrong.
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 4

            // "around", because the unit asks for AccuracySec=30s: systemd is
            // allowed to slide the moment to batch it with other timers, and a
            // page that prints an exact minute is claiming a precision the
            // timer explicitly gave up.
            //
            // The clock format follows the bar's. A settings window showing
            // 22:33 while the bar shows 10:33 PM is two clocks on one desktop.
            text: {
                if (!root.rotating || !root.nextChange)
                    return "";
                const format = Config.use24Hour ? "HH:mm" : "h:mm AP";
                return `Next change around ${Qt.formatDateTime(root.nextChange, format)}.`;
            }

            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- Wallpaper ----------------
    SettingsSection {
        width: parent.width
        title: "Wallpaper"

        // The name of what is applied, spelled out. The ring in the grid says
        // the same thing better, but only while the thumbnail it is on is
        // scrolled into view -- and there are fifty of them.
        Item {
            id: actions

            width: parent.width
            height: Theme.groupHeight - 6

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.groupPadding
                anchors.right: randomButton.left
                anchors.rightMargin: Theme.itemSpacing
                anchors.verticalCenter: parent.verticalCenter

                text: root.currentName !== "" ? root.currentName : "Nothing applied yet"
                elide: Text.ElideRight

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                font.weight: Font.Bold
                color: root.currentName !== "" ? Theme.textOnSurface : Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // NOT a ConfirmButton. That component is for the click you should
            // not be able to take by accident, and this one is undone by
            // clicking any thumbnail below -- arming it would be ceremony
            // around a change that costs a second to reverse.
            Rectangle {
                id: randomButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.groupPadding - 4
                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: randomLabel.implicitWidth + randomGlyph.implicitWidth
                    + Theme.itemSpacing + Theme.groupPadding * 2
                implicitHeight: Theme.groupHeight - 6
                radius: height / 2

                color: randomMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                border.width: 1
                border.color: Theme.outlineVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.itemSpacing

                    Text {
                        id: randomGlyph

                        anchors.verticalCenter: parent.verticalCenter
                        text: Icons.shuffle
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.iconSize
                        color: Theme.textOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }

                    Text {
                        id: randomLabel

                        anchors.verticalCenter: parent.verticalCenter
                        text: "Random now"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize - 1
                        font.weight: Theme.fontWeight
                        color: Theme.textOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }
                }

                MouseArea {
                    id: randomMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // `random` and not a random index picked here: the script
                    // refuses to hand back the one that is already applied,
                    // and a button that sometimes appears to do nothing is a
                    // button people press twice.
                    onClicked: Quickshell.execDetached(["wallpaper-switch", "random"])
                }
            }
        }

        // The folder is missing or holds nothing this shell can draw. Says
        // where it looked, because that is the only thing anyone can act on.
        Text {
            visible: folder.count === 0

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: "No images in ~/Pictures/wallpapers."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // A GRID AND NOT THE LAUNCHER'S STRIP. The strip is walked with two
        // keys and shows three images at a time, which is right for a thing
        // that closes as soon as you pick. Here the question is "which of
        // these fifty is on my desktop", and answering it in a strip means
        // scrolling past forty-nine.
        //
        // THE COLUMN COUNT IS COMPUTED, not fixed. This pane is about 425 px
        // wide in the default window and the window is resizable, so a fixed
        // cellWidth would leave a ragged gap down the right at every other
        // size -- or, worse, force the window wider. Cells divide whatever
        // width there is, and widening the window buys columns rather than
        // bigger thumbnails: this grid's job is to show more of the folder at
        // once.
        //
        // The floor of two columns is what keeps a narrow window from turning
        // the grid back into the strip it exists not to be.
        GridView {
            id: grid

            readonly property int gutter: 6
            // Below about this the file name under a thumbnail elides to
            // nothing useful and the picture stops being recognisable, which
            // is the entire point of a thumbnail.
            readonly property int minCellWidth: 150

            readonly property int columns: Math.max(2, Math.floor(width / minCellWidth))
            readonly property int rows: Math.ceil(folder.count / columns)
            readonly property int labelHeight: 22

            width: parent.width

            // A CEILING, and it is where this page spends its height. 280 is
            // about two rows at the default width, which puts the whole page a
            // little taller than a 380 px window -- so the window's own
            // Flickable scrolls. That is the trade taken on purpose: a ceiling
            // low enough to fit everything without scrolling shows a row and a
            // half, and a grid you cannot see two rows of is a strip with
            // extra steps.
            //
            // The partial row at the bottom is deliberate too. A grid cut
            // exactly on a row boundary looks like the end of the folder.
            height: Math.min(rows * cellHeight, 280)
            visible: height > 0

            cellWidth: Math.floor(width / columns)
            cellHeight: Math.round((cellWidth - gutter) * 9 / 16) + gutter + labelHeight

            model: folder
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // KNOWN COST, do not rediscover it: this is a scrollable thing
            // inside another scrollable thing, and the inner one keeps the
            // wheel. With the pointer over the grid, scrolling past the last
            // row does not fall through to the page. The alternative is an
            // unbounded grid -- twenty-six rows, some 3700 px of it -- which
            // would turn the page into one long scroll where the switch above
            // is the only thing you ever see.

            // The model is used directly rather than copied into an array the
            // way WallpaperPicker.qml does. That copy exists there to be
            // filtered by the launcher's search box; there is no search box
            // here, so the copy would be a second list to keep in step with
            // the folder for no gain.
            delegate: Item {
                id: cell

                required property string filePath
                required property string fileName

                readonly property bool current: cell.filePath === root.currentPath

                width: grid.cellWidth
                height: grid.cellHeight

                Item {
                    id: frame

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: grid.gutter / 2
                    width: grid.cellWidth - grid.gutter
                    height: Math.round(width * 9 / 16)

                    // Tighter than the launcher strip's cardRadius - 8, and
                    // for a reason that does not apply there: those thumbnails
                    // are always 190 px wide, these are whatever the column
                    // count leaves them. At four columns a cell is about a
                    // hundred pixels across and a 16 px corner turns it into a
                    // lozenge.
                    readonly property int radius: Theme.cardRadius - 12

                    // THE IMAGE HAS TO BE MASKED, not merely put inside a
                    // rounded rectangle -- an Image is a rectangle and keeps
                    // its own square corners, and `clip` clips to the bounding
                    // rect rather than to the curve. The whole arrangement
                    // below, threshold and spread included, is copied from
                    // modules/launcher/WallpaperPicker.qml, which took it from
                    // components/CornerWedge.qml. Without those two numbers
                    // MultiEffect cuts the mask at a hard step and throws away
                    // its antialiasing.
                    Image {
                        id: picture

                        anchors.fill: parent
                        source: `file://${cell.filePath}`
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true

                        // Decoded at the size it is drawn at: these are 4K
                        // wallpapers and a grid holds a lot more of them at
                        // once than a strip does.
                        //
                        // Rounded UP to the next 32 px rather than tracking
                        // the cell exactly. The cell width is a binding on the
                        // window's width, so an exact sourceSize would re-
                        // decode every visible image on every pixel of a drag
                        // of the window edge. In 32 px steps a resize costs a
                        // handful of decodes instead of hundreds, and nothing
                        // on screen can tell the difference.
                        sourceSize.width: Math.ceil(frame.width / 32) * 32
                        sourceSize.height: Math.ceil(frame.height / 32) * 32

                        visible: false
                        layer.enabled: true
                    }

                    Rectangle {
                        id: pictureMask

                        anchors.fill: parent
                        radius: frame.radius
                        antialiasing: true
                        color: "black"

                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: picture
                        maskEnabled: true
                        maskSource: pictureMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    // THE RING IS THE ANSWER THIS PAGE IS FOR. Drawn over the
                    // masked image and at the same radius, so it sits exactly
                    // on the cut edge.
                    //
                    // One rectangle for two states, because they cannot both
                    // be true of the same thumbnail in a way worth drawing
                    // twice: hover is a thin neutral edge that says "this is
                    // clickable", applied is a thick accent one that says
                    // "this is the one". Tinting the picture instead would be
                    // fighting the picture, which is the argument the
                    // launcher's strip already makes.
                    Rectangle {
                        anchors.fill: parent
                        radius: frame.radius
                        color: "transparent"
                        antialiasing: true

                        border.width: cell.current ? 3 : (cellMouse.containsMouse ? 1 : 0)
                        border.color: cell.current ? Theme.primary : Theme.outline

                        Behavior on border.width {
                            NumberAnimation { duration: Theme.animDuration }
                        }

                        Behavior on border.color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: grid.gutter / 2
                    anchors.rightMargin: grid.gutter / 2
                    horizontalAlignment: Text.AlignHCenter

                    // Without the extension: it is noise, and the name is only
                    // here to tell two similar images apart.
                    text: cell.fileName.replace(/\.[^.]+$/, "")
                    elide: Text.ElideRight

                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                    font.weight: cell.current ? Font.Bold : Theme.fontWeight
                    color: cell.current ? Theme.textOnSurface : Theme.textOnSurfaceVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }

                MouseArea {
                    id: cellMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    // Clicking the applied one is not a no-op on purpose: it
                    // reapplies, which regenerates the palette from the same
                    // image. That is the way back when a matugen template has
                    // been edited, and it is what `wallpaper-switch reapply`
                    // is for -- there is no reason to make the grid refuse it.
                    onClicked: Quickshell.execDetached(["wallpaper-switch", "set", cell.filePath])
                }
            }
        }
    }
}
