// A hover note, for the row that needs a sentence the label has no room for.
//
// IT IS A CHILD OF WHAT IT EXPLAINS, not a window-level overlay, so it is
// clipped by the first ancestor with clip: true -- which in the settings
// window is the Flickable holding the pages. That used to be the end of the
// story, and the end of the story was a bug: every caller placed its note
// BELOW the row by hand, nothing asked whether there was room below, and a
// row near the bottom of a page with no scroll left put its note past the
// visible area, where the clip sliced the second line through the middle.
//
// THE DECISION NOW LIVES HERE, which is the point of moving it. The note
// goes below when it fits and flips above when it does not, and a caller
// that says nothing about placement still gets that -- so a fourth call site
// cannot reintroduce the bug by forgetting the way the first three did.
//
// THE ALTERNATIVE WAS A SINGLE NOTE AT WINDOW LEVEL with the rows reporting
// their position into it, which is what this header used to recommend "on
// the day a row at the bottom needs one". This is that day, and it was not
// taken. It needs an overlay item that every host of this component would
// have to provide and keep in the right stacking order; it moves the note
// out of the coordinate system its caller writes its x in; and it fixes
// clipping by escaping the clipped container, which only ever works for the
// containers somebody remembered to give an overlay. Flipping fixes it by
// staying inside, and therefore works unchanged in ScrollList, in the pages
// Flickable, and in whatever else this shell clips next.
//
// Opaque, unlike almost everything else this shell draws. A translucent note
// over a translucent window over a wallpaper is three layers of image behind
// two lines of small text, and the point of the thing is that it can be read
// at a glance.

import QtQml
import QtQuick
import "root:/"

