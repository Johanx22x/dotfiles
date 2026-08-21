// The display page: what each monitor is, and the three things about it that
// are worth changing from a settings window.
//
// IT TALKS TO ONE SCRIPT AND TO NOTHING ELSE. Every list, every apply and every
// write below goes through ~/.local/bin/desktop-monitors, and there is not a
// single `hyprctl` or `niri msg` left in this file. That is the whole reason
// this page works on both compositors: what a monitor is set to is the same
// question everywhere, and only the config language and the socket differ --
// which is exactly what that script exists to absorb. A third flavor is four
// branches in it and nothing at all here.
//
//     desktop-monitors list --json      what is connected, in one shape
//     desktop-monitors apply <spec>...  live, provisional, written nowhere
//     desktop-monitors set <spec>       live AND recorded
//     desktop-monitors forget <desc>    drop the record
//     desktop-monitors main <desc>      which monitor games open on
//     desktop-monitors file             where the record is kept
//
// WHAT A CONFIRMED CHANGE IS WRITTEN INTO, because it is not this file and it
// is not the compositor's hand-written config either. The script keeps a
// SECOND file, generated and untracked -- monitors.lua under Hyprland,
// monitors.kdl under niri -- and the page names it in the line under the title
// rather than hard-coding it, because the two flavors do not agree on it and
// asking is cheaper than being wrong.
//
// THE TWO FLAVORS DO NOT AGREE ON WHAT THAT FILE *IS*, EITHER, and it shows up
// on this page in exactly one place. Under Hyprland the generated file is an
// override layer: hyprland.lua declares the monitors by hand, dofile()s the
// generated one after them, and a later hl.monitor for the same output wins --
// so Copy config exists, to promote a value the shell worked out into the file
// a person maintains. Under niri there is no layering to be had (an `output`
// block in an include is ignored when the main config names the same monitor,
// measured), so the generated file is the only declaration there is and a block
// pasted into config.kdl would shadow this page for good. Hence
// `monitorConfigCopy`: the chip is drawn where it means something.
//
// WHY IT DOES NOT WRITE THE HAND-WRITTEN CONFIG ITSELF. That file is a stow
// symlink into a git repo and a thousand lines of hand-written commentary, in
// an order a person chose. A settings window that edited it would be a program
// rewriting prose it cannot read: the first change would move the monitor
// block, or drop the comment explaining why these monitors are matched by
// description and not by connector name, or both -- and the diff would land in
// git looking like something a human did. A generated file is the honest
// boundary. The shell owns that one; the person owns theirs.
//
// THE REVERT TIMER IS THE POINT OF THIS PAGE, not a nicety on top of it. A
// mode the panel cannot display leaves a black screen, and the window holding
// the undo button is on that screen. So an apply is provisional: the spec that
// was live is kept, a countdown starts, and unless it is confirmed the
// compositor is put back where it was. The confirmation is the thing you have
// to do; doing nothing is safe. That is the opposite way round from every
// other button in this shell, and it is deliberate.
//
// AND THE CONFIRMATION IS ALSO THE WRITE. Nothing reaches monitors.lua until
// somebody has said they can see the result -- see keep(), which is where that
// argument is made in full.
//
// THE BAR MOVES WHEN THE BIG MONITOR GOES PORTRAIT, and it looks exactly like
// a bug the first time. Screens.qml picks the shell's screen as the largest
// LANDSCAPE one, so rotating the main panel hands the bar, the launcher, the
// notifications and this window's own sibling surfaces to the other monitor.
// Correct behaviour, badly surprising -- so the rotation control says so
// before you press it, and only when it applies.
//
// WHAT IT DELIBERATELY WILL NOT DO: turn a monitor off. `desktop-monitors list`
// reports the monitors that are actually being driven, on both flavors, so a
// monitor disabled from here could not be listed again to be switched back on
// -- the revert timer would be the only way out of it, and a safety net is not
// a design.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"
// SettingsPage lives one directory UP, and QML's implicit import covers a
// file's own directory only.
import "root:/modules/settings"
// The parts this page is composed of, for the same reason: they live one
// directory DOWN.
import "root:/modules/settings/pages/display"

