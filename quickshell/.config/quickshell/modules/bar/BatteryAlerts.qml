// One battery warning per machine, however many bars are on screen.
//
// NOTHING WITH BRACES MAY GO ABOVE `pragma Singleton`, WHICH IS WHY THE
// EXPLANATION IS BELOW THE IMPORTS. In Quickshell 0.3.0 a comment containing a
// curly brace anywhere above the pragma stops the file being registered as a
// singleton, and it fails in the worst possible way: the type still resolves,
// the linter finds nothing, "Configuration Loaded" is printed, and every
// property and function on it is simply missing. (The linter has to be
// mentioned that way round, incidentally: a comment whose first word is the
// name of the tool is read by it as a lint directive, and it answers with a
// dozen complaints about unknown categories.) This file was written with the
// usual long header first and the shell said
//
//     TypeError: Property 'isAlerting' of object BatteryAlerts is not a
//     function
//
// with nothing pointing at the cause. Keep prose that needs an example of QML,
// JSON or KDL under the imports.

pragma Singleton

import Quickshell

// WHY THIS IS A SINGLETON AND NOT A PROPERTY ON A WIDGET, which is the whole
// reason the file exists. shell.qml builds a Bar per screen -- `Variants {
// model: Screens.barScreens }` -- and every Bar carries its own SystemBattery
// and its own PeripheralBattery. The "already warned about this one" state
// used to live inside each of them: `property var alerted: ({})` in the
// peripheral widget, `property bool warned: false` in the system one. Two bars
// therefore meant two copies of that state, two copies that had never heard of
// each other, and two `notify-send --urgency=critical` for one mouse going
// flat.
//
// AND CRITICAL NOTIFICATIONS DO NOT EXPIRE -- see the header of
// NotificationCard.qml, where that is deliberate and right. So the duplicate
// does not fade out a few seconds later: both cards sit on the screen until
// both are dismissed by hand, and the second one says exactly what the first
// one said.
//
// THE READINGS STILL COME FROM THE WIDGETS. They are the ones with a UPower
// device list and a file full of AirPods percentages, and moving all of that
// in here would be a much larger change to fix a much smaller thing. What
// moves is the decision and the sending. Being called twice with the same
// reading, once per bar, is the normal case and the second call is a no-op --
// which is precisely the point.
//
// A SINGLETON IS BUILT ONCE PER SHELL PROCESS, so this state also survives a
// monitor being unplugged and its bar being destroyed. The old per-widget flag
// did not: losing the bar re-armed the warning for a battery that was still
// just as flat.

Singleton {
    id: root

    // WHEN TO SHOUT, ONE DECISION FOR BOTH WIDGETS. The two files already
    // agreed on these two numbers -- 15 and 20, written out twice -- so there
    // is nothing to reconcile here, only somewhere to say it once. What stays
    // in each widget is `warnBelow`, the point at which the reading merely
    // goes amber: that one they disagree about on purpose (30 for a
    // peripheral, 25 for the machine) because it is a matter of taste about
    // colour rather than a decision to interrupt somebody.
    readonly property int alertBelow: 15

    // Higher than alertBelow on purpose. A battery sitting exactly on the
    // threshold flickers across it as the reading settles, and without a gap
    // between "start warning" and "stop warning" that flicker is a
    // notification every few minutes.
    readonly property int rearmAt: 20

    function isAlerting(charge: int, charging: bool): bool {
        // CHARGING BEATS EVERYTHING. A mouse on its cable at 8% is not a
        // problem, and warning about one is how a warning stops being
        // believed.
        return !charging && charge <= root.alertBelow;
    }

    // Which keys have an outstanding warning. Mutated in place rather than
    // reassigned whole: nothing binds to this -- it is state, not a source --
    // and the copy-on-write dance the peripheral widget does with its own maps
    // is there because delegates DO bind to those. If anything ever binds to
    // this, it has to go back to assigning a new object.
    property var alerted: ({})

    // Called by a battery widget on every reading, from every bar. The reading
    // is one object rather than five arguments because that is what the
    // peripheral widget already has in its hand -- one entry out of its list.
    //
    //   key          stable per device, and the same string from every bar
    //   label        what to call it in the notification
    //   charge       whole percent
    //   charging     on a cable, or full
    //   secondsLeft  UPower's estimate, 0 when there is none
    function consider(reading: var): void {
        const key = reading?.key ?? "";
        if (key === "")
            return;

        // Back above the re-arm line, or on a cable: forget it happened, so
        // the next time it runs down there is a warning again.
        if (reading.charging || reading.charge >= root.rearmAt) {
            delete root.alerted[key];
            return;
        }

        if (!root.isAlerting(reading.charge, reading.charging) || root.alerted[key])
            return;

        root.alerted[key] = true;

        // notify-send and not a call into this shell's own notification model:
        // the shell IS the notification daemon, so this goes out over the bus
        // and comes straight back in as an ordinary notification -- which
        // means it looks like every other one, stacks with them, and obeys
        // do-not-disturb. A private code path would bypass all three.
        Quickshell.execDetached(["notify-send",
            "--urgency=critical",
            "--app-name=Battery",
            `${reading.label} is at ${reading.charge}%`,
            root.detail(reading.secondsLeft ?? 0)]);
    }

    // ONE WORDING, AND THIS IS WHERE THE TWO OLD ONES ARE RECONCILED.
    //
    // They had drifted into saying the same thing differently: the peripheral
    // widget sent "<name> is at 12%" over "Put it on the cable before it
    // stops.", and the system one sent "Battery at 12%" over "About 25 min
    // left." or "Find a cable.". Same event, same urgency, two shapes.
    //
    // The title comes from the peripheral side -- "Battery is at 12%" reads
    // as well for the machine as "Logitech PRO X 2 is at 12%" does for a
    // headset, and it puts the thing before the number, which is the order
    // somebody glancing at a notification stack needs.
    //
    // The body keeps the estimate, which came from the system side and is the
    // more useful half whenever UPower has one: "about half an hour" is what
    // decides whether you go and find the cable now. The instruction survives
    // as the fallback for the many devices that report no estimate at all --
    // every AirPod, and any mouse UPower has not watched for long enough.
    //
    // FORMATTED FROM SECONDS HERE rather than taking each widget's own
    // sentence, because taking the sentence is exactly how the two drifted:
    // one of them prefixes "About" and the other does not, and both strings
    // are also drawn on screen where they are already right. This is the
    // notification's own wording and nothing else reads it.
    function detail(secondsLeft: int): string {
        if (!secondsLeft || secondsLeft <= 0)
            return "Put it on the cable before it stops.";

        const hours = Math.floor(secondsLeft / 3600);
        const minutes = Math.round((secondsLeft % 3600) / 60);
        const spelled = hours > 0 ? `${hours} h ${minutes} min` : `${minutes} min`;

        return `About ${spelled} left. Put it on the cable.`;
    }
}
