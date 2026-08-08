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
// NOTHING ON THIS PAGE IS STORED IN Config. Every fact it shows already has
// an owner outside the shell -- two state files written by the script, and a
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
    // remembering that the desktop changes on its own. "directory" is here for
    // the same reason: the footer below says "folder".
    keywords: ["wallpaper", "background", "rotation", "timer", "random",
        "shuffle", "image", "folder", "directory", "collection"]

    // NOT IN Icons.qml, and not because it does not belong there -- that file
    // is off limits to this change. It was read out of the installed font's
    // cmap rather than off the Nerd Fonts chart, which is the rule Icons.qml
    // itself spells out after three glyphs turned out to draw a music box, a
    // shield and a bluetooth speaker:
    //
    //   python -c "from fontTools.ttLib import TTFont; \
    //     print(TTFont('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf') \
    //       .getBestCmap()[0xF024F])"
    //
    // 0xF024F answers md-folder_image.
    //
    // ITS COMPANION 0xF0770 (md-folder_open) WAS DELETED WITH THE PILL IT SAT
    // IN. The footer's action is a bare word now; a glyph at both ends of one
    // muted line is the kind of furniture this page was carrying too much of.
    readonly property string folderGlyph: String.fromCodePoint(0xF024F)

    // ---------------- What is applied right now ----------------
    //
    // IT IS A READING, NOT A CONTROL. The ring in the grid follows this
    // property, this property follows the state file, and the state file is
    // written by wallpaper-switch after awww has accepted the image. So the
    // ring lands on a thumbnail about a second and a half after it is clicked
    // -- the length of the crossfade -- and does not move at all if the script
    // fails. Moving it on click instead would be quicker and would be a lie in
    // exactly the case where the truth matters.
    // THE PATH AND NOT A NAME DERIVED FROM IT. There used to be a currentName
    // here, spelled out in bold at the top of the card, and it was saying a
    // second time what the ring in the grid says better: the ring is ON the
    // picture, and revealCurrent below scrolls it into view on the first
    // visit, so the name only ever restated a thing already on screen.
    readonly property string currentPath: stateFile.text().trim()

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

    // ---------------- How often ----------------
    //
    // The values worth offering, in minutes. Not a range: see the note on the
    // stepper that walks them.
    readonly property var intervals: [5, 10, 15, 30, 45, 60, 90, 120, 180, 360, 720, 1440]

    // THE NEAREST ONE, not an exact match. `wallpaper-interval` accepts any
    // number of minutes between 5 and 10080, so a value typed into a terminal
    // -- or left over from a version of this list that had different entries
    // -- has no index of its own. Snapping to the closest keeps the stepper on
    // a real position instead of collapsing to the first one.
    readonly property int intervalIndex: {
        let best = 0;
        let distance = Infinity;

        for (let i = 0; i < root.intervals.length; i++) {
            const gap = Math.abs(root.intervals[i] - Config.wallpaperInterval);
            if (gap < distance) {
                distance = gap;
                best = i;
            }
        }

        return best;
    }

    // Minutes below an hour, hours above it, and a day at the top. "1440 min"
    // is arithmetic somebody has to do; "1 day" is the thing they meant.
    function intervalLabel(minutes: int): string {
        if (minutes < 60)
            return `${minutes} min`;
        if (minutes === 1440)
            return "1 day";

        const hours = Math.floor(minutes / 60);
        const rest = minutes % 60;
        return rest === 0 ? `${hours} h` : `${hours} h ${rest}`;
    }

    // ---------------- The folder ----------------
    //
    // WHERE THE COLLECTION LIVES IS NOT THIS FILE'S TO DECIDE. It used to be:
    // ~/Pictures/wallpapers was written out literally here, and moving the
    // collection meant editing the shell as well as the script -- until both
    // were edited, this grid listed one folder while the keybinds cycled
    // another and said nothing about it. wallpaper-switch now keeps the answer
    // in a state file, and this page reads that file exactly the way it
    // already reads which wallpaper is applied.
    //
    // STILL OUTSTANDING, so it is not rediscovered as a bug in this page:
    // modules/launcher/WallpaperPicker.qml and the entry in Commands.qml carry
    // their own literal ~/Pictures/wallpapers. Point the collection somewhere
    // else and the settings grid follows while the launcher's strip does not.
    // The fix there is these same six lines; it was out of scope for the
    // change that added them.
    //
    // NOT $WALLPAPER_DIR, and that is a decision rather than an omission. The
    // script's variable is a per-invocation override -- the point of
    // `WALLPAPER_DIR=/tmp/x wallpaper-switch next` is that it changes ONE run
    // -- so it never described the collection in the first place. And a
    // process inherits its environment at launch: this shell started before
    // any such variable existed and would carry whatever it had then until the
    // next restart, so the grid could sit on a folder that no keybind, no
    // timer and no terminal agrees with, with nothing on screen to explain the
    // disagreement.
    //
    // XDG_STATE_HOME is the opposite case and is honoured. It is a property of
    // the session, set once at login and read identically by every process in
    // it, so the script and this page cannot end up pointing at different
    // files because of it. Set to ~/.local/state here, which is also the
    // fallback, so this costs nothing today and is right if it ever moves.
    // THE FOLDER COMES FROM Config, not from a FileView of this page's own.
    // It had one, watching the same ~/.local/state/wallpaper-dir the launcher
    // would have needed to watch as well -- two readers of one file, and the
    // launcher's strip did not have one at all, so pointing the collection
    // elsewhere moved this grid and left that strip on the old folder. One
    // property in Config is what makes the two views the same view.
    readonly property string folderPath: Config.wallpaperDir

    // For reading, never for passing to anything: ~ is a shell expansion and
    // means a directory literally called "~" to FolderListModel and to find,
    // which is the trap wallpaper-switch expands it away for.
    readonly property string folderLabel: {
        const home = Quickshell.env("HOME");
        if (root.folderPath === home)
            return "~";
        return root.folderPath.startsWith(`${home}/`)
            ? `~${root.folderPath.slice(home.length)}`
            : root.folderPath;
    }

    // A Process where everything else on this page uses execDetached, and the
    // exit code is not the reason. The footer's "Change" has to go quiet while
    // the chooser is on screen, and `running` is the only thing that knows the
    // dialog is still open -- detached, a second click opens a second zenity,
    // and then two dialogs are racing to write the same state file.
    //
    // Deliberately no onExited handler. Config.wallpaperDir is what moves the grid,
    // and it fires when the folder actually changed rather than when the
    // script happened to finish -- which is also the right answer for a
    // cancelled dialog, where the script exits 0 having changed nothing.
    Process {
        id: picker

        command: ["wallpaper-switch", "dir", "pick"]
    }

    // The same extensions and the same sort as the launcher's picker. Both
    // read the list off Config now rather than spelling it out, which is what
    // stops this grid and that strip from disagreeing about what counts as a
    // wallpaper.
    FolderListModel {
        id: folder

        folder: `file://${root.folderPath}`
        nameFilters: Config.wallpaperNameFilters
        showDirs: false
        sortField: FolderListModel.Name

        // The model fills asynchronously, so the current wallpaper cannot be
        // found in it until it reports a count.
        //
        // Also where a video added to the folder mid-session gets its frame
        // extracted -- see the note on refreshWallpaperThumbs.
        onCountChanged: {
            Qt.callLater(root.revealCurrent);
            Config.refreshWallpaperThumbs();
        }
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

        // A STEPPER OVER A LIST AND NOT OVER MINUTES. The useful intervals are
        // not evenly spaced -- the difference between 5 and 10 minutes is a
        // different desktop, the difference between 700 and 705 is nothing --
        // so stepping in minutes would be a control you hold down for a
        // minute and a half to get from half an hour to a day. The stepper
        // walks the list; `display` is what the note in StepperRow.qml calls a
        // value that is not read as a number.
        //
        // Dimmed while rotation is off. The interval is still stored and still
        // applies the moment it goes back on, but a frequency for something
        // that is not happening is a number with nothing to be true about.
        StepperRow {
            glyph: Icons.clock
            label: "Change every"
            enabled: root.rotating

            value: root.intervalIndex
            from: 0
            to: root.intervals.length - 1
            step: 1
            display: root.intervalLabel(root.intervals[root.intervalIndex])

            onMoved: index => Config.setWallpaperInterval(root.intervals[index])

            hint: "Every change regenerates the whole palette with matugen — "
                + "ten template renders and a reload in four applications — "
                + "which is why the shortest offered is five minutes."
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
    //
    // HEADING, GRID, ONE FOOTER LINE -- AND NOTHING ELSE. What this replaced
    // was three horizontal bands stacked before a single picture appeared: a
    // header row inside the card carrying the applied wallpaper's name in bold
    // with a "Random now" pill on its right, then a full ActionRow reading
    // "Wallpaper folder / ~/Pictures/Wallpapers" with a "Change" pill, and only
    // then the thumbnails. Two label-plus-button rows in a row -- 30 px of
    // header plus a 45 px ActionRow plus the spacing between them, near enough
    // 80 px of chrome to walk past before a section whose entire content is
    // pictures.
    //
    // Each band was wrong in its own way:
    //
    //   - The NAME was a second answer to a question already answered better.
    //     The ring in the grid is on the picture; revealCurrent scrolls it into
    //     view on first visit. See the note on currentPath above.
    //   - RANDOM is an action on the whole section, not a setting, so it
    //     belongs to the heading -- see SettingsSection's own note. The heading
    //     line already existed with nothing on its right, so it now costs zero
    //     vertical space where it used to cost a full row.
    //   - The FOLDER row looked like a setting and was not one. It is the scope
    //     of the pictures, which makes it a caption, and a caption goes under
    //     the thing it captions.
    SettingsSection {
        width: parent.width
        title: "Wallpaper"

        // NOT a ConfirmButton, wherever it lives. That component is for the
        // click you should not be able to take by accident, and this one is
        // undone by clicking any thumbnail below -- arming it would be
        // ceremony around a change that costs a second to reverse.
        actionText: "Random"
        actionGlyph: Icons.shuffle

        // `random` and not a random index picked here: the script refuses to
        // hand back the one that is already applied, and a button that
        // sometimes appears to do nothing is a button people press twice.
        onActionTriggered: Quickshell.execDetached(["wallpaper-switch", "random"])

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

                        // For a still this is the wallpaper itself; for a
                        // video it is the frame wallpaper-switch extracted,
                        // since an Image cannot decode an mp4.
                        //
                        // The bare reference to the revision is not dead code:
                        // it is what puts this binding on the list of things
                        // to re-evaluate once the extraction finishes. A video
                        // added to the folder is listed here before ffmpeg has
                        // pulled a frame out of it, and a plain function call
                        // would never be asked again.
                        source: {
                            Config.wallpaperThumbsRevision;
                            return Config.wallpaperThumbUrl(cell.filePath);
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true

                        // Qt caches the fact that a URL failed to load. The
                        // re-evaluation above would otherwise be handed that
                        // same failure instead of going back to disk.
                        cache: false

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

        // ---------------- Where the pictures come from ----------------
        //
        // A FOOTER, WHICH IS A SENTENCE ABOUT THE GRID AND NOT A SETTING. It
        // reads as a caption because it is one -- "these fifty-two pictures,
        // and they live here" -- and captions go under. The whole line stays
        // at textOnSurfaceVariant and a point down, with one exception: the
        // chip at its right end, which is the only thing here you can press
        // and is drawn as such rather than waiting for a hover to admit it.
        //
        // A HAIRLINE AND NOT JUST AIR, which was the other option and reads
        // worse HERE specifically: the grid deliberately cuts its last row
        // mid-picture (see its height cap), so its bottom edge is a torn
        // photograph, not a clean boundary. Muted text floating under a torn
        // edge with only whitespace between them looks like a caption ON that
        // half-thumbnail. The rule gives the grid a definite floor. It is
        // hidden when there is no grid, since a rule under nothing is a lid.
        Item {
            id: footer

            readonly property int lineHeight: Theme.groupHeight - 12

            width: parent.width
            // Air above the rule as well as below it. The card's Column only
            // puts 2 px between its children, and a rule 2 px under a row of
            // cropped photographs reads as part of the photographs.
            implicitHeight: footer.lineHeight + Theme.itemSpacing * 2

            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: Theme.itemSpacing - 2
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.groupPadding
                anchors.rightMargin: Theme.groupPadding

                visible: grid.visible
                height: 1
                color: Theme.outlineVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                id: originGlyph

                anchors.left: parent.left
                anchors.leftMargin: Theme.groupPadding
                anchors.verticalCenter: originText.verticalCenter

                text: root.folderGlyph
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize - 2
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            Text {
                id: originText

                anchors.left: originGlyph.right
                anchors.leftMargin: Theme.itemSpacing - 3
                anchors.right: change.left
                anchors.rightMargin: Theme.itemSpacing
                anchors.verticalCenter: change.verticalCenter

                // THE COUNT REPLACES THE OLD "No images in ~/Pictures/x." LINE.
                // Nothing else on this desktop prints this path, so the line
                // still has to name the folder it looked in -- but "0 images"
                // is a complete answer to the empty case, and when the count is
                // zero the grid collapses to nothing and this line becomes the
                // entire card, so it cannot be walked past. A second widget
                // that only ever appears to say what this one already says was
                // the kind of stacking this redesign was about.
                text: `${root.folderLabel} · ${folder.count} ${folder.count === 1 ? "image" : "images"}`

                // MIDDLE and not Right: the count is at the END of the string,
                // and eliding right drops it first -- the one part of this line
                // that cannot be guessed from anywhere else in the window. The
                // middle of a long path is the cheapest thing to lose.
                elide: Text.ElideMiddle

                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.textOnSurfaceVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // THE SAME CHIP AS "Random" IN THE HEADING ABOVE, deliberately, and
            // it is the second attempt: this was a bare hover-coloured word,
            // on the argument that a border would put back the weight the
            // deleted row was carrying. That argument was about the ROW -- a
            // full-width bordered strip -- and it does not reach a chip the
            // size of the word inside it, which costs no vertical space at all.
            //
            // What it cost instead was the only thing a control has to get
            // right: a word that is only a word until you happen to hover it
            // does not read as pressable, and nothing else on the line is. So
            // it takes the window's one shape for a small action -- hairline
            // border, pill radius, fill on hover -- which is already on this
            // page eighteen rows up. One shape to learn, not two.
            Rectangle {
                id: change

                anchors.right: parent.right
                anchors.rightMargin: Theme.groupPadding
                anchors.bottom: parent.bottom

                // WIDE ENOUGH FOR THE LONGER OF THE TWO WORDS, always, so
                // pressing it does not resize it. The chip is right-anchored:
                // growing means it eats leftwards into the path beside it and
                // re-elides that line, all at the instant of the click, which
                // is exactly when the eye is on it.
                width: Math.max(idleMetrics.width, busyMetrics.width)
                    + Theme.groupPadding * 1.6
                height: footer.lineHeight
                radius: height / 2

                color: changeMouse.containsMouse && !picker.running
                    ? Theme.surfaceContainerHigh : "transparent"
                border.width: 1
                border.color: Theme.outlineVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }

                TextMetrics {
                    id: idleMetrics

                    font: changeLabel.font
                    text: "Change"
                }

                TextMetrics {
                    id: busyMetrics

                    font: changeLabel.font
                    text: "Choosing…"
                }

                Text {
                    id: changeLabel

                    anchors.centerIn: parent

                    // The word changes while zenity is up, because `picker` is
                    // a Process precisely so this line knows the dialog is
                    // still open -- see its declaration above.
                    text: picker.running ? busyMetrics.text : idleMetrics.text

                    // A POINT DOWN AND NOT TWO, unlike the heading's chip. That
                    // one sits beside a bold heading at full size and needs the
                    // step; this one sits beside the caption, which is already
                    // a point down, and matching it keeps the line one line.
                    // The border is what makes both of them buttons, not the
                    // type size.
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize - 1
                    font.weight: Theme.fontWeight
                    color: !picker.running && changeMouse.containsMouse
                        ? Theme.primary : Theme.textOnSurfaceVariant
                    opacity: picker.running ? 0.5 : 1

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                MouseArea {
                    id: changeMouse

                    // The chip is the target now, so it fills it exactly. The
                    // old version grew the hit area 6 px past a bare word,
                    // because there was nothing drawn to aim at.
                    anchors.fill: parent

                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !picker.running

                    // The dialog belongs to the script, not to this window.
                    // Same argument the avatar row makes: a shell that grows
                    // its own file browser has to maintain a file browser, and
                    // this one gets GTK's for the price of a Process.
                    onClicked: picker.running = true
                }
            }
        }
    }
}
