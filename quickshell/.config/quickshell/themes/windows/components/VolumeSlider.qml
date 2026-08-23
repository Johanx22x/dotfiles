// How the windows theme draws a volume slider: Windows' own Slider, which is a
// four-pixel rail with a twenty-two pixel round thumb sitting on it and an
// accent dot inside the thumb that changes size with the pointer. The public
// half -- the range, the units, what `notch` means and why the wheel is off on
// the sound page -- is components/VolumeSlider.qml.
//
// THE TWO PROMISES THIS FILE KEEPS, both of which the facade can require no
// property for:
//
//   A CLICK JUMPS AND A DRAG FOLLOWS. `onPressed` and `onPositionChanged` both
//   report, so there is one gesture and no dead zone on the rail where pressing
//   does nothing.
//
//   THE WHEEL'S ANSWER IS HANDED BACK. `event.accepted` is assigned what
//   row.wheel() returned, every time. Dropping it -- or writing an empty
//   handler, which looks like the same thing -- turns the sound page's sliders
//   into dead patches that swallow the notch instead of scrolling the page. The
//   facade's wheel() has the long version.
//
// AND THE ARITHMETIC THAT USED TO BE UPSTAIRS IS DOWN HERE NOW. moveTo() takes
// a share of the rail, 0 to 1, and the rail is one this file drew. Under this
// theme the row is 32 tall -- Windows' own Slider height -- so the hit area is
// the whole row rather than a thin strip widened by negative margins, and the
// share is a plain `x / width` with no inset to correct for. A theme that goes
// back to a thin rail has to put the correction back with it.
//
// ---------------------------------------------------------------------------
// THE INNER DOT, AND MICROSOFT DISAGREEING WITH ITSELF
// ---------------------------------------------------------------------------
//
// The thumb is a 22px circle with a smaller accent circle inside it, and the
// inner one is 12 at rest, 14 under the pointer and 10 while pressed. Those
// three numbers are the COMMENTS in Microsoft's own Slider XAML; the scale
// transforms next to them render 10.3, 14 and 8.5. Fluent.qml carries the
// intent, for the reason it gives at its own line: the intent is what Windows
// looks like, and the code is one of the two that is going to be corrected.
//
// THE RESIZE IS THE ONE THING HERE THAT ANIMATES, at ControlFasterAnimationDuration
// -- 83ms on WinUI's single easing spline. Everything else in this file swaps
// instantly, because hover in Windows 11 is a DiscreteObjectKeyFrame at time
// zero and Fluent.hoverMs is 0 to say so.
//
// ---------------------------------------------------------------------------
// THE RAIL COLOUR IS THE CALL SITE'S AND MICROSOFT WANTS ANOTHER ONE
// ---------------------------------------------------------------------------
//
// `SliderTrackFill` is `ControlStrongFillColorDefault` #8BFFFFFF, which is the
// scheme's `Theme.outline`. `row.railColor` defaults to a level below that and
// is API: the island sets it to `Qt.alpha(ink, 0.18)` because it draws this
// slider over COVER ART, where a role derived from a scheme has nothing to do
// with what is behind the rail.
//
// A theme cannot tell a default from a choice -- both arrive as a colour on the
// facade -- so the call site wins and this file reads `row.railColor`. The cost
// is that a slider nobody parameterised comes out one level darker than Windows
// draws it. Fixing that properly means the facade distinguishing "unset" from
// "set to the default", which is a change to the public half and not something
// to smuggle in from this side.

import QtQuick
import qs
// VolumeSlider is components/VolumeSlider.qml -- the facade -- and not this
// file. The explicit import wins over the directory a document implicitly
// imports.
import qs.components
// Fluent lives one directory up. Without this line every `Fluent.` below is a
// ReferenceError at runtime, once per read; tests/qml-rules.sh checks the pair.
import qs.themes.windows