SettingsPage {
    id: root

    // Every control here writes a monitor layout into the compositor. Where it
    // cannot be driven, the page is not offered rather than shown dead.
    available: Compositor.can("monitorConfig")

    title: "Display"
    glyph: Icons.monitor
    keywords: ["monitor", "screen", "display", "resolution", "refresh", "hz",
        "scale", "scaling", "rotation", "rotate", "portrait", "landscape",
        "mode", "hyprland", "niri"]

    // ---------------- What the compositor said, last time it was asked ----------------
    //
    // IT IS A READING, NOT A CONTROL. Nothing on this page holds a monitor's
    // state of its own: the controls hold a DRAFT, and everything drawn as
    // fact comes from `source.monitors`.
    MonitorSource {
        id: source
    }

    // ---------------- What would be, and the ten seconds to say so ----------------
    //
    // OUTSIDE THE CARDS AND NOT IN THEM, which is the whole reason it is an
    // object of its own -- see its header.
    DisplayDraft {
        id: draft

        source: source
        revertAfter: root.revertAfter
    }

    // Long enough to see that the desktop redrew and read the line asking, and
    // short enough to sit out with your eyes shut if it did not. Read by both
    // countdowns on this page -- the mode one next door and the arrangement's
    // further down -- which is why it is here and not inside either.
    readonly property int revertAfter: 10

    // ---------------- Re-reading ----------------
    //
    // THE PAGE'S OWN `visible`, which is the only honest signal here: the
    // settings window builds every page at startup and keeps them all alive,
    // showing one at a time. Component.onCompleted fires once, for a page
    // nobody is looking at, and the window being open says nothing -- nine
    // other pages are open too.
    onVisibleChanged: {
        if (!root.visible)
            return;

        // The compositor's list, the saved list, and -- once per session --
        // where the saved list is kept. See MonitorSource.refresh, which holds
        // the guards and the reason for each of the three.
        source.refresh();

        // Which blue-light daemon, if any, this session has. Asked here rather
        // than polled or watched: the answer only changes when a package is
        // installed or a session restarts, and both of those end with a trip
        // back to this page. See NightLightSection.qml, which owns the probe
        // and has no `visible` of its own worth gating on -- QML allows one
        // onVisibleChanged handler per object and this page's is here.
        nightLight.probe();

        // The forget advice belongs to the visit it was earned in. It says to
        // go and settle something outside this window, and leaving it is the
        // likeliest thing to have happened in order to do that.
        source.dropForgetNotice();
    }

    // ---------------- Where a kept change goes ----------------
    //
    // ONE LINE AND NOT A PARAGRAPH. It is true of every control below it, so
    // it has to be said once, up here, and then never repeated on a row -- a
    // notice printed six times is a notice nobody reads. It used to say the
    // opposite ("this session only"), and the reason it no longer does is the
    // generated file; naming it is the point of the line, because it is a file
    // the person can read, delete or keep out of git themselves. The refresh
    // beside it is the manual way to re-read; the page does it on its own
    // whenever it is opened and after every apply.
    //
    Item {
        width: parent.width
        // Grows with the notice rather than clipping it, since the sentence
        // takes two lines at this window's default width and one at a wider
        // one.
        implicitHeight: Math.max(30, notice.implicitHeight + 10)

        Text {
            id: notice

            anchors.left: parent.left
            anchors.leftMargin: Theme.groupPadding
            anchors.right: rereadChip.left
            anchors.rightMargin: Theme.itemSpacing
            anchors.verticalCenter: parent.verticalCenter

            // WRAPS, and does not elide. It elided at first and the window
            // is not wide enough for the sentence, so what reached the screen
            // was "Kept changes are saved to ~/.config/hypr/monitors.lua — ge…"
            // -- the half that says WHERE, cut before the half that says the
            // file is generated. A settings window is the last place that
            // should be telling you most of something.
            text: source.savedTo === ""
                ? "Kept changes are written to a generated file, read back on every reload."
                : `Kept changes are saved to ${source.savedTo} — generated, read back on every reload.`
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Chip {
            id: rereadChip

            anchors.right: parent.right
            anchors.rightMargin: Theme.groupPadding
            anchors.verticalCenter: parent.verticalCenter

            label: "Re-read"
            glyph: Icons.refresh
            enabled: !source.busy
            // BOTH READINGS, because both can be behind: the compositor's if
            // something moved a monitor from elsewhere, and the saved list if a
            // write landed after the page last looked. This chip is the way to
            // catch up on either without closing the window.
            onActivated: source.reread()
        }
    }

    // ---------------- Arranging the monitors ----------------
    //
    // WHERE EACH SCREEN IS RELATIVE TO THE OTHERS, dragged on a map rather
    // than typed as coordinates. The header above used to refuse this outright,
    // on the grounds that moving one monitor rearranges the desktop under every
    // window and undoing that is a second monitor's problem -- and that
    // argument does not survive contact with the actual failure: a position is
    // not a mode. Every screen keeps drawing whatever happens, the mistake is
    // visible the moment the pointer refuses to cross where you expected, and
    // the countdown below undoes it in the same ten seconds a mode change
    // gets. What made it worth reversing is that this is precisely the setting
    // nobody can compute in their head: "1080x240" is a fact about a portrait
    // panel's height and half the difference between two monitors, and typing
    // it is not how anyone thinks about which screen is on the left.
    //
    // THE MAP IS THE DRAFT. Dragging writes logical coordinates into
    // arrangeDraft and nothing reaches the compositor until Apply, which is
    // the same shape the mode controls use -- and the reason the rectangles
    // move under the pointer while nothing on the desk does.
    //
    // SEPARATE PENDING STATE FROM THE MODE CHANGES, not a generalisation of
    // it. That state is one monitor, one spec, one revert, and it is the code
    // path that can leave somebody looking at a black screen; growing it into
    // a list to carry this feature would have put an arrangement's weight on
    // the one part of this page that must not be wrong. The two lock each
    // other out instead: this section is disabled while a mode is waiting to
    // be confirmed, and every monitor card is locked while an arrangement is.
    property var arrangeDraft: ({})

    // The specs that went out, with what they replaced, so the countdown has
    // something to put back. Null when nothing is provisional.
    property var arrangePending: null
    property int arrangeSeconds: 0

    // WHAT THE MONITOR TAKES UP ON THE DESKTOP, which is not `width` and
    // `height`. Those are the mode -- the pixels the panel is being driven at
    // -- and the desktop is laid out in logical pixels: the mode divided by
    // the scale, and then TURNED ON ITS SIDE for an odd transform. The
    // secondary panel here is a 1920x1080 mode at transform 3, which occupies
    // 1080x1920, and that 1080 is where the main monitor's x = 1080 comes
    // from. Get this wrong and every rectangle on the map is the right size
    // for a screen nobody has.
    function logicalSize(mon: var): var {
        const scale = (mon.scale ?? 1) || 1;
        const w = (mon.width ?? 0) / scale;
        const h = (mon.height ?? 0) / scale;

        return ((mon.transform ?? 0) % 2) === 1 ? { w: h, h: w } : { w: w, h: h };
    }

    function arrangedPosition(mon: var): var {
        return root.arrangeDraft[mon.name] ?? { x: mon.x ?? 0, y: mon.y ?? 0 };
    }

    // A NEW OBJECT, for the reason setDraft gives above: assigning into the
    // map in place emits no change signal and the map would move nothing.
    function setArranged(name: string, x: real, y: real): void {
        const next = Object.assign({}, root.arrangeDraft);
        next[name] = { x: Math.round(x), y: Math.round(y) };
        root.arrangeDraft = next;
    }

    readonly property bool arrangeDirty: {
        for (const mon of source.monitors) {
            const at = root.arrangedPosition(mon);
            if (at.x !== (mon.x ?? 0) || at.y !== (mon.y ?? 0))
                return true;
        }
        return false;
    }

    // Two screens claiming the same desktop coordinates. Neither compositor
    // refuses it and it is occasionally even deliberate, so this warns rather
    // than refuses -- but it is almost always a drag that was let go early, and the
    // symptom (a pointer that vanishes into a region drawn twice) is not one
    // anybody diagnoses from the desk.
    readonly property bool arrangeOverlaps: {
        const all = source.monitors;

        for (let i = 0; i < all.length; i++) {
            for (let j = i + 1; j < all.length; j++) {
                const a = root.arrangedPosition(all[i]);
                const as = root.logicalSize(all[i]);
                const b = root.arrangedPosition(all[j]);
                const bs = root.logicalSize(all[j]);

                if (a.x < b.x + bs.w && b.x < a.x + as.w
                    && a.y < b.y + bs.h && b.y < a.y + as.h)
                    return true;
            }
        }

        return false;
    }

    // Edge magnetism, and it is what makes this usable with a mouse: the
    // difference between "next to" and "next to, give or take four pixels" is
    // invisible on a map two hundred pixels wide and is a four-pixel dead
    // stripe the pointer cannot cross on the desk.
    //
    // Four candidates per axis per neighbour -- flush after it, flush before
    // it, and the two ways of lining up an edge -- and the nearest one inside
    // the tolerance wins. The tolerance is given in LOGICAL pixels by the
    // caller, converted from a distance in map pixels, so it means the same
    // thing on screen whatever the zoom.
    function snapPosition(mon: var, x: real, y: real, tolerance: real): var {
        const size = root.logicalSize(mon);

        let bestX = x;
        let bestY = y;
        let nearestX = tolerance;
        let nearestY = tolerance;

        for (const other of source.monitors) {
            if (other.name === mon.name)
                continue;

            const at = root.arrangedPosition(other);
            const os = root.logicalSize(other);

            for (const candidate of [at.x + os.w, at.x - size.w, at.x, at.x + os.w - size.w]) {
                const distance = Math.abs(candidate - x);
                if (distance < nearestX) {
                    nearestX = distance;
                    bestX = candidate;
                }
            }

            for (const candidate of [at.y + os.h, at.y - size.h, at.y, at.y + os.h - size.h]) {
                const distance = Math.abs(candidate - y);
                if (distance < nearestY) {
                    nearestY = distance;
                    bestY = candidate;
                }
            }
        }

        return { x: bestX, y: bestY };
    }

    // The whole layout pulled back so its top-left corner is 0,0.
    //
    // Both compositors take negative coordinates and this is not about either
    // refusing them. It is about the numbers a person reads afterwards: the
    // monitor block in the hand-written config, the Position row on every card
    // and every example in either wiki are written from an origin, and a desktop
    // whose left edge is at -1080 makes every one of those a subtraction. Run after each drag, so the
    // origin is a consequence of the arrangement rather than of which monitor
    // happened to be dragged.
    function normaliseArrangement(): void {
        let minX = Infinity;
        let minY = Infinity;

        for (const mon of source.monitors) {
            const at = root.arrangedPosition(mon);
            minX = Math.min(minX, at.x);
            minY = Math.min(minY, at.y);
        }

        if (!isFinite(minX) || !isFinite(minY) || (minX === 0 && minY === 0))
            return;

        const next = ({});
        for (const mon of source.monitors) {
            const at = root.arrangedPosition(mon);
            next[mon.name] = { x: at.x - minX, y: at.y - minY };
        }

        root.arrangeDraft = next;
    }

    // Only the ones that actually moved. Normalising can shift every monitor
    // at once, and it can equally shift them all back to where they already
    // were -- the compositor is told about the difference, not about the
    // operation.
    //
    // Built on specOf and NOT on draftOf: an unapplied mode sitting in the
    // other draft belongs to the button that was not pressed, and smuggling it
    // out with a position would apply a mode change nobody confirmed.
    function arrangementSpecs(): var {
        const specs = [];

        for (const mon of source.monitors) {
            const at = root.arrangedPosition(mon);
            if (at.x === (mon.x ?? 0) && at.y === (mon.y ?? 0))
                continue;

            specs.push({
                spec: Object.assign({}, Monitors.specOf(mon), { position: `${at.x}x${at.y}` }),
                revert: Monitors.specOf(mon)
            });
        }

        return specs;
    }

    // ONE CALL FOR THE WHOLE ARRANGEMENT, and this is not tidiness. Moving two
    // monitors in two commands means a moment where the first has moved and the
    // second has not, which for a layout that ends up correct is a flash of one
    // that overlaps -- and every window on the desktop is re-laid out for both
    // of them. So `apply` takes any number of specs, five arguments each, and
    // the script decides how atomic it can make them: Hyprland gets one eval
    // holding several hl.monitor calls, niri gets them back to back over its
    // socket, which is as close as it has.
    //
    // Named for what it does rather than for how it used to do it -- there is no
    // eval in this file any more.
    function applyArrangement_(specs: var): void {
        let args = ["desktop-monitors", "apply"];
        for (const spec of specs)
            args = args.concat(Monitors.specArgs(spec));

        arranger.command = args;
        arranger.running = true;
    }

    function applyArrangement(): void {
        const specs = root.arrangementSpecs();
        if (specs.length === 0)
            return;

        root.arrangePending = specs;
        root.arrangeSeconds = root.revertAfter;
        root.applyArrangement_(specs.map(entry => entry.spec));
    }

    function keepArrangement(): void {
        if (!root.arrangePending)
            return;

        // Written one at a time, waiting for each. `desktop-monitors set` reads
        // the whole state file, edits one record and writes it back, so two
        // copies started together would each save what they read before the
        // other wrote -- and the second monitor's position would land in a
        // file that had already forgotten the first's.
        root.persistQueue = root.arrangePending.map(entry => entry.spec);
        root.arrangePending = null;
        root.arrangeDraft = ({});
        root.pumpPersist();
    }

    function revertArrangement(): void {
        if (!root.arrangePending)
            return;

        const back = root.arrangePending.map(entry => entry.revert);
        root.arrangePending = null;
        root.arrangeDraft = ({});
        root.applyArrangement_(back);
    }

    property var persistQueue: []

    function pumpPersist(): void {
        if (persister.running)
            return;

        if (root.persistQueue.length === 0) {
            source.settleOverrides();
            return;
        }

        const head = root.persistQueue[0];
        root.persistQueue = root.persistQueue.slice(1);

        persister.command = ["desktop-monitors", "set"].concat(Monitors.specArgs(head));
        persister.running = true;
    }

    Process {
        id: arranger

        onExited: source.reload()
    }

    // A Process and not execDetached, unlike the mode path's persist: this one
    // has a queue behind it and the next write cannot start until this one has
    // finished. See keepArrangement.
    Process {
        id: persister

        onExited: root.pumpPersist()
    }

    // Bound to the pending state and not to `visible`, for the reason the
    // other countdown gives: the whole point of a revert is that it fires
    // whether or not anybody is still looking at this page.
    Timer {
        id: arrangeCountdown

        interval: 1000
        repeat: true
        running: root.arrangePending !== null

        onTriggered: {
            root.arrangeSeconds--;
            if (root.arrangeSeconds <= 0)
                root.revertArrangement();
        }
    }

    SettingsSection {
        // Nothing to arrange with one screen: its position is 0,0 and the map
        // would be a single rectangle that cannot be dragged anywhere.
        visible: source.monitors.length > 1

        width: root.width
        glyph: Icons.monitor
        title: "Arrangement"

        Text {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: "Drag a screen to say where it sits. Edges snap to the "
                + "neighbours they are near, and nothing reaches the "
                + "compositor until Apply."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        Rectangle {
            id: map

            // The margin around the desktop's own bounding box, in logical
            // pixels, so there is somewhere to drag a monitor TO. Without it
            // the map is exactly the size of the current layout and pulling a
            // screen out to the right walks it off the edge of its own canvas.
            readonly property int margin: 600

            // Frozen for the duration of a drag. The bounding box grows as a
            // monitor is pulled outwards, the scale would shrink to keep it in
            // view, and everything on the map -- including the rectangle under
            // the pointer -- would slide away from the mouse while it is being
            // held. One drag, one scale.
            property var frozen: null

            readonly property var bounds: {
                if (map.frozen)
                    return map.frozen;

                let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

                for (const mon of source.monitors) {
                    const at = root.arrangedPosition(mon);
                    const size = root.logicalSize(mon);
                    minX = Math.min(minX, at.x);
                    minY = Math.min(minY, at.y);
                    maxX = Math.max(maxX, at.x + size.w);
                    maxY = Math.max(maxY, at.y + size.h);
                }

                if (!isFinite(minX))
                    return { x: 0, y: 0, w: 1920, h: 1080 };

                return {
                    x: minX - map.margin,
                    y: minY - map.margin,
                    w: (maxX - minX) + map.margin * 2,
                    h: (maxY - minY) + map.margin * 2
                };
            }

            // Fit, never fill: the same number on both axes, or the desktop's
            // proportions would be a lie and a portrait monitor would draw as
            // a square.
            readonly property real factor: Math.min(map.width / map.bounds.w,
                                                    map.height / map.bounds.h)

            readonly property real offsetX: (map.width - map.bounds.w * map.factor) / 2
            readonly property real offsetY: (map.height - map.bounds.h * map.factor) / 2

            function toMapX(logical: real): real {
                return (logical - map.bounds.x) * map.factor + map.offsetX;
            }

            function toMapY(logical: real): real {
                return (logical - map.bounds.y) * map.factor + map.offsetY;
            }

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            height: 240

            radius: Theme.groupRadius
            color: Qt.alpha(Theme.surfaceContainerHighest, 0.4)

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }

            // Off to the pointer while a MODE change is waiting to be
            // confirmed. Two provisional changes to the same monitors, each
            // with its own countdown, is a state with no honest way back --
            // the same rule the cards apply to each other.
            opacity: draft.pendingName !== "" ? 0.4 : 1

            Behavior on opacity {
                NumberAnimation { duration: Theme.animDuration }
            }

            Repeater {
                model: source.monitors

                delegate: Rectangle {
                    id: screen

                    required property var modelData

                    readonly property var at: root.arrangedPosition(screen.modelData)
                    readonly property var logical: root.logicalSize(screen.modelData)
                    readonly property bool moved: screen.at.x !== (screen.modelData.x ?? 0)
                        || screen.at.y !== (screen.modelData.y ?? 0)

                    x: map.toMapX(screen.at.x)
                    y: map.toMapY(screen.at.y)
                    width: Math.max(8, screen.logical.w * map.factor)
                    height: Math.max(8, screen.logical.h * map.factor)

                    radius: 6

                    // The one being dragged leads in the accent, the ones that
                    // have moved since the last apply are tinted, and the rest
                    // are plain. Three states because they answer three
                    // different questions, and the middle one is the only way
                    // to see what Apply is about to send.
                    color: dragArea.pressed || screen.moved
                        ? Qt.alpha(Theme.primary, 0.28)
                        : Theme.surfaceContainerHigh

                    border.width: screen.modelData.focused ? 2 : 1
                    border.color: dragArea.pressed || screen.moved
                        ? Theme.primary
                        : Theme.outlineVariant

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDuration }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: screen.modelData.name ?? ""
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            font.weight: Font.Bold
                            color: Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        // The logical size and not the mode, because that is
                        // what the rectangle is drawn from: a rotated 1080p
                        // panel reads 1080 × 1920 here and the number matches
                        // the shape it is written on.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: screen.height > 44
                            text: `${Math.round(screen.logical.w)} × ${Math.round(screen.logical.h)}`
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 2
                            color: Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }
                    }

                    // NO drag.target, which is the obvious way to write this
                    // and the wrong one here. Handing the rectangle to the
                    // dragger assigns straight to x and y, which DESTROYS the
                    // bindings above -- the map would then be showing a
                    // position the draft does not hold, and the next re-read
                    // would leave it there. The pointer is followed by hand
                    // instead and the answer goes into the draft, so the
                    // rectangle is always drawn from the model.
                    MouseArea {
                        id: dragArea

                        property real originX: 0
                        property real originY: 0
                        property real grabX: 0
                        property real grabY: 0

                        anchors.fill: parent
                        enabled: draft.pendingName === "" && root.arrangePending === null
                        cursorShape: dragArea.enabled
                            ? (dragArea.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                            : Qt.ArrowCursor

                        onPressed: mouse => {
                            const point = dragArea.mapToItem(map, mouse.x, mouse.y);
                            dragArea.grabX = point.x;
                            dragArea.grabY = point.y;
                            dragArea.originX = screen.at.x;
                            dragArea.originY = screen.at.y;
                            map.frozen = map.bounds;
                        }

                        onPositionChanged: mouse => {
                            if (!dragArea.pressed)
                                return;

                            // In MAP coordinates and not this item's: the item
                            // is what is moving, so a delta measured inside it
                            // is measured against a frame that has already
                            // shifted by the same amount -- the rectangle
                            // would crawl at half speed and then stop.
                            const point = dragArea.mapToItem(map, mouse.x, mouse.y);
                            const wantX = dragArea.originX + (point.x - dragArea.grabX) / map.factor;
                            const wantY = dragArea.originY + (point.y - dragArea.grabY) / map.factor;

                            // Twelve map pixels' worth, whatever that is in
                            // logical ones at this zoom.
                            const snapped = root.snapPosition(screen.modelData, wantX, wantY,
                                12 / map.factor);

                            root.setArranged(screen.modelData.name, snapped.x, snapped.y);
                        }

                        onReleased: {
                            root.normaliseArrangement();
                            map.frozen = null;
                        }

                        onCanceled: {
                            map.frozen = null;
                        }
                    }
                }
            }
        }

        Text {
            visible: root.arrangeOverlaps

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 6

            text: "Two screens are on top of each other. Neither compositor "
                + "refuses it, but the overlapping strip is drawn by both and "
                + "the pointer behaves as though one of them is not there."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.warning

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // The buttons, and the banner that replaces them once something is
        // provisional. Same grammar as the monitor cards below: Apply while
        // there is a difference, then a question with a countdown on it.
        Item {
            width: parent.width
            implicitHeight: 44
            visible: root.arrangeDirty || root.arrangePending !== null

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.groupPadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.itemSpacing

                visible: root.arrangePending !== null

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Glyphs.timerSand
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.iconSize
                    color: Theme.warning

                    Behavior on color {
                        ColorAnimation { duration: Theme.recolorDuration }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `Keep this arrangement? Reverting in ${root.arrangeSeconds}s`
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
                    visible: root.arrangePending !== null
                    label: "Keep"
                    glyph: Glyphs.contentSave
                    filled: true
                    onActivated: root.keepArrangement()
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.arrangePending !== null
                    label: "Revert now"
                    onActivated: root.revertArrangement()
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.arrangePending === null
                    label: "Reset"
                    enabled: root.arrangeDirty
                    onActivated: root.arrangeDraft = ({})
                }

                Chip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.arrangePending === null
                    label: "Apply"
                    filled: true
                    enabled: root.arrangeDirty && draft.pendingName === ""
                    onActivated: root.applyArrangement()
                }
            }
        }
    }

    NightLightSection {
        id: nightLight

        width: root.width
    }

    // ---------------- One section per connected monitor ----------------
    Repeater {
        model: source.monitors

        SettingsSection {
            id: card

            required property var modelData

            readonly property var mon: card.modelData
            readonly property var spec: draft.draftOf(card.mon)
            readonly property bool dirty: draft.isDirty(card.mon)
            readonly property bool pending: draft.pendingName === card.mon.name
            // Locked while ANY monitor is waiting to be confirmed, not only
            // this one. Stacking a second provisional change on top of one
            // that may be about to undo itself is a state with no honest way
            // back.
            // ANY provisional change, not only a mode one: an arrangement is
            // also waiting on a countdown and also about to be undone, and
            // stacking a mode change on top of one is the state this lock
            // exists to make impossible.
            readonly property bool locked: draft.pendingName !== "" || root.arrangePending !== null
            // null when this monitor has nothing saved, which is the state
            // every monitor is in until somebody keeps a change.
            readonly property var saved: source.savedOf(card.mon)

            readonly property bool isMain: source.isMainMonitor(card.mon)
            readonly property bool mainIsChosen: source.mainChosen(card.mon)

            width: root.width
            glyph: Icons.monitor
            title: Monitors.monitorTitle(card.mon)

            // ---------------- What it is ----------------
            Reading {
                label: "Connector"
                value: card.mon.name ?? ""
            }

            // The full EDID string, verbatim, and it is worth being able to
            // read it off the screen rather than out of a terminal: it is the
            // name every rule in the compositor's own config matches on, and
            // the two compositors do not spell it the same way -- Hyprland
            // normalises the manufacturer and niri does not.
            //
            // Which is also why this row shows what THIS session reports and
            // never a string derived from the other one. `desktop-monitors list`
            // is the same answer in a terminal.
            Reading {
                label: "Description"
                value: card.mon.description ?? ""
            }

            Reading {
                label: "Resolution"
                value: `${card.mon.width} × ${card.mon.height}`
            }

            Reading {
                label: "Refresh"
                value: `${(card.mon.refreshRate ?? 0).toFixed(2)} Hz`
            }

            Reading {
                label: "Scale"
                value: (card.mon.scale ?? 1).toFixed(2)
            }

            Reading {
                label: "Rotation"
                value: Monitors.transformLabel(card.mon.transform ?? 0)
            }

            Reading {
                label: "Position"
                value: `${card.mon.x}, ${card.mon.y}`
            }

            Reading {
                label: "Focus"
                value: card.mon.focused ? "has the keyboard" : "—"
                tone: card.mon.focused ? Theme.primary : Theme.textOnSurfaceVariant
            }

            // WHERE THE SHELL LIVES, and it distinguishes chosen from worked
            // out. Both are "yes" to the question the bar answers, and they
            // behave differently the moment a monitor is unplugged or rotated:
            // an automatic pick moves, a chosen one waits for its screen to
            // come back. Somebody surprised by the bar moving is reading this
            // row to find out which of the two they have.
            Reading {
                label: "Main monitor"
                value: card.isMain ? (card.mainIsChosen ? "yes — chosen" : "yes — picked automatically") : "—"
                tone: card.isMain ? Theme.primary : Theme.textOnSurfaceVariant
            }

            // WHAT IS ON DISK, and it is a seventh fact about this monitor
            // rather than a repeat of the six above it. The two disagree
            // whenever something changed the mode since it was saved -- a
            // reload has not happened yet, or a rule elsewhere won -- and that
            // disagreement is the only thing on this page that can show it.
            // Absent, and not "none", when nothing is saved: a row saying "no
            // override" on all six monitors on a machine that has never used
            // this feature is six lines of nothing.
            Reading {
                visible: card.saved !== null
                label: "Saved override"
                value: card.saved ? Monitors.savedLabel(card.saved) : ""
            }

            // Separates the facts above from the draft below, because they
            // look alike and mean opposite things: everything over this line
            // is what IS, everything under it is what WOULD BE.
            Rectangle {
                width: parent.width - Theme.groupPadding * 2
                x: Theme.groupPadding
                height: 1
                color: Theme.outlineVariant

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // ---------------- What it would be ----------------
            CycleRow {
                glyph: Glyphs.arrowExpand
                label: "Mode"
                value: Monitors.modeLabel(card.spec.mode)
                enabled: !card.locked

                // WRAPS RATHER THAN CLAMPS. Nothing is applied by stepping --
                // this only moves a draft -- so running off the end costs
                // nothing, and the main panel offers 29 modes: a button that
                // goes dead at the top of that list is a control that looks
                // broken long before it is understood.
                onStepped: delta => {
                    const modes = Monitors.modeList(card.mon);
                    const at = modes.indexOf(card.spec.mode);
                    const next = (at + delta + modes.length) % modes.length;
                    draft.setDraft(card.mon, { mode: modes[next] });
                }
            }

            CycleRow {
                glyph: Glyphs.relativeScale
                label: "Scale"
                value: card.spec.scale.toFixed(2)
                enabled: !card.locked

                onStepped: delta => {
                    const scales = Monitors.scaleList(card.mon);
                    let at = scales.findIndex(s => Math.abs(s - card.spec.scale) < 0.001);
                    if (at < 0)
                        at = 0;
                    const next = (at + delta + scales.length) % scales.length;
                    draft.setDraft(card.mon, { scale: scales[next] });
                }
            }

            // Rotation is a segmented control and not a cycle, because it has
            // four options that everyone already knows the names of and no
            // order worth stepping through -- going from 0° to 270° should be
            // one click, not three.
            Rectangle {
                width: parent.width
                implicitHeight: Theme.groupHeight
                radius: Theme.groupRadius
                color: "transparent"

                opacity: card.locked ? 0.4 : 1

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.groupPadding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.itemSpacing

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Glyphs.screenRotation
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.iconSize
                        color: Theme.textOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Rotation"
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.weight: Theme.fontWeight
                        color: Theme.textOnSurface

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.groupPadding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        // The four rotations, as index and label. 4-7 (the
                        // flipped ones) are absent on purpose: nothing on this
                        // desk wants a mirrored output, and a segmented
                        // control with eight options is a list.
                        model: [
                            { transform: 0, text: "0°" },
                            { transform: 1, text: "90°" },
                            { transform: 2, text: "180°" },
                            { transform: 3, text: "270°" }
                        ]

                        Chip {
                            required property var modelData

                            anchors.verticalCenter: parent.verticalCenter
                            label: modelData.text
                            // Nothing is selected when the live transform is a
                            // flipped one, which is honest: none of these four
                            // is what the monitor is doing.
                            filled: card.spec.transform === modelData.transform
                            enabled: !card.locked
                            onActivated: draft.setDraft(card.mon, { transform: modelData.transform })
                        }
                    }
                }
            }

            // ONLY WHEN IT IS ABOUT TO HAPPEN. See the header: Screens.qml
            // gives the bar to the largest landscape screen, so turning the
            // big monitor on its side moves the whole shell to the other one.
            // A permanent note saying so would be skipped by the third visit;
            // this one appears exactly when the draft would cause it.
            Text {
                visible: (card.spec.transform === 1 || card.spec.transform === 3)
                    && (card.mon.transform ?? 0) !== 1 && (card.mon.transform ?? 0) !== 3

                x: Theme.groupPadding
                width: parent.width - Theme.groupPadding * 2
                bottomPadding: 6

                text: "Portrait makes this screen taller than it is wide. "
                    + "The bar, the launcher and the notifications go to the largest landscape screen, "
                    + "so they will move to the other monitor."
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.warning

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // ---------------- Actions ----------------
            Item {
                width: parent.width
                implicitHeight: Theme.groupHeight
                visible: !card.pending

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.groupPadding
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.itemSpacing

                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Apply"
                        glyph: Icons.monitor
                        filled: true
                        enabled: card.dirty && !card.locked
                        onActivated: draft.commit(card.mon)
                    }

                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Discard"
                        glyph: Icons.close
                        enabled: card.dirty && !card.locked
                        onActivated: draft.clearDraft(card.mon.name)
                    }

                    // STILL HERE NOW THAT KEEPING WORKS, and it is not the
                    // leftover of the days when it was the only way to make a
                    // change last. The two destinations are different files
                    // with different owners: Keep writes the generated file, and
                    // this puts the same block on the clipboard for the
                    // hand-written one, which is in git. Promoting a value from
                    // the first to the second is a thing to want, and it is not
                    // a thing a settings window should do by itself -- see the
                    // header.
                    //
                    // NOT gated on `dirty`, unlike the two above: copying the
                    // block for a monitor exactly as it is now is the whole
                    // point on the day you want to write the current setup
                    // into the tracked config without changing anything first.
                    //
                    // HIDDEN WHERE THERE IS NOWHERE TO PASTE IT. Under niri the
                    // generated file is the ONLY declaration of an output, so
                    // this block would have no destination -- and the one place
                    // somebody would try, config.kdl, is the place that shadows
                    // the generated file and kills this page. A chip that hands
                    // you a footgun is worse than no chip.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Compositor.can("monitorConfigCopy")
                        label: draft.copiedFor === card.mon.name ? "Copied" : "Copy config"
                        glyph: draft.copiedFor === card.mon.name ? Glyphs.check : Icons.clipboard
                        onActivated: draft.copyConfig(card.mon)
                    }

                    // Moving the shell here, or letting the rule pick again.
                    // Hidden on a single-monitor machine: with one screen it is
                    // already the main one and the chip could only re-state
                    // that.
                    //
                    // NOT LOCKED BY `card.locked`, unlike the mode controls
                    // next to it. That lock is about provisional changes a
                    // countdown is about to undo, and this is not one of them:
                    // nothing here can leave a screen black, so there is
                    // nothing to confirm and nothing to revert.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Screens.all.length > 1
                        label: card.mainIsChosen ? "Unset main" : "Make main"
                        glyph: card.mainIsChosen ? Icons.restore : Icons.monitor
                        enabled: !source.settingMain && (card.mainIsChosen || !card.isMain || Config.mainMonitor !== "")
                        onActivated: card.mainIsChosen ? source.clearMain(card.mon) : source.makeMain(card.mon)
                    }

                    // HIDDEN AND NOT DIMMED, which is the one place this page
                    // departs from the rule written on Chip. A disabled chip
                    // says "not now"; this one would be saying "not until you
                    // save something", which on a machine that never has is a
                    // dead button beside three live ones forever. It is last in
                    // the row, so its coming and going moves nothing that was
                    // already there.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.saved !== null
                        label: "Forget saved"
                        glyph: Icons.restore
                        enabled: !card.locked && !source.forgetting
                        onActivated: source.forget(card.mon)
                    }
                }
            }

            // What the main-monitor write left behind, in the script's words.
            // The shell half of that click is already visible -- the bar moved
            // as it was pressed -- so anything worth printing here is about the
            // compositor half, which is the half that may be waiting on a
            // reload.
            Text {
                visible: source.mainNoticeFor === card.mon.name && source.mainNotice !== ""

                x: Theme.groupPadding
                width: parent.width - Theme.groupPadding * 2
                bottomPadding: 6

                text: source.mainNotice
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                color: Theme.warning

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // THE SCRIPT'S OWN WORDS, printed verbatim under the monitor they
            // were about. `forget` rewrites the generated file and deliberately
            // applies nothing, so at this instant the file and the screen
            // disagree -- and what settles them is not the same on both flavors.
            // Shown rather than paraphrased so there is one copy of that
            // sentence, in the script that knows it.
            Text {
                visible: source.forgetNoticeFor === card.mon.name && source.forgetNotice !== ""

                x: Theme.groupPadding
                width: parent.width - Theme.groupPadding * 2
                bottomPadding: 6

                text: source.forgetNotice
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize - 1
                // Amber and not the ordinary muted grey, for the same reason
                // the portrait note is: this is not an error, it is a state
                // that ends when you do the thing it asks.
                color: Theme.warning

                Behavior on color {
                    ColorAnimation { duration: Theme.recolorDuration }
                }
            }

            // ---------------- The way back ----------------
            //
            // WHY NOT ConfirmButton. That one arms on the first click and acts
            // on the second, so the dangerous thing happens only if you
            // confirm it -- which is the right shape for Reset and the wrong
            // shape here. The dangerous thing has ALREADY happened by the time
            // this row appears: the mode is live, and what the click buys is
            // permission to keep it -- and, since keep() writes, permission to
            // write it down. Silence has to undo, not do nothing. Its
            // countdown is also a border draining away with no number on it,
            // and the number is the one thing worth reading when you are
            // waiting to find out whether the screen comes back.
            Rectangle {
                width: parent.width - 8
                x: 4
                implicitHeight: Theme.groupHeight
                radius: Theme.groupRadius
                visible: card.pending

                // The shell's amber, the same one the Wi-Fi hardware-switch
                // line uses: this is not an error, it is a state that is about
                // to end by itself.
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
                        text: Glyphs.timerSand
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.iconSize
                        color: Theme.warning

                        Behavior on color {
                            ColorAnimation { duration: Theme.recolorDuration }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `Keep this display setting? Reverting in ${draft.secondsLeft}s`
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

                    // "Keep" and a save glyph, because this one press does both
                    // things: it stops the countdown AND it is what writes the
                    // change to the generated file. A tick here would say the
                    // change was merely accepted.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Keep"
                        glyph: Glyphs.contentSave
                        filled: true
                        onActivated: draft.keep()
                    }

                    // The same thing the timer is about to do, for when you
                    // can already see it is wrong and would rather not sit
                    // through the countdown.
                    Chip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Revert now"
                        onActivated: draft.revert()
                    }
                }
            }
        }
    }

    // ---------------- Nothing plugged in, or nothing read yet ----------------
    //
    // The script is asked when the page appears, so an empty list is either the
    // few milliseconds before the first answer or a genuinely empty reply.
    // Both are covered by one line: a page that draws nothing at all reads as
    // a page that failed to load.
    SettingsSection {
        width: root.width
        visible: source.monitors.length === 0
        glyph: Icons.monitor
        title: "Monitors"

        Text {
            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 4

            text: "No monitors reported. `desktop-monitors list` reports the ones actually "
                + "being driven, so a screen that is switched off in the compositor does "
                + "not appear here."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }
}
