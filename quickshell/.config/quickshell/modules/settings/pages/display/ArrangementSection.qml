// The arrangement: where each screen sits relative to the others, dragged on a
// map rather than typed as coordinates.
//
// THE PAGE HEADER USED TO REFUSE THIS OUTRIGHT, on the grounds that moving one
// monitor rearranges the desktop under every window and undoing that is a
// second monitor's problem -- and that argument does not survive contact with
// the actual failure: a position is not a mode. Every screen keeps drawing
// whatever happens, the mistake is visible the moment the pointer refuses to
// cross where you expected, and the countdown here undoes it in the same ten
// seconds a mode change gets. What made it worth reversing is that this is
// precisely the setting nobody can compute in their head: "1080x240" is a fact
// about a portrait panel's height and half the difference between two
// monitors, and typing it is not how anyone thinks about which screen is on the
// left.
//
// THE MAP IS THE DRAFT. Dragging writes logical coordinates into arrangeDraft
// and nothing reaches the compositor until Apply, which is the same shape the
// mode controls use -- and the reason the rectangles move under the pointer
// while nothing on the desk does.
//
// SEPARATE PENDING STATE FROM THE MODE CHANGES, not a generalisation of it, and
// that is why this state lives in this file and not in DisplayDraft.qml. That
// state is one monitor, one spec, one revert, and it is the code path that can
// leave somebody looking at a black screen; growing it into a list to carry
// this feature would have put an arrangement's weight on the one part of this
// page that must not be wrong. The two lock each other out instead: this
// section is disabled while a mode is waiting to be confirmed, which is what
// `modePending` is for, and every monitor card is locked while an arrangement
// is, which is what `pending` is for.
//
// SO THE DRAFT AND THE DRAWING ARE ONE FILE HERE, where the mode changes keep
// them in two. It is not an inconsistency worth removing: the map IS the only
// thing that reads or writes an arrangement, and there is no second view of it
// to keep in step, where the mode draft is read by one card per monitor.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"
// SettingsSection lives two directories UP, and QML's implicit import covers a
// file's own directory only.
import "root:/modules/settings"

SettingsSection {
    id: root

    // Where the monitors come from, and where an applied arrangement has to be
    // read back afterwards.
    required property MonitorSource source

    // The same number the mode countdown uses. The page owns it; see there.
    required property int revertAfter

    // A mode change is waiting to be confirmed somewhere on the page.
    required property bool modePending

    // An arrangement is. The cards read this to lock themselves.
    readonly property bool pending: root.arrangePending !== null

    // Nothing to arrange with one screen: its position is 0,0 and the map
    // would be a single rectangle that cannot be dragged anywhere.
    visible: root.source.monitors.length > 1

    glyph: Icons.monitor
    title: "Arrangement"

    // ---------------- The map's own state ----------------

    // Dragging writes here; see the header.
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
        for (const mon of root.source.monitors) {
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
        const all = root.source.monitors;

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

        for (const other of root.source.monitors) {
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

        for (const mon of root.source.monitors) {
            const at = root.arrangedPosition(mon);
            minX = Math.min(minX, at.x);
            minY = Math.min(minY, at.y);
        }

        if (!isFinite(minX) || !isFinite(minY) || (minX === 0 && minY === 0))
            return;

        const next = ({});
        for (const mon of root.source.monitors) {
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

        for (const mon of root.source.monitors) {
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
            root.source.settleOverrides();
            return;
        }

        const head = root.persistQueue[0];
        root.persistQueue = root.persistQueue.slice(1);

        persister.command = ["desktop-monitors", "set"].concat(Monitors.specArgs(head));
        persister.running = true;
    }

    Process {
        id: arranger

        onExited: root.source.reload()
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

            for (const mon of root.source.monitors) {
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
        opacity: root.modePending ? 0.4 : 1

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }

        Repeater {
            model: root.source.monitors

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
                    enabled: !root.modePending && root.arrangePending === null
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
                enabled: root.arrangeDirty && !root.modePending
                onActivated: root.applyArrangement()
            }
        }
    }
}
