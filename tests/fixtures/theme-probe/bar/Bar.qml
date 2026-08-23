// The bar, as the probe draws it: one magenta strip across the top with the
// theme's name on it. No widgets, no island, no popout, no clock.
//
// IT READS BatteryAlerts, AND THAT IS THE ONE LINE IN THIS FILE THAT IS NOT
// DECORATION. `modules/bar` is a host module whose only importer is a theme:
// BatteryAlerts is read by genesis's two battery widgets and by nothing on the
// host side. Quickshell's startup scan decides which directories become
// modules by following the imports out of shell.qml, so a host module nothing
// on that side imports is one the scan reaches only if some theme on the
// import list happens to import it -- and this fixture is deliberately NOT on
// that list. `modules/Themes.qml` names BatteryAlerts in `keptInScope` for
// exactly this case, and the comment there says the accident is the whole
// problem. This is the caller that turns that line from a precaution into
// something a check can fail on: delete `keptInScope` and genesis still comes
// up clean while this theme dies with "module qs.modules.bar is not
// installed".
//
// IT PUBLISHES NOTHING TO Surfaces. genesis's bar is the only publisher of
// `Surfaces.popoutOpen` and the only listener for `dismissPopouts`, both
// because it owns a popout. A bar with no popout has nothing to say: the
// property stays false and the one-surface-at-a-time rule still holds for the
// other four members. Membership is not registered by a theme -- it is the
// five hardcoded entries in modules/Surfaces.qml -- so a minimal theme
// inherits the whole rule by doing nothing.
//
// THE EXCLUSION ZONE IS KEPT. Nothing in the host reads it; the compositor
// does, and dropping it means every window sits under the bar. It is the one
// surface here with one.

import QtQuick
import Quickshell
import qs
import qs.modules.bar

PanelWindow {
    id: root

    // The ShellScreen this bar belongs to, from Variants in shell.qml.
    required property var modelData

    screen: root.modelData

    anchors.top: true
    anchors.left: true
    anchors.right: true

    implicitHeight: Theme.barHeight
    color: "#ff00ff"

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight

    Text {
        anchors.centerIn: parent

        text: `PROBE -- battery alert below ${BatteryAlerts.alertBelow}%`
        color: "#000000"
        font.family: Theme.fontFamily
    }

    // THE LINE tests/shell-load.sh WATCHES FOR, and the only reason this
    // fixture prints anything at all. A theme swap rebuilds the surfaces
    // inside a running engine: nothing is written, nothing exits, and
    // "Configuration Loaded" is not printed a second time -- so from outside
    // the process there is no evidence it happened. Seven of these are.
    Component.onCompleted: console.log("theme-probe drew bar/Bar.qml")
}
