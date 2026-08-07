// The network page: the radio switch, and everything in range.
//
// THIS IS THE ONE PLACE IN THE SHELL THAT TAKES A PASSWORD. The island's
// WifiControl deliberately refuses to -- it shows what is in range and hands
// anything it does not already know to nm-connection-editor, because a form
// does not belong in a panel that hangs off the bar. A settings window is
// where that job lives, so the inline field below is the payoff for that
// refusal rather than a contradiction of it.
//
// Everything comes off Quickshell's NetworkManager backend: no nmcli is
// spawned, nothing is polled, and the list moves on NetworkManager's own
// signals. `nmcli device wifi list` was used to check what the surrounding
// air actually looks like -- WPA1/WPA2 mixes, a 2.4 and a 5 GHz side of the
// same router, one distant network at 19% -- but no nmcli runs from here.
//
// WHAT IT STILL WILL NOT DO: enterprise (EAP) and hidden networks. Both need
// a full connection profile, and NMSettings is not creatable from QML, so
// there is no honest way to build one here. Those rows say what they are and
// open nm-connection-editor, which is the same answer WifiControl gives and
// for the same reason.

import Quickshell
import Quickshell.Networking
import QtQuick
import "root:/"
import "root:/components"
// SettingsPage lives one directory UP, and QML's implicit import covers a
// file's own directory only -- without this line the root element below is an
// unknown type and the page fails to load. The other three imports are the
// shell-wide ones every file here takes.
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Network"
    glyph: Icons.wifi
    // The words someone would type into the search box and expect to land
    // here, including the ones that appear nowhere on the page: "hotspot" and
    // "ssid" are what a router's label calls these things, "password" is what
    // the field below is for even though the row calls it nothing.
    keywords: ["wifi", "wi-fi", "wireless", "internet", "connection", "network", "ssid", "password", "hotspot", "ethernet"]

    // ---------------- Glyphs that are not in Icons yet ----------------
    //
    // TEMPORARY, and they belong in Icons.qml -- they are here only because
    // that file is being edited elsewhere right now. Move them when it is
    // free; nothing else about them should change.
    //
    // Every codepoint below was read out of the installed font's cmap rather
    // than looked up by name, which is the rule that file's own comments set
    // after two of its entries turned out to be a bluetooth speaker and a
    // shower head:
    //
    //   python3 -c "from fontTools.ttLib import TTFont; \
    //     print(TTFont('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf') \
    //       .getBestCmap()[0xF091F])"
    //
    // The four strength glyphs are consecutive-ish but NOT contiguous -- the
    // alert and lock variants are interleaved between them -- so they cannot
    // be computed from a base codepoint, which is exactly the kind of shortcut
    // that produces a wrong glyph here.
    readonly property string wifi1: String.fromCodePoint(0xF091F)      // nf-md-wifi_strength_1
    readonly property string wifi2: String.fromCodePoint(0xF0922)      // nf-md-wifi_strength_2
    readonly property string wifi3: String.fromCodePoint(0xF0925)      // nf-md-wifi_strength_3
    readonly property string wifiFaint: String.fromCodePoint(0xF092F)  // nf-md-wifi_strength_outline

    // Solid, not md-lock_outline (0xF0341). This sits at label size next to a
    // network name, and at that size an outlined padlock is four grey strokes
    // that read as a smudge. Same call the `settings` glyph in Icons.qml makes,
    // for the same reason.
    readonly property string lock: String.fromCodePoint(0xF033E)       // nf-md-lock

    // ---------------- The adapter ----------------
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null

    // Connected first, then the ones already saved, then alphabetically. The
    // two rows worth clicking are at the top, and past that a stable order
    // matters more than a clever one: a list sorted by signal strength
    // reshuffles itself under the pointer every few seconds, which is how you
    // click the wrong network.
    //
    // Note what this binding does NOT read: signalStrength. It changes
    // constantly, and reading it here would rebuild the whole list -- and
    // every delegate in it -- on every sample.
    readonly property var networks: {
        const all = root.wifiDevice?.networks?.values ?? [];
        return all.slice().sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return (a.name ?? "").localeCompare(b.name ?? "");
        });
    }

    // ---------------- The scanner ----------------
    //
    // THE PAGE'S OWN `visible`, AND THAT IS THE WHOLE TRAP. The settings
    // window builds every page at startup and keeps them all alive, showing
    // one at a time -- see the note above the Flickable in Settings.qml about
    // why a Loader was rejected. So a page that is not on screen is still
    // fully constructed, still has its bindings live, and would happily leave
    // the radio scanning forever if this were tied to anything else.
    //
    // `Component.onCompleted` is therefore wrong (it fires once, for a page
    // nobody is looking at), and so is the window being open: three of its
    // four pages are open too. The only thing that tracks "someone is actually
    // reading this list" is this item's own visible flag, which the window
    // drives from the selected page.
    //
    // A Binding and not an onVisibleChanged handler: the adapter can appear
    // AFTER the page is built -- a USB dongle, or NetworkManager still coming
    // up at login -- and a handler that already fired would never notice.
    // A binding re-evaluates when wifiDevice stops being null.
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.visible && Networking.wifiEnabled
    }

    // ---------------- Password state, held HERE and not in the row ----------------
    //
    // BY NETWORK NAME, AT PAGE LEVEL. The list is a Repeater over the computed
    // array above, and that array is rebuilt whenever any network's connected,
    // known or name changes -- which destroys every delegate and everything
    // living inside one. A half-typed password held in the row would vanish
    // because some unrelated network across the street finished associating.
    //
    // Keyed by name rather than by index for the same reason: the index of a
    // row is not stable across a re-sort, and the name is what the user is
    // looking at. The key is only as unique as the SSID -- if the backend ever
    // hands back two entries with the same name, both rows would open at once.
    // Not seen here, and not worth a synthetic id until it is.
    property string pskFor: ""
    property string pskDraft: ""

    // The failure line, same reasoning: connectionFailed arrives on the
    // network object some seconds after the click, by which time the delegate
    // that was clicked may be a different instance.
    property string failedFor: ""
    property string failedText: ""

    function openPsk(name: string): void {
        root.pskFor = name;
        root.pskDraft = "";
        root.failedFor = "";
        root.failedText = "";
    }

    function closePsk(): void {
        root.pskFor = "";
        root.pskDraft = "";
    }

    // ---------------- What a security type means for us ----------------
    //
    // Split by what the UI has to DO about it, not by protocol family, which
    // is why WEP sits next to WPA3-SAE here: both are "one secret, we can ask
    // for it".
    //
    // Owe is counted as open on purpose -- Opportunistic Wireless Encryption
    // encrypts the link with no shared secret at all, so asking for a password
    // would be asking for something that does not exist. Unknown falls to the
    // password side: a network whose security we cannot read is far more
    // likely to want one than not, and offering a field that turns out to be
    // unnecessary is a smaller failure than a click that silently does nothing.
    function needsPassword(security: int): bool {
        switch (security) {
        case WifiSecurityType.Open:
        case WifiSecurityType.Owe:
            return false;
        default:
            return true;
        }
    }

    // The ones that need a certificate, an identity, or a RADIUS server --
    // in other words a whole connection profile, which is what NMSettings
    // would build and NMSettings cannot be created from QML. Wpa3SuiteB192 is
    // in here rather than with the WPA3 personal case above: the 192-bit
    // suite-B mode is enterprise, whatever its name suggests.
    function isEnterprise(security: int): bool {
        switch (security) {
        case WifiSecurityType.Wpa3SuiteB192:
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.DynamicWep:
        case WifiSecurityType.Leap:
            return true;
        default:
            return false;
        }
    }

    // Four buckets over a 0..1 double. Quarters, because that is what the
    // glyphs draw -- the font has exactly four arc counts plus an empty one,
    // so any finer mapping would be arithmetic that never reaches the screen.
    function strengthGlyph(strength: real): string {
        if (strength >= 0.75)
            return Icons.wifi;
        if (strength >= 0.5)
            return root.wifi3;
        if (strength >= 0.25)
            return root.wifi2;
        if (strength > 0)
            return root.wifi1;
        return root.wifiFaint;
    }

    // Plain words, not ConnectionFailReason.toString(). That returns the
    // enumerator's own name -- "NoSecrets" -- which is a sentence about
    // NetworkManager's internals, and the person reading it typed a password
    // wrong. Only the one case anybody can act on gets its own wording; the
    // rest are genuinely indistinguishable from where the user is sitting.
    function failureText(reason: int): string {
        if (reason === ConnectionFailReason.NoSecrets)
            return "Wrong password";
        return "Could not connect";
    }

    // ---------------- Radio ----------------
    SettingsSection {
        width: parent.width
        title: "Wi-Fi"

        ToggleRow {
            glyph: Networking.wifiEnabled ? Icons.wifi : Icons.wifiOff
            label: "Wi-Fi"
            checked: Networking.wifiEnabled
            // wifiHardwareEnabled is the physical kill switch. With it off the
            // soft switch cannot be turned on at all, so the row goes dim and
            // stops accepting clicks rather than taking one that would do
            // nothing -- and the line below says why, because a control that
            // is greyed out with no explanation reads as a bug.
            enabled: Networking.wifiHardwareEnabled
            onToggled: value => Networking.wifiEnabled = value
        }

        // Only there when it is true, which is almost never. A permanent
        // caption explaining a condition that does not apply is noise the eye
        // learns to skip, and then misses on the day it matters.
        Text {
            visible: !Networking.wifiHardwareEnabled

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            bottomPadding: 6

            text: "The wireless adapter is switched off in hardware. "
                + "A key on the keyboard or a switch on the machine has to turn it back on."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.warning

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }
    }

    // ---------------- Networks ----------------
    SettingsSection {
        width: parent.width
        title: "Networks"

        // The one line the card shows when it has no rows to show. Each case
        // is a different thing to do about it, which is why it is not a single
        // "nothing here": the radio being off is fixed by the switch above,
        // a missing adapter is not fixable from this window at all, and an
        // empty list with the scanner running just means waiting a second.
        Text {
            visible: text !== ""

            x: Theme.groupPadding
            width: parent.width - Theme.groupPadding * 2
            topPadding: 4
            bottomPadding: 6

            text: {
                if (!root.wifiDevice)
                    return "No wireless adapter found.";
                if (!Networking.wifiEnabled)
                    return "Wi-Fi is off. Turn it on above to see what is in range.";
                if (root.networks.length === 0)
                    return "Scanning…";
                return "";
            }

            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize - 1
            color: Theme.textOnSurfaceVariant

            Behavior on color {
                ColorAnimation { duration: Theme.recolorDuration }
            }
        }

        // A CEILING ON THE LIST, and the same argument the island's version
        // makes: the number of rows is decided by however many access points
        // the air happens to be carrying, so a card that grows to fit them is
        // a card whose height is set by the neighbours. Here it also decides
        // the height of the window, which would then change size on the way
        // to the network page.
        //
        // 200 is about five rows, which is enough to see the top of the list
        // -- where the connected and the saved ones already are -- without the
        // section pushing anything else off the bottom of a 380px window.
        ScrollList {
            id: list

            width: parent.width
            height: Math.min(entries.implicitHeight, 200)

            // NO `visible: height > 0` HERE, however tidy that looks -- the
            // island's version of this list can afford it and this one cannot.
            // There the height comes from a bool nobody else reads; here it
            // comes from the column inside, and `visible` in QML is EFFECTIVE
            // visibility: hiding this hides every delegate, an invisible child
            // contributes nothing to a Column's implicitHeight, so the height
            // would go to zero and hold the thing shut. Measured on a stripped
            // copy of exactly this arrangement rather than reasoned about:
            // with the line in, adding three rows to an empty hidden list left
            // implicitHeight at 0 and the list closed forever. An empty
            // Flickable is zero pixels tall anyway, so it buys nothing.
            contentHeight: entries.implicitHeight

            // A Repeater IN a Flickable, not a ListView, and that is a
            // deliberate trade. ListView recycles delegates as they scroll,
            // which is right for a thousand rows and wrong for a row that
            // holds a password field: the field would be handed to a different
            // network on the way past. A Repeater builds every row and keeps
            // it. There are never more than a couple of dozen networks in
            // range, so the thing ListView buys does not apply here.
            Column {
                id: entries

                width: list.width
                spacing: 2

                Repeater {
                    model: Networking.wifiEnabled ? root.networks : []

                    delegate: Rectangle {
                        id: entry

                        required property var modelData

                        readonly property bool secured: root.needsPassword(entry.modelData?.security ?? WifiSecurityType.Unknown)
                        readonly property bool enterprise: root.isEnterprise(entry.modelData?.security ?? WifiSecurityType.Unknown)
                        readonly property bool asking: root.pskFor !== "" && root.pskFor === entry.modelData?.name
                        readonly property bool failed: root.failedFor !== "" && root.failedFor === entry.modelData?.name

                        width: entries.width
                        implicitHeight: content.implicitHeight + 8

                        // Pill while it is one line, and it stays a pill when
                        // the password field opens underneath: the radius is
                        // the row's own, so an expanded row reads as the same
                        // object grown rather than as a different kind of
                        // card that appeared.
                        radius: Theme.groupRadius
                        color: entryMouse.containsMouse || entry.asking ? Theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }

                        // The failure arrives on the network object, not from
                        // the call that started it: connect() and
                        // connectWithPsk() return immediately and the verdict
                        // comes back seconds later over D-Bus. Written to the
                        // page rather than to a local, for the reason at the
                        // top of this file -- this delegate may not exist by
                        // then.
                        Connections {
                            target: entry.modelData

                            function onConnectionFailed(reason): void {
                                root.failedFor = entry.modelData?.name ?? "";
                                root.failedText = root.failureText(reason);
                                // A wrong password leaves the field open with
                                // what was typed still in it: the correction
                                // is usually one character.
                            }

                            function onConnectedChanged(): void {
                                if (entry.modelData?.connected && entry.asking)
                                    root.closePsk();
                            }
                        }

                        Column {
                            id: content

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            // ---------------- The row itself ----------------
                            Item {
                                id: body

                                width: parent.width
                                height: 32

                                Text {
                                    id: strength

                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.groupPadding
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: root.strengthGlyph(entry.modelData?.signalStrength ?? 0)
                                    font.family: Theme.fontFamily
                                    font.pointSize: Theme.iconSize
                                    // The accent marks the connected network
                                    // and nothing else. Colouring this by
                                    // signal strength as well -- red for weak,
                                    // which is the obvious idea -- puts two
                                    // meanings on one mark, and the arcs
                                    // already say how strong it is.
                                    color: entry.modelData?.connected ? Theme.primary : Theme.textOnSurfaceVariant

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.animDuration }
                                    }
                                }

                                Row {
                                    id: nameRow

                                    anchors.left: strength.right
                                    anchors.leftMargin: Theme.itemSpacing
                                    anchors.right: actions.left
                                    anchors.rightMargin: Theme.itemSpacing
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        id: nameText

                                        anchors.verticalCenter: parent.verticalCenter

                                        // Bounded rather than left to elide
                                        // against the row: a Row hands each
                                        // child whatever width it asks for, so
                                        // a long SSID would push the padlock
                                        // out past the right edge instead of
                                        // eliding. The lock's own width is
                                        // subtracted only when it is showing,
                                        // because an invisible child takes no
                                        // space in a Row.
                                        width: Math.min(implicitWidth, nameRow.width - (lockMark.visible ? lockMark.width + nameRow.spacing : 0))
                                        elide: Text.ElideRight

                                        text: entry.modelData?.name ?? ""
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSize
                                        font.weight: entry.modelData?.connected ? Font.Bold : Theme.fontWeight
                                        color: entry.modelData?.connected ? Theme.primary : Theme.textOnSurface

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.animDuration }
                                        }
                                    }

                                    // A separate mark and not one of the
                                    // font's wifi_strength_N_lock glyphs,
                                    // which would say both things in one
                                    // character. At 13pt the padlock tucked
                                    // inside the arc is three pixels of
                                    // shackle -- it survives on a cheat sheet
                                    // and not on screen. Two marks, each
                                    // legible.
                                    Text {
                                        id: lockMark

                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: entry.secured

                                        text: root.lock
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSize - 2
                                        color: Theme.outline

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.recolorDuration }
                                        }
                                    }
                                }

                                Row {
                                    id: actions

                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.groupPadding - 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    // Forget. Only on the rows that have a
                                    // saved profile to throw away, and spelled
                                    // out rather than given a glyph: it throws
                                    // away a stored password, and every icon
                                    // that could stand for that (a bin, a
                                    // cross) is also the icon for "close
                                    // this". A word cannot be misread.
                                    Rectangle {
                                        id: forgetChip

                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: entry.modelData?.known ?? false

                                        implicitWidth: forgetLabel.implicitWidth + 16
                                        implicitHeight: 22
                                        radius: height / 2

                                        color: forgetMouse.containsMouse ? Theme.critical : "transparent"
                                        border.width: 1
                                        border.color: forgetMouse.containsMouse ? Theme.critical : Theme.outlineVariant

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.animDuration }
                                        }

                                        Behavior on border.color {
                                            ColorAnimation { duration: Theme.animDuration }
                                        }

                                        Text {
                                            id: forgetLabel

                                            anchors.centerIn: parent
                                            text: "Forget"
                                            font.family: Theme.fontFamily
                                            font.pointSize: Theme.fontSize - 2
                                            // Paired with the fill behind it,
                                            // as M3 requires: on the critical
                                            // red it has to be textOnCritical,
                                            // never textOnSurface.
                                            color: forgetMouse.containsMouse ? Theme.textOnCritical : Theme.textOnSurfaceVariant

                                            Behavior on color {
                                                ColorAnimation { duration: Theme.animDuration }
                                            }
                                        }

                                        MouseArea {
                                            id: forgetMouse

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                if (entry.asking)
                                                    root.closePsk();
                                                if (entry.modelData)
                                                    entry.modelData.forget();
                                            }
                                        }
                                    }

                                    // Says what a click will do rather than
                                    // repeating what the row already shows --
                                    // "secured" here would only restate the
                                    // padlock two inches to the left.
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: {
                                            if (entry.modelData?.connected)
                                                return "connected";
                                            if (entry.modelData?.stateChanging)
                                                return "connecting…";
                                            if (entry.modelData?.known)
                                                return "connect";
                                            if (entry.enterprise)
                                                return "set up";
                                            if (entry.asking)
                                                return "";
                                            return "join";
                                        }

                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSize - 2
                                        color: Theme.outline

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.recolorDuration }
                                        }
                                    }
                                }

                                // Behind the chip above, exactly as the
                                // island's list does it: reaching for Forget
                                // must never also connect. z: -1 puts this
                                // under every sibling, and none of the others
                                // take a click.
                                MouseArea {
                                    id: entryMouse

                                    anchors.fill: parent
                                    z: -1
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        const net = entry.modelData;
                                        if (!net)
                                            return;

                                        if (net.connected) {
                                            net.disconnect();
                                            return;
                                        }

                                        // Already saved: NetworkManager has
                                        // the secret, so this never needs to
                                        // ask for it -- including for
                                        // enterprise ones, which is why this
                                        // test comes before the EAP one.
                                        if (net.known) {
                                            net.connect();
                                            return;
                                        }

                                        // A profile, not a password. See the
                                        // header: NMSettings cannot be built
                                        // from QML, so this is handed to the
                                        // tool that can -- the same thing
                                        // WifiControl does with everything it
                                        // cannot handle.
                                        if (entry.enterprise) {
                                            Quickshell.execDetached(["nm-connection-editor"]);
                                            return;
                                        }

                                        if (!entry.secured) {
                                            net.connect();
                                            return;
                                        }

                                        // A second click on an open field
                                        // closes it, so the row is its own way
                                        // out of the state it just entered.
                                        if (entry.asking)
                                            root.closePsk();
                                        else
                                            root.openPsk(net.name);
                                    }
                                }
                            }

                            // ---------------- Password ----------------
                            //
                            // ON THE ROW AND NOT IN A DIALOG. Which network is
                            // being joined is the one thing that must not be
                            // in doubt while typing a secret, and a modal
                            // covering the list takes that away exactly when
                            // it is needed.
                            //
                            // A bare TextInput in a pill drawn by hand. There
                            // is no other password field in this shell, so
                            // there is nothing to copy -- and the obvious
                            // shortcut, Controls' TextField, is out for the
                            // reason written above ToggleRow's switch: nothing
                            // here imports QtQuick.Controls, and one widget
                            // that does would arrive with its own palette and
                            // its own metrics.
                            Item {
                                id: pskBox

                                width: parent.width
                                height: 32
                                visible: entry.asking

                                // The field is created with the row, long
                                // before anyone asks for it, so focus has to
                                // follow the row opening rather than the item
                                // being built.
                                onVisibleChanged: {
                                    if (visible)
                                        pskField.forceActiveFocus();
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: Theme.groupPadding
                                    anchors.rightMargin: Theme.groupPadding - 4
                                    anchors.verticalCenter: parent.verticalCenter

                                    height: 28
                                    radius: height / 2

                                    // Its own surface, a step up from the row
                                    // behind it: a field that is only outlined
                                    // reads as a label with a box round it,
                                    // and this one has to look like somewhere
                                    // to type.
                                    color: Theme.surfaceContainerHighest
                                    border.width: 1
                                    border.color: pskField.activeFocus ? Theme.primary : Theme.outlineVariant

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.recolorDuration }
                                    }

                                    Behavior on border.color {
                                        ColorAnimation { duration: Theme.animDuration }
                                    }

                                    TextInput {
                                        id: pskField

                                        anchors.left: parent.left
                                        anchors.right: enterHint.left
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter

                                        echoMode: TextInput.Password

                                        // THE TEXT LIVES ON THE PAGE, and this
                                        // binding is how it gets back here
                                        // after a rebuild -- see the note at
                                        // the top. Writing to pskDraft from
                                        // onTextEdited does not break the
                                        // binding above it: the binding
                                        // re-evaluates to the value just
                                        // written, so nothing loops and
                                        // nothing is overwritten.
                                        text: root.pskDraft
                                        onTextEdited: {
                                            root.pskDraft = text;
                                            // Typing is the answer to "wrong
                                            // password", so the complaint goes
                                            // away as soon as it is being
                                            // acted on.
                                            root.failedFor = "";
                                        }

                                        // Keeps the field out of the input
                                        // method's history and prediction, and
                                        // off any autocapitalisation -- a
                                        // capitalised first letter in a WPA
                                        // key is a failure that looks like a
                                        // wrong password.
                                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSize
                                        color: Theme.textOnSurface
                                        selectionColor: Theme.primary
                                        selectedTextColor: Theme.textOnPrimary
                                        selectByMouse: true

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.recolorDuration }
                                        }

                                        onAccepted: {
                                            // An empty field is a stray Enter,
                                            // not a request: connectWithPsk("")
                                            // would fail with NoSecrets and be
                                            // reported back as a wrong
                                            // password, which is the one
                                            // message it is not.
                                            if (root.pskDraft === "" || !entry.modelData)
                                                return;
                                            entry.modelData.connectWithPsk(root.pskDraft);
                                        }

                                        // ESCAPE HAS TO BE SWALLOWED HERE.
                                        // The settings window's FocusScope
                                        // closes the whole window on Escape,
                                        // and without accepting the event that
                                        // is what cancelling a password field
                                        // would do -- the window would
                                        // disappear instead of the field.
                                        Keys.onEscapePressed: event => {
                                            root.closePsk();
                                            event.accepted = true;
                                        }

                                        // TextInput has no placeholderText --
                                        // that belongs to TextField, which is
                                        // Controls. With echoMode Password an
                                        // empty field shows literally nothing,
                                        // so without this it is an empty pill
                                        // that gives no sign of what it wants.
                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: pskField.text === ""

                                            text: "Password"
                                            font.family: Theme.fontFamily
                                            font.pointSize: Theme.fontSize
                                            color: Theme.outline

                                            Behavior on color {
                                                ColorAnimation { duration: Theme.recolorDuration }
                                            }
                                        }
                                    }

                                    // There is no button. The field is one
                                    // line at the end of a click that already
                                    // said what it was for, and a submit chip
                                    // beside it would be a second target for
                                    // the same decision -- so the key that
                                    // does it is written where it will be
                                    // read.
                                    Text {
                                        id: enterHint

                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: "Enter to join · Esc to cancel"
                                        font.family: Theme.fontFamily
                                        font.pointSize: Theme.fontSize - 3
                                        color: Theme.outline

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.recolorDuration }
                                        }
                                    }
                                }
                            }

                            // ---------------- Failure ----------------
                            //
                            // On the row that failed, in the colour reserved
                            // for things that are wrong. Not a notification:
                            // the answer to this line is to retype the field
                            // directly above it, and a message that appears in
                            // the corner of the screen moves the eye away from
                            // the only thing that fixes it.
                            Text {
                                width: parent.width - Theme.groupPadding * 2
                                x: Theme.groupPadding
                                visible: entry.failed

                                text: root.failedText
                                wrapMode: Text.WordWrap
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 2
                                color: Theme.critical

                                Behavior on color {
                                    ColorAnimation { duration: Theme.recolorDuration }
                                }
                            }

                            // ---------------- Enterprise ----------------
                            //
                            // Says what it is using NetworkManager's own name
                            // for the security type rather than a word chosen
                            // here: "WPA2 Enterprise" is what the person who
                            // set the network up will recognise, and it is one
                            // less string that can drift out of step with the
                            // backend.
                            Text {
                                width: parent.width - Theme.groupPadding * 2
                                x: Theme.groupPadding
                                visible: entry.enterprise && !(entry.modelData?.known ?? false)

                                text: WifiSecurityType.toString(entry.modelData?.security ?? WifiSecurityType.Unknown)
                                    + " · needs a certificate. Opens the network editor."
                                wrapMode: Text.WordWrap
                                font.family: Theme.fontFamily
                                font.pointSize: Theme.fontSize - 2
                                color: Theme.textOnSurfaceVariant

                                Behavior on color {
                                    ColorAnimation { duration: Theme.recolorDuration }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
