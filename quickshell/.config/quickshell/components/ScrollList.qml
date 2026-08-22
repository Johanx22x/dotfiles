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
// THE WHEEL WAS HALF OF IT, and shipping that half alone did not fix the
// complaint. A DRAG puts the view into the same state and the handler below
// does nothing about it: press the list, pull it up, let go, and the
// Flickable is still `moving` for the best part of a second afterwards --
// during which its child event filter takes every press away from the rows
// inside it, exactly as the wheel animation did. So dragging is off; see
// `interactive` below for what that costs and what it does not.
//
// MEASURED, Qt 6.11.2, offscreen, against the settings rail's real geometry
// -- an 820x580 window, a 452px list over 530px of entries -- by scrolling to
// the bottom and clicking the entry that is only reachable that way, at four
// delays after the gesture:
//
//                                  0 ms   100 ms  300 ms  600 ms
//     plain Flickable, wheel        lost    lost    lost   lands
//     this, wheel                  lands   lands   lands   lands
//     this, drag or flick, before   lost    lost    lost   lands
//     this, drag or flick, after   the gesture is gone, so there is no
//                                  click left to lose
//
// It cost two rounds. The rail's Updates and About entries are the only two
// anybody reaches by scrolling, so a window-wide effect was reported, and
// hunted twice, as two pages refusing to open on the first click -- the first
// time it was blamed on the wheel alone, on a bench that only ever sent wheel
// events.

import QtQuick
import "root:/"

Flickable {
    id: root

    // Always the full width -- these are lists of rows, never side to side.
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // NOT DRAGGABLE, AND THAT IS THE POINT. `interactive` is what turns a
    // press-and-pull into a scroll, and it is the same switch that makes
    // QQuickFlickable filter the presses of everything inside it: while
    // `moving` is true -- which it stays for the best part of a second AFTER
    // a drag ends, not merely during it -- each press is taken from the row
    // underneath so that the gesture can be continued instead of interrupted.
    // That is the right call for a finger and the wrong one for a mouse, and
    // this shell is only ever driven by a mouse: there is no touchscreen, and
    // InputPage says in its own header that there is no touchpad on this
    // machine either.
    //
    // WHAT IS LOST is grabbing a list and pulling it. WHAT IS KEPT is
    // everything that actually moves these views: the wheel, through the
    // handler below, which does not go through `interactive` at all; and the
    // scrollbar, which writes contentY straight in from a MouseArea that
    // lives outside the view. Both were driven at the rail at 0, 100, 300 and
    // 600 ms after the scroll, and the click lands every time.
    //
    // THE HAND-BACK IS UNCHANGED, which is what this file exists for and so
    // the thing to check hardest. Wheeling over a capped list that can still
    // move moves the list and leaves the page under it alone; wheeling over
    // one that cannot move moves the page instead. Both measured either side
    // of this line, and both give the same numbers -- with dragging off, the
    // wheel event a disabled handler declines is declined by the Flickable
    // too, and reaches the page the same way it did before.
    //
    // IF A TOUCH DEVICE EVER ARRIVES this is the line to revisit, and the
    // answer then is not simply to delete it: the wheel handler below only
    // accepts a real mouse (WheelHandler defaults to acceptedDevices: Mouse
    // and drops anything Qt marks as synthesized), so a touchpad already
    // falls through to the Flickable and would need that widened first.
    interactive: false

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
    readonly property bool scrollable: root.contentHeight > root.height

    // Whether this draws its own bar. On by default: every list this component
    // exists for is a list of things the machine happens to have, where "is
    // that all of them" is the question being asked, and a call site that has
    // to remember to ask for the answer is a call site that will forget.
    //
    // OFF IS FOR A CALL SITE THAT PLACES ITS OWN, and there is exactly one --
    // the cheatsheet. Its contents are columns of a FIXED width rather than
    // rows bound to this item's, so the four pixels that land on card padding
    // everywhere else would land on the last column's key names; and its card
    // already keeps thirty pixels of padding outside this, which is a better
    // place for a bar than on top of anything. Off there means "somewhere
    // better", not "never".
    property bool showScrollBar: true

    WheelHandler {
        enabled: root.scrollable

        onWheel: event => {
            const limit = Math.max(0, root.contentHeight - root.height);
            root.contentY = Math.max(0, Math.min(limit,
                root.contentY - event.angleDelta.y));
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
    // no way to narrow the content from in here at all, and the seven call
    // sites that would have to be edited include one this branch must not
    // touch.
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