Rectangle {
    id: root

    property alias text: label.text
    // Set by whatever is being hovered. Not `visible` directly: the fade
    // needs something to animate, and an item that is not visible does not
    // animate at all.
    property bool shown: false

    // Wide enough for a sentence over two or three lines. Wider and the eye
    // has to travel back across the row it is explaining.
    property int maxWidth: 320

    // ---------------- Where it goes ----------------
    //
    // A CALLER STILL SAYS WHAT IT WANTS, it just says it as a band instead of
    // as a y. The band is the part of the parent the note must not cover --
    // the row, or the label line of a row that has controls under it -- and
    // it is given in the parent's own coordinates, the same ones the caller
    // already writes `x` in. From it this file derives both candidate
    // positions, and they are mirror images, so a note that hangs 4px into
    // the row's bottom edge when it is below hangs 4px into its top edge when
    // it is above and the two look like the same object.
    //
    // The defaults are the whole parent, which is what two of the three call
    // sites meant anyway.
    property real anchorY: 0
    property real anchorHeight: root.parent ? root.parent.height : 0

    // Distance between the band and the note. NEGATIVE OVERLAPS, which is
    // what the two row components want: a note that starts a few pixels
    // inside the row reads as belonging to it rather than as floating loose
    // between two rows.
    property real gap: 0

    // ---------------- The viewport it must stay inside ----------------
    //
    // FOUND BY WALKING UP, not by naming ScrollList or the settings window.
    // The thing that can cut the note is whatever ancestor has clip: true,
    // and there is no reason for this file to know which component that is --
    // this way a note inside ScrollList, inside the pages Flickable, or
    // inside some future clipped card all get the same treatment, and a note
    // with no clipped ancestor at all (a popout, a bar) correctly decides it
    // has infinite room and always hangs below.
    //
    // IT IS A BINDING AND IT RE-EVALUATES. Every `parent` and every `clip`
    // read below is a property read, so QML's dependency capture registers
    // each of them; reparenting or turning clip on somewhere up the chain
    // re-runs this. That matters at startup more than later, because the
    // chain is not complete at the moment this object is constructed.
    readonly property Item viewport: root.clipperOf(root)

    function clipperOf(item: Item): Item {
        let p = item ? item.parent : null;
        while (p) {
            if (p.clip === true)
                return p;
            p = p.parent;
        }
        return null;
    }

    // WHERE THE PARENT'S ORIGIN SITS INSIDE THAT VIEWPORT, in the viewport's
    // own coordinates, which is the number the whole decision turns on.
    //
    // THIS IS NOT mapToItem, DELIBERATELY, and the comment in StepperRow.qml
    // that this file's fix grew out of says why: mapToItem is a function, not
    // a binding. It is evaluated once, and once -- for a tooltip declared
    // inside a row inside a Flickable -- is before anything has been laid
    // out. It returned 0 there and the note landed in the right place for the
    // wrong reason, which held only until something moved.
    //
    // Summing `y` up the chain by hand gives the same number AND a real
    // dependency on every term in it. Scrolling a Flickable moves its
    // contentItem, and contentItem is in this chain, so its `y` is one of the
    // terms and the sum re-runs on every scroll. So does resizing the window,
    // which changes a row's `y` inside its column.
    //
    // It ignores scale and rotation, which mapToItem would not. Nothing in
    // this shell puts either between a row and its Flickable, and a note that
    // needs to survive a transform needs the real projection, not this.
    readonly property real viewportY: root.offsetIn(root.parent, root.viewport)

    function offsetIn(item: Item, stop: Item): real {
        if (!stop)
            return 0;
        let sum = 0;
        let p = item;
        while (p && p !== stop) {
            sum += p.y;
            p = p.parent;
        }
        return sum;
    }

    // The same walk, kept as a list, because a flipped note needs it too --
    // see the stacking note further down.
    readonly property var ancestry: root.chainTo(root.parent, root.viewport)

    function chainTo(item: Item, stop: Item): var {
        const out = [];
        let p = item;
        while (p && p !== stop) {
            out.push(p);
            p = p.parent;
        }
        return out;
    }

    // The two candidates, in the parent's coordinates.
    readonly property real belowY: root.anchorY + root.anchorHeight + root.gap
    readonly property real aboveY: root.anchorY - root.height - root.gap

    // BELOW IS THE DEFAULT AND STAYS THE DEFAULT. A note that jumps sides on
    // a page that has plenty of room is harder to follow than one that always
    // appears in the same place, so above is only ever a rescue.
    readonly property bool fitsBelow: !root.viewport
        || root.viewportY + root.belowY + root.height <= root.viewport.height
    readonly property bool fitsAbove: !!root.viewport
        && root.viewportY + root.aboveY >= 0
    readonly property bool flipped: !root.fitsBelow && root.fitsAbove

    // AND WHEN IT FITS NEITHER WAY, which flipping alone does not answer: a
    // note taller than the space above AND the space below, i.e. a viewport
    // shorter than about two rows plus the note. Neither side can show it
    // whole from its anchor, so the anchor is given up rather than the text
    // -- it is pushed to whichever side had more room and pinned flush
    // against that edge, fully readable, covering part of the row it
    // explains. Covering the row is the cheaper loss: the row is still under
    // the pointer, the note is the thing being read, and it goes away the
    // moment the pointer leaves. Being sliced in half, which is what happened
    // before, is not readable at all.
    //
    // Not expected to fire in the settings window -- it needs a viewport of
    // roughly 150px -- but the day it does it should degrade, not tear.
    readonly property real roomBelow: root.viewport
        ? root.viewport.height - (root.viewportY + root.belowY) : 0
    readonly property real roomAbove: root.viewport
        ? root.viewportY + root.anchorY - root.gap : 0

    y: {
        if (root.fitsBelow)
            return root.belowY;
        if (root.fitsAbove)
            return root.aboveY;
        return root.roomBelow >= root.roomAbove
            ? root.viewport.height - root.viewportY - root.height   // flush bottom
            : -root.viewportY;                                      // flush top
    }

    implicitWidth: Math.min(label.implicitWidth + Theme.groupPadding * 2, maxWidth)
    implicitHeight: label.implicitHeight + Theme.groupPadding

    radius: 10
    color: Theme.surfaceContainerHighest
    border.width: 1
    border.color: Theme.outlineVariant

    // Above the rows it overlaps, including the one below it in the card.
    z: 100

    // AND `z: 100` IS NOT ENOUGH FOR A FLIPPED ONE, which is the half of this
    // fix that a screenshot found and arithmetic did not. `z` orders an item
    // among its own SIBLINGS and nothing else, so 100 wins inside the row and
    // buys nothing outside it -- and everything outside it is stacked on the
    // assumption that a note only ever hangs DOWNWARDS. SettingsSection gives
    // its rows a descending z so that a note covers the rows BELOW it, and
    // SettingsPage does the same to the sections for the same reason. Both
    // comments say so in as many words. Flip the note and both work against
    // it: the row above has the higher z, so it paints last, and its label
    // came through the middle of the note. Photographed on a probe holding
    // three real SettingsSections -- the word "Filler" sat across the second
    // line of a flipped note.
    //
    // So while a note is up AND flipped, every item between it and the
    // viewport is lifted over its own siblings, which is the smallest change
    // that makes the whole path win: the row over the rows above it, the card
    // over its heading, the section over the section before it. A Binding per
    // ancestor rather than an assignment, so that dropping the note puts each
    // `z` back where it was without this file having to remember them.
    //
    // 1000 because the restacks assign a z equal to a child count -- thirteen
    // sections at the most in this window -- and this has to clear all of
    // them. Nothing else in the shell assigns a z anywhere near it.
    //
    // ONLY WHILE FLIPPED. An unflipped note wants exactly the stacking the
    // two restacks already give it, and lifting the row would break the case
    // that has always worked to fix the one that never did.
    Instantiator {
        active: root.visible && root.flipped
        model: root.ancestry

        delegate: Binding {
            required property var modelData

            target: modelData
            property: "z"
            value: 1000
            restoreMode: Binding.RestoreBindingOrValue
        }
    }

    visible: opacity > 0
    opacity: root.shown ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: Theme.recolorDuration }
    }

    Text {
        id: label

        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.maxWidth - Theme.groupPadding * 2)

        wrapMode: Text.WordWrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize - 1
        color: Theme.textOnSurface

        Behavior on color {
            ColorAnimation { duration: Theme.recolorDuration }
        }
    }
}
