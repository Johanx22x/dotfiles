// The wallpaper page: which image is on the desktop, and whether it changes
// by itself.
//
// WHAT THIS PAGE IS NOT IS A PICKER. It carried a grid of thumbnails once,
// and choosing from it meant judging a 4K photograph at a hundred pixels
// across in a pane the width of a sidebar. Picking happens in the carousel
// now -- SUPER + SHIFT + W, modules/wallpaper -- and what is left here is
// everything AROUND the collection: where it lives, how often it changes by
// itself, and the name of the one currently on the desktop.
//
// EVERYTHING HERE GOES THROUGH wallpaper-switch, the same script the keybind
// and the rotation timer use: it is what sets the image AND regenerates the
// palette AND pushes the new accent into the compositor. Calling awww from
// here would change the picture and leave the rest of the desktop on the
// previous colours -- including this window, which is painted out of Theme.
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
import "root:/"
import "root:/components"
// WallpaperState, which the Browse button opens. A singleton is not in scope
// just because it is one -- its directory has to be imported.
import "root:/modules/wallpaper"
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
    // IT IS A READING, NOT A CONTROL. The row below follows this property,
    // this property follows the state file, and the state file is written by
    // wallpaper-switch after the backend has accepted the image. So the name
    // changes about a second and a half after the click -- the length of the
    // crossfade -- and does not change at all if the script failed. Moving it
    // on click instead would be quicker and would be a lie in exactly the case
    // where the truth matters.
    //
    // THE PATH AND NOT THE NAME, with the trimming left to the row that shows
    // it: the path is what the state file holds and what a comparison against
    // the collection needs.
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
            // next elapse moved with it. Harmless when the change came from
            // the carousel -- the schedule did not move -- and telling the two
            // cases apart is not worth more than the 4 ms this costs.
            root.probeRotation();
        }
        // A machine that has never changed its wallpaper has no state file.
        // That is a first run, not an error to print on every launch.
        printErrors: false
    }

    // ---------------- Rotation ----------------
    //
    // THE SWITCH IS A READING OF THE SETTING TOO. It shows what
    // `wallpaper-interval show` says, not what was clicked: the click starts a
    // process, the process finishes, and only then is the state re-read. A few
    // milliseconds, invisible in use, and it means a call that did not work
    // leaves the switch where it was instead of showing an "on" that nothing
    // on the system agrees with.
    property bool rotating: false

    // A Date, or null when systemd has no next elapse for the unit.
    property var nextChange: null

    function probeRotation(): void {
        modeProbe.running = true;
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
    }

    Component.onCompleted: {
        if (root.visible)
            root.probeRotation();
    }

    // THIS SWITCH USED TO CALL `systemctl --user disable --now`, AND THAT
    // DELETED THE UNIT FILE. Not the enablement symlink -- the unit.
    //
    // The reasoning it replaced was that an enablement is machine-local state,
    // that dotfiles/systemd carries only the unit FILES, and that flipping it
    // therefore "cannot make the repo and the machine disagree about a tracked
    // file". Every clause of that is true and the conclusion is still wrong,
    // because of where stow puts the file. It links it into
    // ~/.config/systemd/user/, which is not merely a directory systemd reads:
    // it is THE unit configuration directory, so the unit counts as linked --
    //
    //   $ systemctl --user is-enabled wallpaper-rotate.service
    //   linked
    //
    // -- and `man systemctl` says of disable that it "removes all symlinks to
    // the unit files backing the specified units from the unit configuration
    // directory ... including manually created symlinks, and not just those
    // actually created by enable or link". stow's symlink is a manually
    // created symlink to a matching unit file, so disable took it with the
    // enablement. The unit then reported not-found, this switch could never
    // turn it back on, and `install.sh check` began listing the file as not
    // linked. It happened three times in one day.
    //
    // SO NOTHING HERE TOUCHES UNIT STATE AT ALL NOW. Both directions go
    // through `wallpaper-interval`, which owns the drop-in at
    // ~/.config/systemd/user/wallpaper-rotate.timer.d/interval.conf and
    // nothing else; the script's own header carries the systemd evidence. Off
    // is a schedule the timer can never reach, on is an interval, and the
    // enablement is left to whoever set it -- the installer's services-user
    // unit -- exactly as it was before anyone clicked anything.
    //
    // IT STILL SURVIVES A REBOOT, and by a plainer route than before: the
    // setting is a FILE. ~/.config/systemd/user/wallpaper-rotate.timer.d/
    // interval.conf is read by systemd on every start of the user manager, so
    // an off written today is still off after a reboot without anything having
    // to remember it. That is strictly more durable than the old enablement
    // symlink, which lived in the same place but could be removed by any
    // `disable` of the unit, deliberate or otherwise.
    //
    // TURNING IT ON SENDS THE INTERVAL AND NOT A WORD LIKE "on", because
    // `wallpaper-interval` has no `on`: setting an interval is what turns
    // rotation on. Config.wallpaperInterval is the one the stepper is showing,
    // read back out of the state file the script writes, so the value the row
    // above has been displaying while greyed out is the value that takes
    // effect.
    function setRotation(on: bool): void {
        switcher.command = ["wallpaper-interval",
            on ? String(Config.wallpaperInterval) : "off"];
        switcher.running = true;
    }

    Process {
        id: switcher

        // Whatever the script did or refused to do, the answer comes from
        // asking it again rather than from assuming the call worked.
        onExited: root.probeRotation()
    }

    // ASKING THE SCRIPT AND NOT systemd, and that is forced rather than
    // preferred. `systemctl --user is-active wallpaper-rotate.timer` used to be
    // the reading here, and under the drop-in scheme it answers `active` in
    // BOTH states: an off timer is a healthy enabled timer whose next elapse is
    // never, so it sits in SubState=elapsed and is-active still says active.
    // The only thing that can tell the two apart is the drop-in, and
    // `wallpaper-interval show` is the reader for it -- it prints `off`, or the
    // interval in minutes.
    //
    // The trade-off being accepted: this now reports the SETTING rather than
    // the running state, so a machine where the timer was never enabled shows
    // the switch on while nothing rotates. That is the installer's question,
    // `install.sh check` already asks it, and the alternative -- a switch that
    // refuses to move because of something no text on this page mentions -- is
    // the worse of the two.
    Process {
        id: modeProbe

        command: ["wallpaper-interval", "show"]

        stdout: StdioCollector {
            onStreamFinished: root.rotating = text.trim() !== "off"
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
                    // TWO SHAPES MEAN "NO NEXT CHANGE", not one. A timer that
                    // is not running is not listed at all, so an empty array
                    // is still possible; but an off timer under the drop-in
                    // scheme IS listed, active, with `next` and `left` both
                    // JSON null. Verified on a scratch copy of the unit:
                    //
                    //   [{"next":null,"left":null,"last":0,"passed":0, ...}]
                    //
                    // `null > 0` is false in JavaScript, so the same
                    // comparison covers both without a second branch.
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
    // were edited, this page named one folder while the keybind cycled another
    // and said nothing about it. wallpaper-switch keeps the answer in a state
    // file now, and Config is what reads it.
    //
    // THE FOLDER COMES FROM Config, not from a FileView of this page's own. It
    // had one, watching the same ~/.local/state/wallpaper-dir the carousel
    // would then need to watch as well -- two readers of one file, and the
    // second reader is the one that ends up on the old folder. One property in
    // Config is what makes every view of the collection the same view.
    //
    // NOT $WALLPAPER_DIR, and that is a decision rather than an omission. The
    // script's variable is a per-invocation override -- the point of
    // `WALLPAPER_DIR=/tmp/x wallpaper-switch next` is that it changes ONE run
    // -- so it never described the collection in the first place. And a
    // process inherits its environment at launch: this shell started before
    // any such variable existed and would carry whatever it had then until the
    // next restart, so this page could name a folder that no keybind, no timer
    // and no terminal agrees with, with nothing on screen to explain the
    // disagreement.
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
    // Deliberately no onExited handler. Config.wallpaperDir is what moves the
    // count and the carousel alike, and it fires when the folder actually
    // changed rather than when the script happened to finish -- which is also
    // the right answer for a cancelled dialog, where the script exits 0 having
    // changed nothing.
    Process {
        id: picker

        command: ["wallpaper-switch", "dir", "pick"]
    }

    // ONLY THE COUNT IS DRAWN FROM THIS, in the footer at the bottom of the
    // page -- the pictures themselves are the carousel's business now. It is
    // still a FolderListModel and not a `find | wc -l` for the same reason it
    // always was: Quickshell has no directory API, and Qt already has one.
    //
    // The extensions and the sort come off Config, which is where the carousel
    // reads them too: one answer to what counts as a wallpaper, so the count
    // here cannot disagree with the number of cards over there.
    FolderListModel {
        id: folder

        folder: `file://${root.folderPath}`
        nameFilters: Config.wallpaperNameFilters
        showDirs: false
        sortField: FolderListModel.Name

        // Where a video added to the folder mid-session gets its frame
        // extracted -- see the note on refreshWallpaperThumbs. The count is
        // the moment we learn the file is there, and the carousel needs the
        // frame before it can draw a card for it.
        onCountChanged: Config.refreshWallpaperThumbs()
    }

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

        SectionNote {
            visible: text !== ""

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
        }
    }

    // ---------------- Wallpaper ----------------
    //
    // HEADING, ONE ROW, ONE FOOTER LINE -- AND NOTHING ELSE. Two things have
    // been taken out of this card over time and both went for the same reason,
    // so it is worth keeping the reasoning where the next addition will be
    // read:
    //
    //   - RANDOM is an action on the whole section, not a setting, so it
    //     belongs to the heading -- see SettingsSection's own note. The heading
    //     line already existed with nothing on its right, so it costs zero
    //     vertical space where it used to cost a full row.
    //   - The FOLDER row looked like a setting and was not one. It is the scope
    //     of the collection, which makes it a caption, and a caption goes under
    //     the thing it captions.
    //
    // What is left is the one thing a settings window is the right place for:
    // the name of the wallpaper on the desktop, and the way to the surface
    // where a different one is chosen.
    SettingsSection {
        width: parent.width
        title: "Wallpaper"

        // NOT a ConfirmButton, wherever it lives. That component is for the
        // click you should not be able to take by accident, and this one is
        // undone by browsing to the picture you had -- arming it would be
        // ceremony around a change that costs a second to reverse.
        actionText: "Random"
        actionGlyph: Icons.shuffle

        // `random` and not a random index picked here: the script refuses to
        // hand back the one that is already applied, and a button that
        // sometimes appears to do nothing is a button people press twice.
        onActionTriggered: Quickshell.execDetached(["wallpaper-switch", "random"])

        // WHAT USED TO BE HERE WAS A GRID OF THUMBNAILS, and it was the
        // second picker in a window that now has none. Choosing a wallpaper
        // happens in one place -- the fullscreen carousel, SUPER + SHIFT + W
        // -- and this page is what it always claimed to be: the settings
        // around the collection. Where it lives, how often it changes by
        // itself, and which one is on the desktop.
        //
        // The grid cost about 280 px of pictures the size of a postage stamp,
        // shown at a fifth of the size of the thing they were previews of, in
        // a pane 425 px wide. The carousel draws one card at a third of the
        // screen. Two answers to one question, and the worse one was the one
        // in the way.
        //
        // THE NAME IS A READING AND THE BUTTON IS THE ACTION, which is exactly
        // what ActionRow is for. The ring on a thumbnail used to say which
        // wallpaper was applied; with no thumbnails left, the name has to say
        // it -- and it is read off the same state file the ring followed.
        ActionRow {
            glyph: Icons.image
            label: "Current"

            // The file name without its extension, which is how every other
            // surface in this shell names a wallpaper. The path itself would
            // be a line of ~/Pictures/wallpapers repeated from the footer two
            // rows down.
            description: {
                if (root.currentPath === "")
                    return "None applied yet";

                return root.currentPath.split("/").pop().replace(/\.[^.]+$/, "");
            }

            // "Browse" and not "Change": the button opens something to look
            // at, and what you do next in there is up to you -- Escape leaves
            // the desktop exactly as it was.
            actionText: "Browse"

            // The window STAYS OPEN behind the carousel. It is an ordinary
            // window and the carousel is a layer surface that covers the
            // screen and takes the keyboard, so it is hidden rather than
            // interfered with, and closing the carousel gives it back.
            onTriggered: WallpaperState.open()
        }

        // ---------------- Where the pictures come from ----------------
        //
        // A FOOTER, WHICH IS A SENTENCE ABOUT THE SECTION AND NOT A SETTING.
        // It reads as a caption because it is one -- "there are fifty-two of
        // them and they live here" -- and captions go under. The whole line
        // stays at textOnSurfaceVariant and a point down, with one exception:
        // the chip at its right end, which is the only thing here you can press
        // and is drawn as such rather than waiting for a hover to admit it.
        //
        // A HAIRLINE AND NOT JUST AIR. The line above it is a row like any
        // other in this window -- label, reading, button -- and muted text
        // floating under one of those with only whitespace between reads as a
        // second line of that row rather than as a caption on the card. The
        // rule is what says the caption belongs to the section and not to the
        // row it sits under.
        Item {
            id: footer

            readonly property int lineHeight: Theme.groupHeight - 12

            width: parent.width
            // Air above the rule as well as below it. The card's Column only
            // puts 2 px between its children, and a rule 2 px under the row
            // above reads as part of that row.
            implicitHeight: footer.lineHeight + Theme.itemSpacing * 2

            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: Theme.itemSpacing - 2
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.groupPadding
                anchors.rightMargin: Theme.groupPadding

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
                // is a complete answer to the empty case, on a line that is
                // always on screen and cannot be walked past. A second widget
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
