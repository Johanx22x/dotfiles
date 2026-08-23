// One notification. THIS IS THE HALF THE PANEL SEES; the card is in
// themes/<theme>/components/NotificationCard.qml.
//
// WHAT IS LEFT HERE IS THE SPEC, and that is the whole of the line this split
// draws. Everything below is a fact about the desktop notification protocol or
// about the sending application: which timeout applies at which urgency, what
// the two magic values mean, when the clock runs, and the difference between
// telling an application the user closed its notification and letting it
// expire. A theme decides what a notification LOOKS like. It does not get to
// decide when one goes away, and it does not get to decide what the sender is
// told when it does.
//
// IT MOVED UP OUT OF THE THEME TO GET HERE. This file used to be
// themes/genesis/notifications/NotificationCard.qml -- one file, spec and
// pixels together -- which meant a second theme would have had to reimplement
// the paragraph below correctly, in full, to avoid shipping a panel that never
// cleared itself. That is not a thing to ask of a theme.
//
// Clicking the card dismisses it. That is `dismiss()` and not `expire()`:
// dismissing tells the sending application the user closed it deliberately,
// which is what lets apps like Discord stop re-sending the same thing. The
// theme calls the function below; the distinction stays here.

import Quickshell.Services.Notifications
import QtQuick
import qs
import qs.modules

Item {
    id: root

    required property Notification notification

    // WRITABLE, AND THE THEME DOES NOT WRITE IT. Rule 4 in
    // themes/genesis/components/README.md is that a theme reads `row` and never
    // assigns to it, so the chevron calls toggleExpanded() below rather than
    // flipping this. It stays a plain property because it is also the only
    // state on this card a CALL SITE could reasonably want to set -- a history
    // view opening one card already open, say -- and because the clock a few
    // lines down is bound to it.
    property bool expanded: false

    // How long this card stays up, in MILLISECONDS.
    //
    // expireTimeout is already in milliseconds -- `notify-send -t 2000`
    // arrives here as 2000. An earlier version multiplied it by 1000 "to
    // convert from seconds", which turned every explicit timeout into a
    // little over half an hour. That is why notifications piled up and never
    // left: the only ones that expired were the ones asking for the default.
    //
    // The two special values come from the desktop notification spec:
    //   -1  the sender has no opinion -> ours
    //    0  "never expire"
    //
    // "Never" is NOT honoured. Applications reach for it far too easily
    // (browser notifications especially) and the result is a panel that only
    // grows. Every setting below is bounded at both ends, so even something
    // important eventually clears itself.
    //
    // ONE DEFAULT PER URGENCY, and this is where the file changed its mind.
    // It used to say that critical did not follow the setting, because "how
    // long do I want to read a chat notification" is not an answer to "how
    // long should the recorder's failure stay up". Those are still two
    // different questions -- which is the argument for giving them two
    // different ANSWERS, not for hardcoding one of them. A number written
    // into the source is not an answer to a question nobody can ask; it only
    // makes the question unaskable. So the settings page asks all three and
    // each urgency carries its own number.
    //
    // The old behaviour is what the defaults still are: 10 seconds for low
    // and normal, 30 for critical. Nothing moves until somebody moves it.
    //
    // Anything the spec does not define falls to normal, which is the closest
    // true answer for an urgency this shell has never heard of.
    readonly property int timeoutSeconds: {
        switch (root.notification.urgency) {
        case NotificationUrgency.Low:
            return Config.notificationTimeoutLow;
        case NotificationUrgency.Critical:
            return Config.notificationTimeoutCritical;
        default:
            return Config.notificationTimeout;
        }
    }

    // SECONDS in Config and multiplied HERE -- the one place in the shell
    // that conversion happens, so there is one place to get it wrong. Three
    // settings and still one `* 1000`.
    readonly property int timeout: {
        const asked = root.notification.expireTimeout;
        if (asked > 0)
            return asked;
        return root.timeoutSeconds * 1000;
    }

    // Read by the theme to draw the outline. It is on this side because
    // "critical" is the spec's word and the spec's enum, not a style: a theme
    // that had to spell out `notification.urgency === NotificationUrgency.Critical`
    // would be a theme that had to import the notification service.
    readonly property bool critical: root.notification.urgency === NotificationUrgency.Critical

    // THE TWO THINGS A THEME MAY ASK FOR, and they are functions rather than
    // properties for the reason rule 4 gives: a card takes a value and emits a
    // request to change it, so there is one writer to each.
    //
    // dismiss() is the one that carries the argument at the top of this file.
    // The theme puts a MouseArea over the card; which of the service's two
    // closures that click means is decided here.
    function dismiss(): void {
        root.notification.dismiss();
    }

    function toggleExpanded(): void {
        root.expanded = !root.expanded;
    }

    // THE PANEL'S NUMBER AND NOT THE CARD'S, which is why the width does not
    // come back across the seam the way Chip's does. themes/genesis/notifications/
    // Notifications.qml builds its window, its left margin and the x every card
    // slides in from out of Theme.notificationWidth; a card that chose its own
    // width would leave the panel drawn around a different one. Rule 2 holds:
    // the theme is filled to this and reports no width back.
    implicitWidth: Theme.notificationWidth

    // THE THEME DRIVES THE HEIGHT, WITH A FLOOR UNDER IT -- a card that wraps
    // its body to four lines is a height only the theme can compute. The floor
    // is the same one every other facade uses and it is here for the same
    // second reason: a root Item whose author forgot `implicitHeight` reports
    // 0, nothing warns, and a stack of zero-height cards draws every
    // notification on top of the one below it. Read off the Loader rather than
    // `Loader.item` -- see ToggleRow for the [missing-property] that costs.
    implicitHeight: Math.max(Theme.groupHeight, drawing.implicitHeight)

    // EXPANDED MEANS THE USER IS READING IT, so the clock stops; collapsing it
    // again starts a fresh one. The Timer is on this side with the numbers it
    // counts -- a theme that owned it could not be wrong about the shape of a
    // card without also being wrong about when notifications leave the screen.
    Timer {
        running: !root.expanded
        interval: root.timeout
        onTriggered: root.notification.expire()
    }

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/NotificationCard.qml")

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
