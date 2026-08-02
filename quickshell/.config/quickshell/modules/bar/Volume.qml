// Volume of the default sink, straight from PipeWire.
//
// No pulseaudio module, no wpctl being spawned to read a number: Quickshell
// talks to PipeWire itself, so the value changes the instant the sink does.
//
// PwObjectTracker is not optional. PipeWire objects are bound lazily: without
// something declaring interest in the node, its `audio` data is never
// populated and volume reads 0 forever.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "root:/"

// The root is an Item and not the Row itself: a Row refuses to lay out
// children that use anchors.fill, and the click area has to cover the whole
// module.
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)

    // Icon set matches waybar's format-icons, including the headphone and
    // headset cases.
    readonly property string glyph: {
        if (muted)
            return Icons.volumeMuted;
        const name = (sink?.name ?? "").toLowerCase();
        const description = (sink?.description ?? "").toLowerCase();
        const both = `${name} ${description}`;
        if (both.includes("headset"))
            return Icons.headset;
        if (both.includes("headphone"))
            return Icons.headphones;
        if (volume === 0)
            return Icons.volumeLow;
        if (volume < 50)
            return Icons.volumeMedium;
        return Icons.volumeHigh;
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: {
                if (root.muted)
                    return Theme.outline;
                // Over 100% the gain is applied in software: worth flagging,
                // the same way waybar's .overamplified class did.
                if (root.volume > 100)
                    return Theme.warning;
                return Theme.textOnSurface;
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "muted" : `${root.volume}%`
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            font.weight: Theme.fontWeight
            color: root.muted ? Theme.outline : Theme.textOnSurface

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.sink?.audio)
                root.sink.audio.muted = !root.sink.audio.muted;
        }
        // Same 5% step waybar used for scroll-step.
        onWheel: wheel => {
            if (!root.sink?.audio)
                return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            // Capped at 1.0: boosting past 100% is left to the keyboard keys,
            // which already allow it deliberately (see hyprland.lua).
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }
}
