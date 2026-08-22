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

import QtQuick
import "root:/"

Flickable {
    id: root

    // Always the full width -- these are lists of rows, never side to side.
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // NO `visible: height > 0` HERE, however tidy it looks. `visible` in QML
    // is effective visibility: hiding this hides every delegate, an invisible
    // child contributes nothing to a Column's implicitHeight, the height it
    // is given goes to zero and the list is held shut forever. Measured on a
    // stripped copy of exactly this arrangement -- with the line in, adding
    // three rows to an empty hidden list left implicitHeight at 0.
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
