// QUICK SETTINGS, the panel Win+A opens from the taskbar corner.
//
// Drawn from a photograph, and the photograph contradicts what a table of
// numbers would have produced in three places:
//
//   A TILE IS A WIDE RECTANGLE AND ITS LABEL IS OUTSIDE IT. Not a square with
//   the word inside. The tile is about 140 by 48 with the glyph centred, and
//   the label sits underneath it, centred, in Caption.
//
//   WI-FI AND BLUETOOTH ARE SPLIT TILES. The left part toggles; a separate
//   right-hand segment with a chevron opens the picker, and there is a visible
//   divider between the two. That is why the label under those two is the
//   network's name rather than the word "Wi-Fi".
//
//   THE SLIDERS' UNFILLED TRACK IS LIGHTER THAN THE PANEL, not darker. Which
//   is the rule this whole theme runs on -- everything that comes forward gets
//   lighter -- and it is the opposite of the instinct.
//
// AND THE MEDIA CARD BELONGS HERE. Windows puts the now-playing controls in a
// separate card ABOVE the toggle grid, not on the taskbar. Genesis's island
// put it bottom-left on the bar, which is the single thing the user pointed at
// first when he called the last attempt an adaptation. The object is not
// wrong; its place was.

import QtQuick
import Quickshell.Services.UPower
import qs
import qs.modules.settings
import qs.themes.windows

