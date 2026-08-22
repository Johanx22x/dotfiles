// The bar that says there is more, and how much further down you are.
//
// Hand-drawn, for the same reason the volume slider and the switches are: a
// QtQuick.Controls ScrollBar arrives with its own style, and putting that back
// into this palette is more code than the two rectangles below. Nothing else
// in this shell imports Controls either.
//
// IT ANSWERS TWO QUESTIONS, and the view underneath cannot answer either on
// its own. "Is there more below" -- a row cut off by the bottom edge looks
// exactly like a row that happens to end there, which is how a package list
// that was missing nothing read as a package list missing Steam. And "how far
// down am I" -- twenty entries of the same shape scroll past with no landmark,
// so without this the list feels like it is going nowhere.
//
// IT DISAPPEARS WHEN EVERYTHING FITS. A bar that is always full height is a
// control that says nothing and takes up room saying it, and it would also
// answer the first question wrong: the point of drawing it is that its
// presence alone means "there is more", so it must not be present otherwise.
//
// WHERE IT GOES IS THE CALL SITE'S CHOICE, because what is beside a scrolling
// view differs and the bar must not cover anything that carries information.
// Two placements are in use:
//
//   IN A MARGIN THAT IS ALREADY THERE -- the settings window's page pane and
//   its navigation rail both sit inside a padding that is empty by
//   construction, so the bar lives in it and overlaps nothing at all.
//
//   OVER THE INSIDE EDGE -- lists whose rows already run the full width, where
//   there is no spare strip to move into. Every one of those rows is a card
//   with at least groupPadding of its own before any text or control starts,
//   so four pixels of bar land on card, never on content. Reserving a strip
//   instead is not available to those: the contents are bound to the
//   Flickable's own width, not to contentWidth, so narrowing the content means
//   editing every call site -- and it would take the strip back the moment the
//   last row was removed, moving every remaining row sideways.
//
// WHAT IT MAY ANCHOR TO DEPENDS ON THE VIEW'S TYPE, and this is not a detail:
// get it wrong and the bar travels with the scroll it is supposed to be
// reporting.
//
// A plain Flickable's default property is `flickableData`, so a bar declared
// inside one becomes a child of the contentItem -- the item that moves. Such a
// call site either anchors from outside the view entirely, or stays inside and
// gives the scroll back with `y: view.contentY`. ScrollList.qml is a Flickable
// and does the second.
//
// ListView and GridView override that default property back to plain `data`,
// so a bar declared inside one of THOSE is a child of the view item, which
// does not move: it can anchor to `parent` and be done. Copying the
// Flickable's `y: view.contentY` into one of them cancels nothing, because
// nothing moved it -- it shoves the bar down by the whole scroll until the
// view's own clip eats it. Check which kind of view you are in before copying
// a placement from another call site.
//
// THE SAME CHOICE ALSO DECIDES WHO IS ON TOP, and that is what says whether
// any of the widening below is reachable at all. In a ListView or a GridView
// the bar is a later sibling of the contentItem, so it is above the rows and
// takes what it overlaps. In ScrollList the bar is declared in the base
// document and the call site's Column is appended to the same `flickableData`
// afterwards, so the ROWS are above the bar: a call site whose rows carry a
// full-width MouseArea takes every press across the list, this bar included,
// and it is drawn but cannot be grabbed. Five of ScrollList's seven do
// exactly that. Measured, not read off the docs, in tests/scrollbar-target.py
// -- and it is the reason those seven never suffered the fault the rail and
// the launcher did, rather than any care taken about their margins.
import QtQuick
import qs

