// THE WINDOWS 11 TASKBAR.
//
// Bottom, full width, forty-eight tall, and translucent enough that the
// wallpaper's colour reads through it. That last clause is not decoration: it
// is the single most load-bearing fact about how this thing looks, and the
// first attempt at this theme missed it entirely because every screenshot was
// taken over the compositor's black void, where a 95%-opaque surface and a
// 78%-opaque one are the same picture.
//
// THREE ZONES, AND THE MIDDLE ONE IS CENTRED ON THE SCREEN rather than in the
// space left over. Windows centres Start and the task buttons and lets the
// corner run out to the right edge underneath them; a centring that respected
// the corner would shift the whole group every time a tray icon appeared.
//
// WHAT IS IN THE MIDDLE IS WINDOWS, NOT WORKSPACES. A Windows taskbar is a
// list of what is open. That needed the host to publish one -- see
// Compositor.windowsOn -- and until it did, the centre of this bar was empty
// and no amount of drawing was going to fix it.
//
// WHAT IS NOT HERE. No media island, no dashboard, no logo pill, no settings
// gear, no power button, no updates glyph, no notification bell. Windows has
// none of them on its taskbar: Start holds the power button, Quick Settings
// holds the toggles, and the unread count sits on the clock. A theme that
// carries them because the shell has them is a theme wearing another theme's
// inventory, which is exactly how the first attempt went wrong.

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.components
import qs.modules
import qs.modules.settings
// The notification centre lives next door in notifications/, because it is
// that surface's content and not the bar's. A directory import and NOT the
// module form: `import qs.themes.windows` is the rule for reaching THE THEME'S
// SINGLETON, where the relative form silently resolves the type instead of the
// instance. An ordinary type has no such trap, and this is how genesis reaches
// across its own directories.
import "../notifications"

PanelWindow {
    id: root

    required property var modelData

    readonly property string screenKey: Config.screenKey(root.modelData)

    // The four switches this taskbar can actually obey, and the manifest
    // declares exactly these four so the Bar page offers no others. A switch
    // for a widget a theme does not draw is a control that flips, saves,
    // reloads and changes nothing.
    function widget(name: string): bool {
        return Config.barWidget(root.screenKey, name);
    }
    readonly property var apps: Compositor.windowsOn(root.modelData?.name ?? "")

    screen: modelData

    // The namespace Hyprland's blur-quickshell rule matches on. Not
    // decorative: a namespace that is not on that list does not come out
    // unblurred, it falls through to the global decoration.blur, which has
    // different parameters and no xray, and the surface ends up visibly
    // blurrier than everything around it.
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight

    // The bar is the whole window: there is no fillet strip to keep
    // click-through, because screenCornerRadius is 0 under this theme and a
    // taskbar has no concave corners to carve.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight

    color: "transparent"

    Rectangle {
        id: surface

        anchors.fill: parent
        color: Theme.glass(Theme.surface)

        // A hairline along the top edge. Windows has one -- Rectangle
        // #BackgroundStroke, a real element in the live taskbar's XAML -- and
        // publishes no value for it, so this is OURS.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Theme.outlineVariant
        }
    }

    // ================= CENTRE: START AND THE OPEN WINDOWS =================
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.itemSpacing

        StartButton {}

        Repeater {
            model: root.apps

            TaskButton {
                required property var modelData

                app: modelData
            }
        }
    }

    // ================= RIGHT: THE TASKBAR CORNER =================
    // THE CLOCK IS THE RIGHTMOST THING ON THE BAR, and the icons sit to its
    // left. That order was backwards on the first pass and a photograph is the
    // only thing that catches it: reading a real corner right to left gives
    // the date and time, then the system group, then the keyboard layout, then
    // the overflow chevron.
    Clock {
        id: clock

        visible: root.widget("clock")

        anchors.right: parent.right
        anchors.rightMargin: Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter

        onClicked: barPopout.openAt(clock.x + clock.width / 2, notificationCentre)
    }

    TrayCorner {
        id: corner

        anchors.right: clock.visible ? clock.left : parent.right
        anchors.rightMargin: clock.visible ? 0 : Theme.barPadding
        anchors.verticalCenter: parent.verticalCenter

        barScreen: root.modelData

        showTray: root.widget("tray")
        showKeyboardLayout: root.widget("keyboardLayout")
        showNotifications: root.widget("notifications")

        onOverflowRequested: barPopout.openAt(corner.x + corner.width / 2, trayMenu)
        onQuickSettingsRequested: barPopout.openAt(corner.x + corner.width / 2, quickSettings)
    }

    // ================= THE ONE POPOUT THE BAR OWNS =================
    //
    // It moves under whichever item was clicked and swaps its content, rather
    // than every item owning a window. See components/Popout.qml.
    //
    // The id is NOT `popout`: in `Foo { popout: popout }` the right-hand side
    // resolves to Foo's own property of that name before the outer id.
    Popout {
        id: barPopout

        modelData: root.modelData
    }

    // The three things the taskbar opens, each drawn against its own
    // photograph. They were empty skeletons here for most of this theme's
    // life, and empty rather than borrowed on purpose: a Quick Settings panel
    // that was genesis's dashboard in a different colour is the thing this
    // theme was restarted to stop doing, and a placeholder that admits it is
    // one is easier to finish than a copy that looks finished already.
    //
    // ONE Popout above and three Components here, not three Popouts. Windows
    // dismisses whichever of these is open when you click another -- they are
    // one surface showing different contents, and giving each its own window
    // is how you end up with two of them on screen at once.
    Component {
        id: quickSettings

        QuickSettings {
            onDismissRequested: barPopout.close()
            onSubPageRequested: page => {
                // The sub-pages Windows opens inside this panel -- the Wi-Fi
                // picker, the Bluetooth list, the cast target -- are pages
                // this shell already has in its settings window. Sending
                // somebody there is honest; drawing a second, thinner copy of
                // a list that already exists is not.
                barPopout.close();
                SettingsState.open();
            }
        }
    }

    Component {
        id: notificationCentre

        NotificationCentre {}
    }

    Component {
        id: trayMenu

        TrayOverflow {
            onDismissRequested: barPopout.close()
        }
    }

    // THIS FILE REPORTS AND OBEYS; IT DOES NOT DECIDE which of the shell's own
    // surfaces may be on screen together. That rule is one file,
    // modules/Surfaces.qml, and a per-bar file is the wrong place to keep a
    // fact about the whole shell.
    Connections {
        target: barPopout

        function onIsOpenChanged(): void {
            Surfaces.popoutOpen = barPopout.isOpen;
        }
    }

    Connections {
        target: Surfaces

        function onDismissPopouts(): void {
            barPopout.close();
        }
    }
}