Item {
    id: root

    implicitWidth: Fluent.quickWidth
    implicitHeight: column.implicitHeight

    // Hoisted here, where every read through them is checked.
    readonly property bool playing: Track.active !== null
    readonly property string trackTitle: Track.active?.trackTitle ?? ""
    readonly property string trackArtist: Track.active?.trackArtist ?? ""
    readonly property string trackApp: Track.active?.identity ?? ""
    readonly property bool trackPaused: Track.active?.playbackState !== 1

    readonly property int batteryPercent: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)
    readonly property bool hasBattery: UPower.displayDevice?.isLaptopBattery === true

    Column {
        id: column

        width: parent.width
        spacing: Fluent.quickCardGap

        // ---------------- the media card ----------------
        Rectangle {
            width: parent.width
            height: root.playing ? Fluent.quickMediaHeight : 0
            visible: root.playing

            radius: Fluent.overlayRadius
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outlineVariant

            Text {
                id: mediaApp

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Fluent.quickPadding

                text: root.trackApp
                font.family: Theme.fontFamily
                font.pointSize: Fluent.captionSize
                color: Theme.textOnSurfaceVariant
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: mediaApp.bottom
                anchors.leftMargin: Fluent.quickPadding
                anchors.rightMargin: Fluent.quickPadding
                anchors.topMargin: 10

                spacing: 2

                Text {
                    width: parent.width
                    text: root.trackTitle
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.bodySize
                    font.weight: Fluent.strongWeight
                    color: Theme.textOnSurface
                }

                Text {
                    width: parent.width
                    text: root.trackArtist
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pointSize: Fluent.captionSize
                    color: Theme.textOnSurfaceVariant
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Fluent.quickPadding

                spacing: 28

                component Transport: Item {
                    id: transport

                    property string transportGlyph: ""

                    signal pressed

                    width: 32
                    height: 32

                    Text {
                        anchors.centerIn: parent
                        text: transport.transportGlyph
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodyLargeSize
                        color: transportPointer.containsMouse
                            ? Theme.textOnSurface
                            : Theme.textOnSurfaceVariant
                    }

                    MouseArea {
                        id: transportPointer

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: transport.pressed()
                    }
                }

                Transport {
                    transportGlyph: Icons.skipPrevious
                    onPressed: Track.active?.previous()
                }

                Transport {
                    transportGlyph: root.trackPaused ? Icons.play : Icons.pause
                    onPressed: Track.active?.togglePlaying()
                }

                Transport {
                    transportGlyph: Icons.skipNext
                    onPressed: Track.active?.next()
                }
            }
        }

        // ---------------- the toggles and sliders ----------------
        Rectangle {
            width: parent.width
            height: body.implicitHeight

            radius: Fluent.overlayRadius
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outlineVariant

            Column {
                id: body

                width: parent.width
                spacing: 0

                // A Column positions its children, so nothing inside it may
                // set its own y. The padded parts sit inside holder Items and
                // the dividers run the full width, which is what the
                // photograph shows -- a rule that stops at the padding would
                // read as a card inside a card.
                Item {
                    width: parent.width
                    height: Fluent.quickPadding
                }

                Item {
                    width: parent.width
                    height: grid.height

                    Grid {
                        id: grid

                        x: Fluent.quickPadding
                        width: parent.width - Fluent.quickPadding * 2

                        columns: 3
                        columnSpacing: Fluent.quickTileGap
                        rowSpacing: Fluent.quickTileGap

                        readonly property real cell:
                            (grid.width - grid.columnSpacing * (grid.columns - 1)) / grid.columns

                        QuickTile {
                            cellWidth: grid.cell
                            tileGlyph: Icons.wifi
                            caption: "Wi-Fi"
                            on: true
                            split: true
                            onPicked: root.subPageRequested("network")
                        }

                        QuickTile {
                            cellWidth: grid.cell
                            tileGlyph: Icons.bluetooth
                            caption: "Bluetooth"
                            on: true
                            split: true
                            onPicked: root.subPageRequested("bluetooth")
                        }

                        QuickTile {
                            cellWidth: grid.cell
                            tileGlyph: Microphone.isOpen ? Icons.microphone : Icons.microphoneOff
                            caption: "Microphone"
                            on: Microphone.isOpen
                            onToggled: Microphone.toggle()
                        }

                        QuickTile {
                            cellWidth: grid.cell
                            tileGlyph: Icons.nightLight
                            caption: "Night light"
                            on: NightLight.enabled
                            onToggled: NightLight.toggle()
                        }

                        QuickTile {
                            cellWidth: grid.cell
                            tileGlyph: Icons.bellOff
                            caption: "Do not disturb"
                            on: NotificationState.dnd
                            onToggled: NotificationState.dnd = !NotificationState.dnd
                        }

                        QuickTile {
                            cellWidth: grid.cell
                            tileGlyph: Icons.display
                            caption: "Project"
                            on: false
                            onToggled: root.subPageRequested("display")
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Fluent.quickPadding
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outlineVariant
                }

                QuickSlider {
                    width: parent.width
                    visible: Brightness.present
                    height: visible ? Fluent.quickSliderHeight : 0
                    sliderGlyph: Icons.brightness
                    value: Brightness.percent / 100
                    onMoved: fraction => Brightness.setPercent(Math.round(fraction * 100))
                }

                QuickSlider {
                    width: parent.width
                    height: Fluent.quickSliderHeight
                    sliderGlyph: Volume.muted ? Icons.volumeMuted : Icons.volumeHigh
                    value: Volume.volume
                    trailing: true
                    onMoved: fraction => Volume.setVolume(fraction)
                    onTrailingPressed: root.subPageRequested("sound")
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outlineVariant
                }

                Item {
                    width: parent.width
                    height: Fluent.quickFooterHeight

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Fluent.quickPadding
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        visible: root.hasBattery

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.battery
                            font.family: Theme.fontFamily
                            font.pointSize: Fluent.captionSize
                            color: Theme.textOnSurface
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `${root.batteryPercent}%`
                            font.family: Theme.fontFamily
                            font.pointSize: Fluent.captionSize
                            color: Theme.textOnSurface
                        }
                    }

                    Item {
                        id: gear

                        anchors.right: parent.right
                        anchors.rightMargin: Fluent.quickPadding - 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 32

                        Rectangle {
                            anchors.fill: parent
                            radius: Fluent.controlRadius
                            color: gearPointer.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.settings
                            font.family: Theme.fontFamily
                            font.pointSize: Fluent.captionSize
                            color: Theme.textOnSurface
                        }

                        MouseArea {
                            id: gearPointer

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                SettingsState.open();
                                root.dismissRequested();
                            }
                        }
                    }
                }
            }
        }
    }

    signal subPageRequested(string page)
    signal dismissRequested
}
