// The horizontal slider every volume in this shell is dragged with. THIS IS
// THE HALF THE CALL SITES SEE; the pixels are in
// themes/<theme>/components/VolumeSlider.qml.
//
// IT WAS DRAWN TWICE BEFORE IT WAS A COMPONENT. The island had one and the
// sound page needed four more -- one per output, one per input, one per
// application -- which is the point at which "two rectangles and a MouseArea"
// stops being cheaper than a file.
//
// THE RANGE IS THE CALLER'S. The island passes 1.0 and the sound page passes
// 1.5, and that difference is deliberate rather than an oversight -- see the
// note over the output section in AudioPage.qml. This file only holds what it
// is told and reports where the pointer went; it has no opinion about how loud
// is too loud.
//
// ---------------------------------------------------------------------------
// THE CONTRACT WITH THE THEME IS A FRACTION, AND THAT IS A CHANGE
// ---------------------------------------------------------------------------
//
// Before the split this file had a function that took the pointer's x and
// turned it into a volume:
//
//     const local = x + mouse.anchors.margins;
//     root.moved(Math.max(0, Math.min(1, local / rail.width)) * root.maximum);
//
// Read it again with the seam in mind and both of its terms belong to the
// theme. `mouse.anchors.margins` is -6 because THIS THEME insets its hit area
// by six pixels so a thin rail is not a thin target, and `rail.width` is the
// width of a rectangle THIS THEME draws. A theme that inset by eight, or that
// left a gap at the ends of the rail, or that drew the rail anywhere but hard
// against both edges, would have handed this arithmetic two numbers it was not
// written for and got every value slightly wrong -- silently, because a volume
// that is off by a few percent looks exactly like a volume.
//
// So the direction is reversed. THE THEME SAYS WHERE ALONG ITS OWN RAIL THE
// POINTER IS, AS A NUMBER FROM 0 TO 1, and moveTo() below does the only two
// things that are not the theme's business: clamping it, and multiplying by a
// maximum the theme has no reason to know. The correction for the inset stays
// in the theme, next to the inset, which is the only place it can be right.
//
// THE WHEEL GOES THE SAME WAY AND FOR A SHARPER REASON. The theme owns the
// MouseArea, so the wheel arrives there; but what a notch MEANS -- five
// percent, or nothing at all on a page that scrolls -- is this file's, and so
// is the decline. wheel() below returns whether it took the event, and the
// theme's only job is to hand back what it is given. See that function for
// what an empty handler would cost, which is not nothing.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    // Both in the same units the caller thinks in -- PipeWire's, where 1.0 is
    // 100%. Nothing here converts.
    property real value: 0
    property real maximum: 1

    // A mark drawn across the rail, for a range whose interesting point is
    // not at either end: at 1.0 on a slider that goes to 1.5 it is the line
    // between "as loud as the hardware means" and "gain applied in software".
    // Anything at or below zero draws none.
    property real notch: -1

    property color accent: Theme.primary

    // ---- The two colours that are not the accent ----
    //
    // Parameterised for the dashboard, which draws this slider on a
    // PHOTOGRAPH: there, a role derived from the wallpaper has nothing to do
    // with what is behind the rail. The defaults are exactly the roles that
    // were read in place here before, so the sound page gets the slider it
    // had.
    //
    // THEY ARE API AND THAT IS WHY THEY ARE STILL HERE. Rule 5 of
    // themes/genesis/components/README.md says a theme reads Theme itself
    // rather than being handed tokens -- and it would, for a colour nobody
    // sets. Four call sites set these two, so they are the call site's word
    // and they cross the seam like every other thing a call site said.
    property color railColor: Theme.surfaceContainerHighest

    // The mark reads as a gap cut through the bar rather than as a third
    // colour, so it wants whatever is BEHIND the slider -- the window's own
    // background on a settings page, the scrimmed cover on the dashboard.
    property color notchColor: Theme.surface

    // How far one wheel click moves it, in the same units. Five percent, the
    // step the bar's own wheel handler has always used.
    property real step: 0.05

    // WHETHER THE WHEEL BELONGS TO THE SLIDER AT ALL, and the default is yes
    // because that is where this control came from: on the island it is a
    // popout with nothing behind it to scroll, and turning the wheel over a
    // volume bar is what everyone expects.
    //
    // It is FALSE on the sound page, and the difference is not taste. That
    // page is a Flickable taller than the window, so the wheel over a slider
    // has two possible meanings -- move this value, or move the page -- and
    // the pointer happens to be over a slider on the way past far more often
    // than it is there on purpose. Scrolling down to reach the input devices
    // and arriving with the output volume changed is the bug; the page is the
    // one that gets the wheel there. Same argument as ScrollList.qml, reached
    // from the other side: the rule is that the surface you MEANT to scroll
    // gets the event, and for a slider in a long page that is never the
    // slider.
    property bool wheelEnabled: true

    signal moved(real value)

    // WHERE THE FILL STOPS AND THE HANDLE SITS, as a share of the rail. The
    // theme multiplies this by whatever it drew the rail as; it is here rather
    // than there because the clamp is about the VALUE and not about the
    // pixels. A caller that hands over a volume above its own maximum -- and
    // PipeWire will, for a stream boosted past the range the page offers --
    // gets a full bar and not a handle sitting outside the control.
    readonly property real fraction: root.maximum > 0
        ? Math.max(0, Math.min(1, root.value / root.maximum))
        : 0

    // Twenty is what the slider was before the split, and the floor is what a
    // theme that reported nothing falls back to. See ToggleRow's header for
    // the two ways that happens and for why this reads the Loader rather than
    // `Loader.item`.
    implicitHeight: Math.max(20, drawing.implicitHeight)

    // ---------------- What the theme calls ----------------

    // THE POINTER IS `fraction` OF THE WAY ALONG YOUR RAIL. Everything about
    // where that rail is, how wide it is and how far the hit area sticks out
    // past it belongs to the theme and is applied before this is called; the
    // two things left are the clamp and the range.
    //
    // CLAMPED RATHER THAN MERELY SCALED, and that is not tidiness either. A
    // theme's hit area is wider than the rail it covers -- it has to be, six
    // pixels of it in this one -- so a press at the very start of the rail
    // arrives as a small NEGATIVE fraction and one past the end arrives above
    // 1. Unclamped, the first would ask for a negative volume and the second
    // would overshoot the caller's maximum.
    function moveTo(fraction: real): void {
        root.moved(Math.max(0, Math.min(1, fraction)) * root.maximum);
    }

    // ONE NOTCH OF THE WHEEL, and the answer is whether this slider took it.
    //
    // DECLINED RATHER THAN IGNORED WHEN THE WHEEL IS NOT OURS, and the theme
    // has to honour that answer by assigning it to `event.accepted`. A
    // MouseArea accepts a wheel event whether or not anything handles it, so a
    // theme that called this and threw the result away -- or that left the
    // handler empty on the grounds that there was nothing to do -- would still
    // SWALLOW the notch. What that looks like is not a slider that ignores the
    // wheel: it is a dead patch on the sound page where the page underneath
    // stops scrolling, several rows tall, in the middle of the thing you were
    // scrolling through. Handing it back is what lets the Flickable have it.
    function wheel(deltaY: real): bool {
        if (!root.wheelEnabled)
            return false;

        root.moved(Math.max(0, Math.min(root.maximum,
            root.value + (deltaY > 0 ? root.step : -root.step))));
        return true;
    }

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/VolumeSlider.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()

        // See ToggleRow for why there is no status handler here either.
    }
}
