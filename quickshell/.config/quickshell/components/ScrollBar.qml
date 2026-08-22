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
import QtQuick
import "root:/"

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

    // How far past the bar a press still counts. Four pixels is the right width
    // to LOOK at and an unfair thing to ask anyone to hit, so the target is
    // widened -- but ONLY INTO SPACE THE CALL SITE ACTUALLY HAS, which is why
    // this is a property and not the seven it used to be everywhere.
    //
    // SEVEN IS FOR A BAR WITH ROOM ON BOTH SIDES. The page pane and the search
    // results have it: they sit in the window's own groupPadding, and every
    // card inside them keeps twelve pixels of its own before any control, so
    // eighteen pixels of target land on padding either way.
    //
    // THE RAIL DOES NOT, and passes 3. Its channel is ten pixels wide in
    // total and its entries run right up to the edge of it, with no padding of
    // their own to spend -- so seven reached four pixels back over every row.
    // Measured on the real rail, offscreen, pressing a row at four heights of
    // the pointer: at x=194 the entry is selected, at x=197 and x=199 the
    // entry hears nothing and the list jumps to where the bar was pressed.
    // Which is a settings window where the right-hand edge of every
    // navigation entry silently scrolls instead of opening anything.
    property int grabMargin: 7

    // WIDER ONLY, never taller. Growing it vertically as well would move this
    // item's origin above the track, and `mouse.y` is measured from that
    // origin -- so every position below would be off by the overhang and the
    // thumb would sit seven pixels from where it was grabbed.
    MouseArea {
        id: scrollMouse

        anchors.fill: parent
        anchors.leftMargin: -root.grabMargin
        anchors.rightMargin: -root.grabMargin

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
