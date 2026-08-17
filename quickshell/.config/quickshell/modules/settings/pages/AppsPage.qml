// Which program opens what.
//
// SEVEN ROLES AND NOT FORTY MIME TYPES. Nobody wants to set the handler for
// image/webp; they want "the thing that opens pictures", which is nine types
// that have to move together. A viewer chosen for PNG and not for JPEG is
// worse than not choosing at all, because it looks like it took. The grouping
// lives in the `default-apps` script so a terminal gets it too.
//
// NOTHING IS STORED HERE. The answer is ~/.config/mimeapps.list, written by
// xdg-mime, read by every application on the machine. This page is a view of
// it -- change a default from a terminal and this shows the new one the next
// time it is opened.
//
// THE LIST OF CANDIDATES IS gio's, not a walk of /usr/share/applications.
// That walk would reimplement, badly, something gio already does correctly:
// the per-user directory, the desktop-specific overrides, and the difference
// between an application that declares a type and one that merely opens it.
//
// NO TERMINAL ROW, which is the one people look for. There is no MIME type
// for it -- the terminal is named in hyprland.lua, a tracked file with a
// thousand lines of prose in it that this window must not rewrite. Same
// boundary desktop-tweak's header draws.

import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Apps"
    glyph: Icons.apps
    keywords: ["default", "defaults", "apps", "applications", "open with",
        "browser", "file manager", "viewer", "player", "pdf", "editor",
        "mime", "handler"]

    // The label is what this role is CALLED to a person, and the glyph is the
    // kind of thing it opens rather than the program that opens it -- the
    // program is the part that changes.
    readonly property var roles: [
        { key: "browser", label: "Web pages",  glyph: Icons.wifi },
        { key: "files",   label: "Folders",    glyph: Icons.windowTiles },
        { key: "image",   label: "Pictures",   glyph: Icons.image },
        { key: "video",   label: "Video",      glyph: Icons.display },
        { key: "audio",   label: "Music",      glyph: Icons.music },
        { key: "pdf",     label: "PDFs",       glyph: Icons.clipboard },
        { key: "text",    label: "Plain text", glyph: Icons.textSize }
    ]

    // role -> desktop id, as the script last reported it.
    property var handlers: ({})

    // AT PAGE LEVEL, keyed by role, for the reason the network page gives
    // about its password field: the rows are a Repeater over an array that is
    // rebuilt whenever the handlers change, which destroys every delegate.
    // An expansion held inside one would close itself the moment it was used.
    property string expandedRole: ""
    property var candidates: []
    property bool loadingCandidates: false

    function displayName(desktopId: string): string {
        if (!desktopId || desktopId === "-")
            return "";

        // byId wants the id WITHOUT the suffix; the script and gio both speak
        // in full filenames.
        const entry = DesktopEntries.byId(desktopId.replace(/\.desktop$/, ""));
        if (entry?.name)
            return entry.name;

        // No entry is not an error worth hiding: a handler can name a .desktop
        // that has since been uninstalled, and seeing the filename is how
        // somebody works out why nothing opens.
        return desktopId.replace(/\.desktop$/, "");
    }

    function open(role: string): void {
        if (root.expandedRole === role) {
            root.expandedRole = "";
            return;
        }

        root.expandedRole = role;
        root.candidates = [];
        root.loadingCandidates = true;
        candidateQuery.command = ["default-apps", "candidates", role];
        candidateQuery.running = true;
    }

    // Asked when the page is looked at rather than once at startup: every page
    // in this window is built and kept alive, and mimeapps.list can have been
    // changed from a terminal since the last visit.
    onVisibleChanged: {
        if (visible && !handlerQuery.running)
            handlerQuery.running = true;
    }

    Process {
        id: handlerQuery

        command: ["default-apps", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = ({});

                for (const line of (text || "").split("\n")) {
                    const at = line.indexOf("\t");
                    if (at < 0)
                        continue;
                    parsed[line.slice(0, at)] = line.slice(at + 1);
                }

                root.handlers = parsed;
            }
        }
    }

    Process {
        id: candidateQuery

        stdout: StdioCollector {
            onStreamFinished: {
                root.candidates = (text || "").split("\n").filter(line => line.trim() !== "");
                root.loadingCandidates = false;
            }
        }
    }

    Process {
        id: setter

        // Re-read rather than assumed: xdg-mime can decline, and a page that
        // painted the new value on click would be reporting its own intention
        // back to itself.
        onExited: handlerQuery.running = true
    }

    SettingsSection {
        width: parent.width
        glyph: Icons.apps
        title: "Opens with"

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: root.roles

                delegate: Column {
                    id: roleRow

                    required property var modelData

                    readonly property string key: roleRow.modelData.key
                    readonly property string handler: root.handlers[roleRow.key] ?? ""
                    readonly property bool expanded: root.expandedRole === roleRow.key

                    width: parent.width
                    spacing: 2

                    Rectangle {
                        width: parent.width
                        implicitHeight: 34
                        radius: Theme.groupRadius
                        color: rowMouse.containsMouse || roleRow.expanded
                            ? Theme.surfaceContainerHigh : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.animDuration }
                        }

                        Text {
                            id: roleGlyph

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.groupPadding
                            anchors.verticalCenter: parent.verticalCenter

                            text: roleRow.modelData.glyph
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.iconSize
                            color: Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        Text {
                            anchors.left: roleGlyph.right
                            anchors.leftMargin: Theme.itemSpacing
                            anchors.verticalCenter: parent.verticalCenter

                            text: roleRow.modelData.label
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            font.weight: Theme.fontWeight
                            color: Theme.textOnSurface

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.groupPadding
                            anchors.verticalCenter: parent.verticalCenter

                            // "Nothing" and not an empty right-hand side: a
                            // role with no handler is a real state -- opening
                            // that kind of file does nothing at all -- and a
                            // blank looks like the page failed to read it.
                            text: root.displayName(roleRow.handler) || "Nothing"
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 1
                            color: roleRow.expanded ? Theme.primary : Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.animDuration }
                            }
                        }

                        MouseArea {
                            id: rowMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.open(roleRow.key)
                        }
                    }

                    // ---------------- The choices ----------------
                    //
                    // INLINE AND NOT A MENU, for the reason the network page
                    // gives about its password field: which role is being
                    // changed must not be in doubt while choosing, and a
                    // popup covering the list takes that away exactly when it
                    // is needed.
                    Column {
                        width: parent.width
                        visible: roleRow.expanded
                        spacing: 2

                        Text {
                            visible: root.loadingCandidates || root.candidates.length === 0

                            x: Theme.groupPadding + Theme.iconSize + Theme.itemSpacing
                            topPadding: 2
                            bottomPadding: 4

                            text: root.loadingCandidates
                                ? "Looking…"
                                : "Nothing installed declares that it opens these."
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize - 2
                            color: Theme.textOnSurfaceVariant

                            Behavior on color {
                                ColorAnimation { duration: Theme.recolorDuration }
                            }
                        }

                        Repeater {
                            model: roleRow.expanded ? root.candidates : []

                            delegate: Rectangle {
                                id: choice

                                required property var modelData

                                readonly property bool chosen: choice.modelData === roleRow.handler

                                width: parent.width
                                implicitHeight: 28
                                radius: Theme.groupRadius
                                color: choiceMouse.containsMouse
                                    ? Theme.surfaceContainerHighest : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animDuration }
                                }

                                Text {
                                    // Indented past the role's glyph, so the
                                    // list reads as belonging to the row above
                                    // it rather than as more roles.
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.groupPadding + Theme.iconSize + Theme.itemSpacing
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.groupPadding
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: root.displayName(choice.modelData)
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pointSize: Theme.fontSize - 1
                                    font.weight: choice.chosen ? Font.Bold : Theme.fontWeight
                                    color: choice.chosen ? Theme.primary : Theme.textOnSurface

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.animDuration }
                                    }
                                }

                                MouseArea {
                                    id: choiceMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        setter.command = ["default-apps", "set",
                                            roleRow.key, choice.modelData];
                                        setter.running = true;
                                        root.expandedRole = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