Item {
    id: root

    // The facade, handed in by its Loader as an initial property. Typed and
    // `required` for the reason rule 1 of README.md sets out.
    required property VolumeSlider row

    // WHAT THE FACADE READS BACK. Windows' Slider is 32 tall, which is the same
    // 32 every button, field and combo box in this theme is. The facade floors
    // at 20, so this raises the row rather than being raised by it. Not derived
    // from this item's own height.
    implicitHeight: Fluent.sliderRowHeight

    // How far along the rail the thumb's CENTRE sits. The thumb overhangs both
    // ends by half its width, which is what Windows does: the rail runs edge to
    // edge and the handle is allowed off it.
    readonly property real centreX: rail.width * root.row.fraction

    // ---------------- The rail ----------------
    //
    // Four tall at radius two, which is a capsule. SliderTrackHeight and
    // SliderTrackCornerRadius, both straight out of Slider_themeresources.xaml.
    Rectangle {
        id: rail

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right

        height: Fluent.sliderTrackHeight
        radius: Fluent.sliderTrackRadius
        antialiasing: true
        color: root.row.railColor
    }

    // ---------------- The filled part ----------------
    //
    // AccentFillColorDefault, which under this scheme is SystemAccentColorLight2
    // -- dark mode's accent is the LIGHT shade of the ramp, not the base one.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left

        width: root.centreX
        height: Fluent.sliderTrackHeight
        radius: Fluent.sliderTrackRadius
        antialiasing: true
        color: root.row.accent
    }

    // ---------------- The mark ----------------
    //
    // OVER THE FILL AND UNDER THE THUMB, which is the whole reason it is written
    // here and not before the fill: painted underneath it would disappear at
    // exactly the moment it starts to mean something, which is when the fill has
    // passed it.
    Rectangle {
        visible: root.row.notch > 0 && root.row.notch < root.row.maximum

        x: rail.width * (root.row.notch / root.row.maximum) - width / 2
        anchors.verticalCenter: parent.verticalCenter

        width: 2
        height: Fluent.sliderTrackHeight * 3
        radius: 1

        // See notchColor on the facade: it reads as a gap cut through the bar
        // rather than as a third colour, which works over the rail and over the
        // fill alike where no ink colour does.
        color: root.row.notchColor
    }

    // ---------------- The thumb ----------------
    //
    // 22 VISIBLE, WHICH IS AN 18px ELEMENT WITH A BORDER AT Margin="-2". That is
    // how Slider_themeresources.xaml gets there and it is why the number looks
    // arbitrary; Fluent.sliderThumb carries the visible one.
    //
    // THE LIT EDGE. Windows draws a 1px gradient border round this circle --
    // ControlElevationBorderBrush, a vertical gradient in ABSOLUTE mapping over
    // three pixels, brighter at the TOP in dark mode. Absolute mapping is why
    // the bright stroke stays one pixel wherever the control's height goes, and
    // it is drawn here as an outer circle carrying the gradient with the fill
    // circle inset by one inside it. The stops below convert Microsoft's two
    // absolute offsets into the fractions of this circle they land on.
    Rectangle {
        id: thumb

        x: root.centreX - width / 2
        anchors.verticalCenter: parent.verticalCenter

        width: Fluent.sliderThumb
        height: Fluent.sliderThumb
        radius: width / 2
        antialiasing: true

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, Fluent.elevationTop)
            }
            GradientStop {
                position: Fluent.elevationStop * Fluent.elevationSpan / Fluent.sliderThumb
                color: Qt.rgba(1, 1, 1, Fluent.elevationTop)
            }
            GradientStop {
                position: Fluent.elevationSpan / Fluent.sliderThumb
                color: Qt.rgba(1, 1, 1, Fluent.elevationRest)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, Fluent.elevationRest)
            }
        }

        // The thumb's own body, one pixel inside the gradient so what shows of
        // it is the border.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1

            radius: width / 2
            antialiasing: true
            color: Theme.surfaceContainerHighest
        }

        // ---------------- The dot ----------------
        Rectangle {
            id: dot

            anchors.centerIn: parent

            width: mouse.pressed ? Fluent.sliderDotPress
                : mouse.containsMouse ? Fluent.sliderDotHover
                : Fluent.sliderDotRest
            height: dot.width
            radius: width / 2
            antialiasing: true
            color: root.row.accent

            // ControlFasterAnimationDuration on ControlFastOutSlowInKeySpline,
            // which is the only easing resource WinUI ships.
            Behavior on width {
                NumberAnimation {
                    duration: Fluent.fasterMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Fluent.easeOut
                }
            }
        }
    }

    // ---------------- The target ----------------
    //
    // THE WHOLE ROW, and no negative margins. genesis insets a thin rail's hit
    // area by six pixels and then corrects for the six when it reports; a 32px
    // row is already a fair target, so the correction is gone and the share
    // below is exact.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Both, so a click jumps and a drag follows.
        onPressed: event => root.emit(event.x)
        onPositionChanged: event => {
            if (pressed)
                root.emit(event.x);
        }

        // THE ANSWER IS HANDED BACK, and that assignment is the whole of this
        // theme's part in the wheel. Whether a notch belongs to this slider at
        // all is the facade's decision -- see its wheel() -- and dropping the
        // result here would leave the sound page with a dead strip down every
        // slider instead of a page that scrolls.
        onWheel: event => {
            event.accepted = root.row.wheel(event.angleDelta.y);
        }
    }

    // WHERE THE POINTER IS ALONG THE RAIL, 0 TO 1, WHICH IS ALL THE FACADE
    // WANTS TO KNOW. The facade clamps what comes out of this and multiplies by
    // a maximum this file has no reason to know.
    function emit(x: real): void {
        root.row.moveTo(x / rail.width);
    }
}
