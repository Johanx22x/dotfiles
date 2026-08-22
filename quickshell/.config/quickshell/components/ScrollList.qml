// A list with a ceiling on it, inside a page that also scrolls.
//
// THE WHOLE FILE EXISTS FOR ONE BUG: turning the wheel over one of these
// moved the list AND the page underneath it at the same time, so a device
// four rows down walked away from the pointer while it was being aimed at.
// Two scroll surfaces stacked on one another is the only place in this window
// where that can happen, and every one of them is this shape -- a capped list
// of things the machine happens to have.
//
// THE RULE IS: WHILE THE POINTER IS OVER A LIST THAT CAN MOVE, THE LIST GETS
// THE WHEEL. Not "the list until it reaches its end, then the page", which is
// the other obvious design and is worse in practice: it means a single flick
// scrolls the list to the bottom and then throws the page, so where you end
// up depends on how hard you spun the wheel. Capturing outright is what every
// desktop list does, and moving the pointer off the card is a smaller ask
// than aiming a scroll.
//
// The handler is DISABLED when there is nothing to scroll, which is what
// hands the event back to the page: a list of two devices inside a 150px
// ceiling is not a scroll surface at all, and swallowing the wheel there
// would leave a dead patch on the page.
//
// A SECOND REASON, FOUND LATER, AND IT IS WHY THIS IS NOW THE ONLY SCROLLING
// VIEW IN THE SETTINGS WINDOW. Taking the wheel by hand also keeps the click
// that follows it. A Flickable left to answer the wheel itself starts a
// scroll animation, and while that animation runs it takes the next mouse
// press in order to stop the flick -- QQuickFlickable does this on purpose,
// so that a press lands on a moving list rather than on whatever happened to
// slide under the pointer -- and the item beneath never hears about the press
// at all. On a list that is dragged, that is right. On a list that is only
// ever wheeled and clicked, it means the first click after every scroll is
// thrown away.
//
// THAT PARAGRAPH WAS TRUE AND FOR A LONG TIME IT DID NOTHING, which is the
// part worth remembering. The handler below declined every wheel event this
// machine produced -- see the note on `acceptedDevices` -- so the Flickable
// went on doing the scrolling and went on eating the click, and the component
// written to stop it had never once run. The measurement that said it worked
// was taken offscreen, where Qt hands out a device typed Mouse and the
// handler accepts; a Wayland seat hands out one typed TouchPad and it does
// not. A bench that cannot produce the machine's own event is a bench that
// agrees with you.
//
// MEASURED, Qt 6.11.2, offscreen, against the settings rail's real geometry
// -- an 820x580 window, a 452px list over 530px of entries -- clicking the
// entry that is only reachable by scrolling, at 0, 100, 300 and 600 ms after
// the gesture, and driven through a device the handler accepts AND one it
// declines:
//
//     wheel, handler accepting     lands at all four
//     wheel, handler declining     lost at 0 and 100, before this change
//     drag or flick                lost at 0, 100 and 300, before this change
//     the scrollbar                lands at all four, throughout
//
// It cost three rounds and one broken settings window. The rail's Updates and
// About entries are the only two anybody reaches by scrolling, so a
// window-wide effect kept being reported as two pages refusing to open.
//
// `visible: height > 0` ON ONE OF THESE IS A QUESTION ABOUT WHERE THE
// HEIGHT COMES FROM, and that answer is the whole of it. This header used
// to forbid the line outright and was overstated: five call sites carried
// it anyway and not one of them was broken, which is how a rule in
// capitals teaches the next reader that the capitals can be ignored.
//
// Two things are true and neither latches anything alone. `visible` in
// QML is EFFECTIVE visibility, so hiding one of these hides every delegate
// under it. And an invisible child contributes nothing to the
// implicitHeight of a Column it sits in. The latch needs a third thing --
// THE HEIGHT HAS TO COME BACK DOWN FROM THE PARENT THAT WAS JUST SHRUNK.
//
// SO DO NOT WRITE IT ON A LIST SIZED BY ITS PARENT. `Layout.fillHeight:
// true` in a ColumnLayout, or a height bound to the implicitHeight of the
// very Column this sits in: the list hides, the parent loses its only tall
// child, zero comes back down, and nothing ever reopens it. Both shapes
// were built to check, and they are worse than described -- neither
// survives its first layout, so such a list is born shut rather than
// latched by some later sequence.
//
// IT IS SAFE ON A LIST SIZED BY THE COLUMN INSIDE IT, which is every list
// in this shell. Nothing closes there: a positioner counts a child's own
// `visible` and not the effective one it inherits, so the inner Column
// goes on laying out while hidden and the height comes straight back when
// the rows do. Driven on Qt 6.11.1 in a headless compositor against the
// real pages, not a stripped copy. The keybinds list, emptied by a query
// that matches nothing and refilled by clearing it, over the eighty binds
// read out of the niri config; both bluetooth lists emptied and refilled
// over a STAND-IN model, because emptying the real one means toggling a
// live adapter. Every one came back at full height, including when the
// refill happened with the whole page switched away and invisible.
//
// On most lists it also buys nothing: an empty Flickable is already zero
// pixels tall.

import QtQuick
import "root:/"

