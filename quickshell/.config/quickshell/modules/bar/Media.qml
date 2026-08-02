// What is playing, from MPRIS.
//
// This replaces ~/.local/bin/waybar-media, and the reason that script existed
// disappears with it: waybar ran libplayerctl INSIDE its own process, so a
// Chromium player emitting PropertiesChanged could corrupt memory and take
// the whole bar down (the script's header documents the backtrace). Here the
// D-Bus client is Quickshell's own service, out of process from every player.

import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import "root:/"

Item {
    id: root

    // Prefer whatever is actually playing; fall back to the first player that
    // exists, so a paused track still shows.
    readonly property var player: {
        const players = Mpris.players.values;
        if (players.length === 0)
            return null;
        return players.find(p => p.isPlaying) ?? players[0];
    }

    readonly property bool hasPlayer: player !== null

    // Per-player glyph, same table the old script carried. The key is matched
    // against the D-Bus identity, lowercased.
    readonly property var icons: ({
        brave: Icons.chromium,
        chromium: Icons.chromium,
        chrome: Icons.chromium,
        firefox: Icons.firefox,
        spotify: Icons.spotify,
        vlc: Icons.vlc
    })

    readonly property string icon: {
        if (!hasPlayer)
            return Icons.music;
        if (!player.isPlaying)
            return Icons.pause;
        const identity = (player.identity ?? "").toLowerCase();
        for (const key in icons) {
            if (identity.includes(key))
                return icons[key];
        }
        return Icons.music;
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: root.player?.isPlaying ? Theme.tertiary : Theme.outline

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (!root.hasPlayer)
                    return "No media";
                const title = root.player.trackTitle ?? "";
                const artist = Track.artist(root.player.trackArtist ?? "");
                return artist ? `${title}  ·  ${artist}` : title;
            }

            // Same ceiling the old script used for the bar text.
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 380)

            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: {
                if (!root.hasPlayer)
                    return Theme.outline;
                return root.player.isPlaying ? Theme.textOnSurface : Theme.textOnSurfaceVariant;
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.ForwardButton | Qt.BackButton

        onClicked: mouse => {
            if (!root.hasPlayer)
                return;
            if (mouse.button === Qt.ForwardButton)
                root.player.next();
            else if (mouse.button === Qt.BackButton)
                root.player.previous();
            else if (root.player.canTogglePlaying)
                root.player.togglePlaying();
        }
    }
}