Rectangle {
    id: root

    // What this describes and drives. Required rather than defaulted: a bar
    // with no view behind it has no length to draw and no position to point
    // at, and would silently draw a full-height track over anything.
    required property Flickable view

    width: 4
    radius: width / 2

    // A say for the call site, ANDed with the rule below rather than replacing
    // it. A host that draws its own bar somewhere better -- the cheatsheet
    // does -- needs to silence the one it would otherwise get, and doing that
    // by overwriting `visible` would make it restate when a bar is warranted
    // at all, which is the one piece of this that should live in exactly one
    // place.
    property bool wanted: true

    // FOUR CONDITIONS AND NOT ONE. There is more than the view can show, is
    // the point of it. The view is on screen, because a bar for a hidden list
    // is a bar floating over whatever the list was hiding behind -- the
    // cheatsheet hides its list outright on a compositor that cannot report
    // binds. And the view has a height at all: a collapsed list keeps the
    // contents it will show when it opens, so `contentHeight > height` is
    // perfectly true of a pack nobody has opened yet.
    visible: root.wanted && root.view.visible && root.view.height > 0
        && root.view.contentHeight > root.view.height

    color: Qt.alpha(Theme.outlineVariant, 0.5)

    Behavior on color {
        ColorAnimation { duration: Theme.recolorDuration }
    }

    Rectangle {
        id: thumb

        // As tall a share of the track as the visible part is of the whole,
        // with a floor: proportional alone means fifty entries leave a
        // four-pixel dot, which is a position indicator you have to hunt for.
        height: Math.max(30, root.height * root.view.visibleArea.heightRatio)

        // The floor is also why the position is not simply
        // `yPosition * track.height`: once the thumb is taller than its share
        // it has less room to travel than the content does, so the scroll
        // position is mapped onto the travel that is actually left. Without
        // that the bar reaches the bottom before the view does.
        y: {
            const travel = root.height - thumb.height;
            const range = 1 - root.view.visibleArea.heightRatio;
            if (travel <= 0 || range <= 0)
                return 0;
            const progress = Math.max(0, Math.min(1, root.view.visibleArea.yPosition / range));
            return progress * travel;
        }

        width: parent.width
        radius: parent.radius

        // Brighter while it is being used -- moved, dragged or pointed at --
        // and quiet the rest of the time. At rest this is a hint about the
        // shape of the view; in the hand it is a control, and the two should
        // not look the same.
        //
        // Both `moving` and the velocity are asked, because they do not cover
        // the same gestures: `moving` is a drag or a flick, and a wheel notch
        // on a desktop is neither -- it moves the view without ever putting
        // the Flickable into that state.
        color: root.view.moving || root.view.verticalVelocity !== 0 || scrollMouse.pressed || scrollMouse.containsMouse
            ? Theme.primary
            : Theme.outline

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }
    }

    // How far past the bar a press still counts, AND IT IS TWO NUMBERS,
    // BECAUSE THE TWO SIDES ARE NOT ALIKE. Four pixels is the right width to
    // LOOK at and an unfair thing to ask anyone to hit, so the target is
    // widened -- but one side of it faces the view this bar is drawn over,
    // where every pixel taken is a pixel some row stops hearing, and the
    // other faces whatever the call site put the bar into, which in this tree
    // is either padding that is empty by construction or a clip that throws
    // the pixels away. One number for both is what made the widening a defect
    // twice, in the settings rail and then in the launcher grid: a single
    // margin can only be as large as the tighter side allows, so it is either
    // too small to hit or it eats the rows beside it, and there is no value
    // that is neither.
    //
    // INWARD MEANS LEFTWARD, because every bar in this tree hangs on the
    // right-hand edge of the thing it describes. A bar down a left-hand edge
    // would want the two swapped and there is none; if one is ever added,
    // this is the place to teach about it rather than the call site.
    //
    // THREE INWARD, which is what both of the call sites that used to
    // override the old single margin were asking for, and neither has to ask
    // any more. Measured offscreen, on the launcher's grid geometry -- three
    // columns of 260 with the bar hard against the right edge at x=779 --
    // pressing a third-column row across the last pixels of its width:
    //
    //   inward   the app hears the press   the bar takes it
    //   7        up to x=768               769 to 779
    //   3        up to x=772               773 to 779
    //
    // ELEVEN OUTWARD, which is not a taste: 3 + 4 + 11 is the eighteen pixels
    // the old seven-on-both-sides gave, moved to the side that can afford it.
    // Where a clip meets the bar's outer edge -- ScrollList, the launcher
    // grid, the clipboard list -- all eleven are discarded and the target is
    // the seven that are left, which is what those sites already had. Where
    // nothing clips, all eleven are live and land on padding: the cheatsheet
    // keeps thirteen pixels of card outside the bar, the notification history
    // twelve of panel, and the rail's bar reaches four pixels short of the
    // page pane through window padding that holds nothing.
    //
    // Measured rather than reasoned, because Qt's rule here is not the
    // obvious one: a press target is bounded by a CLIPPING ancestor and by
    // nothing else, so an unclipped parent does NOT stop a child's MouseArea
    // reaching past it. The launcher's grid answers to x=779 with its clip on
    // and to x=790 with it off, on the same geometry and the same margins --
    // tests/scrollbar-target.py holds both, and the first is the only reason
    // the outward side is free to be this wide.
    property int grabMarginInward: 3
    property int grabMarginOutward: 11

    // WIDER ONLY, never taller. Growing it vertically as well would move this
    // item's origin above the track, and `mouse.y` is measured from that
    // origin -- so every position below would be off by the overhang and the
    // thumb would sit seven pixels from where it was grabbed. Widening the
    // two sides by different amounts is safe for exactly the same reason
    // read the other way: `mouse.x` is not read at all, so where the left
    // edge sits changes nothing about where the thumb lands.
    MouseArea {
        id: scrollMouse

        anchors.fill: parent
        anchors.leftMargin: -root.grabMarginInward
        anchors.rightMargin: -root.grabMarginOutward

        // Only while there is something to drive. An invisible bar's mouse
        // area would still take the press, leaving a dead strip down the edge
        // of every view that fits.
        enabled: root.visible

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Press jumps and drag follows, which is what the volume slider does
        // and for the same reason: one gesture, and no dead zone on the track
        // where nothing happens.
        //
        // The pointer is treated as the MIDDLE of the thumb, so what you
        // pressed on ends up under your finger rather than starting there and
        // sliding down by half a thumb.
        function scrollTo(y: real): void {
            const travel = root.height - thumb.height;
            if (travel <= 0)
                return;
            const progress = Math.max(0, Math.min(1, (y - thumb.height / 2) / travel));
            root.view.contentY = progress * (root.view.contentHeight - root.view.height);
        }

        onPressed: mouse => scrollMouse.scrollTo(mouse.y)
        onPositionChanged: mouse => {
            if (pressed)
                scrollMouse.scrollTo(mouse.y);
        }
    }
}