Flickable {
    id: root

    // Always the full width -- these are lists of rows, never side to side.
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Is there anywhere to go? This is what enables the wheel handler and
    // what decides whether the bar below is drawn at all.
    readonly property bool scrollable: root.contentHeight > root.height

    // Whether this draws its own bar. On by default: every list this component
    // exists for is a list of things the machine happens to have, where "is
    // that all of them" is the question being asked, and a call site that has
    // to remember to ask for the answer is a call site that will forget.
    //
    // OFF IS FOR A CALL SITE THAT PLACES ITS OWN, and there are four of them.
    // Three are in the settings window -- the rail, the pane the pages sit in
    // and the search results -- and their reason is the same one: the bar for
    // each of those is drawn in the padding that is already beside the list,
    // placed and anchored from OUTSIDE it, so a second one just inside the
    // list's own edge would be a bar drawn twice.
    //
    // The fourth is the cheatsheet, and its reason is its own. Its contents
    // are columns of a FIXED width rather than rows bound to this item's, so
    // the four pixels that land on card padding everywhere else would land on
    // the last column's key names; and its card already keeps thirty pixels of
    // padding outside this, which is a better place for a bar than on top of
    // anything.
    //
    // Off anywhere means "somewhere better", not "never" -- which is why the
    // default is on. A list nobody has placed a bar for still gets one.
    property bool showScrollBar: true

    WheelHandler {
        enabled: root.scrollable

        // EVERY DEVICE, AND THIS LINE IS THE WHOLE OF THE BUG THIS FILE WAS
        // WRITTEN FOR. A WheelHandler defaults to `acceptedDevices: Mouse`
        // and, on top of that, drops any wheel event Qt marks as synthesized
        // -- and a handler that declines an event is a handler that does
        // nothing, so on a machine whose pointer Qt does not type as a mouse
        // this component was, for months, an ordinary Flickable with a dead
        // handler bolted to it. The scrolling still worked, because the
        // Flickable underneath caught everything the handler dropped; what
        // did not work was the one thing the handler is here for, so the
        // click after a wheel notch went on being eaten and the fix that was
        // supposed to stop it had never run.
        //
        // It was found the hard way. Turning `interactive` off to stop a drag
        // stealing the same click took the Flickable away as well, and the
        // settings window stopped scrolling outright -- which is the proof
        // that the handler was never the thing doing the scrolling.
        //
        // AllDevices AND NOT Mouse|TouchPad, because the failure mode of
        // naming device types is silence: nothing is logged, nothing throws,
        // the list simply scrolls through the other path and the click is
        // lost again. There is no device this component wants to refuse.
        // Naming TouchPad is also what lifts the synthesized-source check, so
        // this one line answers both halves.
        acceptedDevices: PointerDevice.AllDevices

        onWheel: event => {
            // angleDelta is what a wheel reports and pixelDelta is what a
            // continuous scroll reports; a device that sends only the second
            // would otherwise be accepted here and then moved by zero, which
            // is the same silence as declining it.
            const step = event.angleDelta.y !== 0 ? event.angleDelta.y
                : event.pixelDelta.y;
            const limit = Math.max(0, root.contentHeight - root.height);
            root.contentY = Math.max(0, Math.min(limit, root.contentY - step));
        }
    }

    // And the bar that says the ceiling is biting. A capped list is the one
    // shape in this shell where a row cut off by the bottom edge looks exactly
    // like the last row, so this is the only thing on screen that distinguishes
    // "eight devices" from "eight devices and more below". It costs nothing on
    // the lists that fit, because it is not drawn there.
    //
    // PLACED AND NOT ANCHORED, and `y` is the whole trick. Anything declared
    // inside a Flickable is parented to its contentItem and scrolls with it,
    // which is the one thing an indicator of position must not do; riding the
    // content back the other way at exactly contentY leaves it standing still
    // over a list that moves. Reparenting it onto the Flickable itself is the
    // other way to get there and does not work from in here: the parent is
    // reassigned after the anchors are read, so all three come out as "Cannot
    // anchor to an item that isn't a parent or sibling" and the bar draws with
    // no height at all. Measured, in a nested compositor, on this exact file.
    //
    // Nothing here is measured off it: contentHeight is the call site's, set
    // from its own Column, so an extra child in the content item changes
    // nothing about how tall the content is.
    //
    // OVER THE INSIDE EDGE, and not in a strip taken out of the width. Every
    // call site binds its content to THIS ITEM's width rather than to
    // contentWidth -- `width: list.width`, `width: parent.width` -- so there is
    // no way to narrow the content from in here at all: narrowing it means
    // editing all eleven call sites, one of them in a module nobody was
    // touching at the time.
    //
    // HARD AGAINST THAT EDGE, with no inset, because the inset is what the
    // rows already leave and moving in from the edge spends it twice. Measured
    // rather than assumed: a bluetooth row ends its "pair" nine pixels short of
    // the list, so four pixels of bar in the last four leave four of clear
    // space, and the same four pixels placed four in from the edge leave none
    // at all -- which is what the first draft of this did, and it read as a bar
    // drawn through the word.
    ScrollBar {
        id: scrollBar

        view: root
        wanted: root.showScrollBar

        x: root.width - width
        y: root.contentY
        height: root.height
    }
}
