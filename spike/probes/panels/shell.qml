// PROBE: the four treatments side by side, on one surface, over one backdrop.
//
// Every panel is drawn with the SAME paint -- a rounded rectangle plus the
// shell's own CornerWedge on each top corner -- so the only thing that differs
// between them is where the frosted backdrop comes from:
//
//   0  nothing. No blur at all, which is what the desktop had before any of
//      this and what reverting goes back to.
//   1  ext-background-effect, region flush with the paint. The staircase.
//   2  ext-background-effect, region inset one pixel. The unblurred ring.
//   3  no compositor blur at all: a pre-blurred copy of the WALLPAPER, drawn
//      as this panel's own backdrop and masked with the same antialiased
//      shape the paint uses.
//
// Treatment 3 is only defensible because niri's blur is xray by default --
// verified in probes/xray and in niri's own source -- so what the compositor
// would have put there is the blurred wallpaper and nothing else.
//
// Coordinates are written out rather than anchored, because the blur regions
// below have to name the same numbers and a wl_region is surface-local.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "components"

ShellRoot {
    Variants {
        model: Quickshell.screens.filter(s => s.name === "DP-3")

        PanelWindow {
            id: probe

            required property var modelData

            readonly property int pw: 520
            readonly property int ph: 260
            readonly property int py: 520
            readonly property int rad: 24
            readonly property int fil: 24
            readonly property color tint: Qt.rgba(0.09, 0.09, 0.12, 0.85)
            readonly property string wallblur: "file:///tmp/claude-1000/-home-johan/c11ddbc5-7e23-4a19-8679-729aed84d77c/scratchpad/wallblur-DP-3.png"

            function px(i: int): int {
                return 100 + i * 620;
            }

            screen: modelData
            WlrLayershell.namespace: "blur-spike-panels"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}

            // Treatment 1 flush, treatment 2 inset by one pixel. Treatments 0
            // and 3 ask for nothing and are absent from this region.
            BackgroundEffect.blurRegion: Region {
                intersection: Intersection.Combine

                // -- 1: flush --
                Region {
                    x: probe.px(1)
                    y: probe.py
                    width: probe.pw
                    height: probe.ph
                    bottomLeftRadius: probe.rad
                    bottomRightRadius: probe.rad
                    intersection: Intersection.Combine
                }
                Region {
                    x: probe.px(1) - probe.fil
                    y: probe.py
                    width: probe.fil
                    height: probe.fil
                    intersection: Intersection.Combine

                    Region {
                        shape: RegionShape.Ellipse
                        intersection: Intersection.Subtract
                        x: probe.px(1) - probe.fil * 2
                        y: probe.py
                        width: probe.fil * 2
                        height: probe.fil * 2
                    }
                }
                Region {
                    x: probe.px(1) + probe.pw
                    y: probe.py
                    width: probe.fil
                    height: probe.fil
                    intersection: Intersection.Combine

                    Region {
                        shape: RegionShape.Ellipse
                        intersection: Intersection.Subtract
                        x: probe.px(1) + probe.pw
                        y: probe.py
                        width: probe.fil * 2
                        height: probe.fil * 2
                    }
                }

                // -- 2: one pixel in, the way master does it --
                Region {
                    x: probe.px(2) + 1
                    y: probe.py
                    width: probe.pw - 2
                    height: probe.ph - 1
                    bottomLeftRadius: probe.rad - 1
                    bottomRightRadius: probe.rad - 1
                    intersection: Intersection.Combine
                }
                Region {
                    x: probe.px(2) - probe.fil
                    y: probe.py
                    width: probe.fil
                    height: probe.fil
                    intersection: Intersection.Combine

                    Region {
                        shape: RegionShape.Ellipse
                        intersection: Intersection.Subtract
                        x: probe.px(2) - probe.fil * 2 - 1
                        y: probe.py - 1
                        width: probe.fil * 2 + 2
                        height: probe.fil * 2 + 2
                    }
                }
                Region {
                    x: probe.px(2) + probe.pw
                    y: probe.py
                    width: probe.fil
                    height: probe.fil
                    intersection: Intersection.Combine

                    Region {
                        shape: RegionShape.Ellipse
                        intersection: Intersection.Subtract
                        x: probe.px(2) + probe.pw - 1
                        y: probe.py - 1
                        width: probe.fil * 2 + 2
                        height: probe.fil * 2 + 2
                    }
                }
            }

            // -- treatment 3's backdrop: the wallpaper, blurred here, cut to
            // the shape with a mask that has coverage.
            //
            // THE TINT IS INSIDE THIS LAYER, not painted over it afterwards.
            // Two masked layers stacked would put the backdrop's own coverage
            // in front of the glass at the boundary: at a half covered pixel
            // the wallpaper would arrive at 0.5 rather than at 0.5 * 0.15, and
            // the edge picks up a bright fringe of the difference -- measured
            // at 35 levels out of 255 against a dark window, which is the same
            // order as the staircase this route exists to avoid. Composited
            // first and masked once, the boundary pixel is exactly
            // coverage * (tint over wallpaper), which is what the paint means.
            Item {
                id: wallSource

                x: probe.px(3) - probe.fil
                y: probe.py
                width: probe.pw + probe.fil * 2
                height: probe.ph
                visible: false
                layer.enabled: true

                Image {
                    x: -(probe.px(3) - probe.fil)
                    y: -probe.py
                    source: probe.wallblur
                    cache: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: probe.tint
                }
            }

            Item {
                id: wallShape

                x: probe.px(3) - probe.fil
                y: probe.py
                width: probe.pw + probe.fil * 2
                height: probe.ph
                visible: false
                layer.enabled: true
                clip: true

                Rectangle {
                    x: probe.fil
                    y: -probe.rad
                    width: probe.pw
                    height: probe.ph + probe.rad
                    radius: probe.rad
                    antialiasing: true
                    color: "black"
                }

                CornerWedge {
                    x: 0
                    y: 0
                    corner: "topRight"
                    radius: probe.fil
                    fillColor: "black"
                }

                CornerWedge {
                    x: probe.fil + probe.pw
                    y: 0
                    corner: "topLeft"
                    radius: probe.fil
                    fillColor: "black"
                }
            }

            MultiEffect {
                x: wallSource.x
                y: wallSource.y
                width: wallSource.width
                height: wallSource.height

                source: wallSource
                maskEnabled: true
                maskSource: wallShape
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            // Labels, outside the clipped groups below.
            Repeater {
                model: 4

                Text {
                    required property int index

                    x: probe.px(index)
                    y: probe.py - 70
                    color: "#ff00ff"
                    font.pixelSize: 26
                    text: ["0 no blur", "1 region flush", "2 region inset 1px", "3 wallpaper, masked"][index]
                }
            }

            // -- the paint, identical for all four --
            Repeater {
                model: 4

                Item {
                    id: paint

                    required property int index

                    x: probe.px(paint.index) - probe.fil
                    y: probe.py
                    width: probe.pw + probe.fil * 2
                    height: probe.ph
                    clip: true

                    // Treatment 3 draws its glass inside the masked layer
                    // above, tint and all, so it must not be painted twice.
                    visible: paint.index !== 3

                    Rectangle {
                        x: probe.fil
                        y: -probe.rad
                        width: probe.pw
                        height: probe.ph + probe.rad
                        radius: probe.rad
                        antialiasing: true
                        color: probe.tint
                    }

                    CornerWedge {
                        x: 0
                        y: 0
                        corner: "topRight"
                        radius: probe.fil
                        fillColor: probe.tint
                    }

                    CornerWedge {
                        x: probe.fil + probe.pw
                        y: 0
                        corner: "topLeft"
                        radius: probe.fil
                        fillColor: probe.tint
                    }

                }
            }
        }
    }
}
