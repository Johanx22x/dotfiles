pragma Singleton

// WINDOWS' OWN NUMBERS, IN ONE PLACE, AND ONLY THE ONES THE SCHEME CANNOT CARRY.
//
// Twenty-nine components and seven surfaces need the same forty constants, and
// forty constants copied twenty-nine times is thirty-six chances to type 4
// where Windows says 8. This file is the single authority for them.
//
// WHAT IS NOT IN HERE, AND WHY IT IS NOT. No colour. Windows' dark ramp is
// already the scheme -- schemes/windows-11-dark.json composites Microsoft's
// alpha overlays onto Microsoft's base and publishes the results as the four
// surface levels, so Theme.surfaceContainerHigh IS
// `ControlFillColorSecondary #15FFFFFF over SolidBackgroundFillColorBase`.
// A second set of colours here would be a second answer to a question that
// already has one, and the two would drift. Read colour from Theme, always.
//
// The one exception proves the rule: `elevationTop` and `elevationRest` below
// are not colours, they are the two ALPHAS of a gradient Windows draws over
// whatever is behind it. There is no scheme role for "seven per cent white",
// because seven per cent white is not a colour until it lands on something.
//
// SIZES ARE ABSOLUTE AND TEXT IS RELATIVE, and that split is the host's rule
// rather than a preference. Theme.fontSize is Config.fontSize -- the number
// `desktop-font` writes and kitty, Zen and GTK all read -- so it belongs to the
// person at the keyboard and not to a theme. Windows' ramp is absolute epx
// (Caption 12, Body 14, Subtitle 20, Title 28) and this file expresses it as
// offsets from whatever the user chose, so the ratios survive and the dial
// still works. The absolute value each offset lands on at the default is
// written beside it.
//
// SOURCES. Everything here is read out of Microsoft's shipping source unless
// its line says otherwise:
//
//   controls/dev/CommonStyles/CornerRadius_themeresources.xaml   the radii
//   controls/dev/CommonStyles/Common_themeresources_any.xaml     motion, strokes
//   controls/dev/CommonStyles/TextBlock_themeresources.xaml      the type ramp
//   controls/dev/CommonStyles/ToggleSwitch_themeresources.xaml   the switch
//   controls/dev/CommonStyles/Slider_themeresources.xaml         the slider
//   controls/dev/CommonStyles/ScrollBar_themeresources.xaml      the scroll bar
//   controls/dev/NavigationView/NavigationView_themeresources.xaml
//   CommunityToolkit/Windows components/SettingsControls          the cards
//   dxaml/xcp/components/graphics/inc/DropShadowRecipe.h          the shadows
//
// A NUMBER MICROSOFT DOES NOT PUBLISH IS MARKED `OURS`. The taskbar is shell
// chrome and has no public design documentation at all, so every taskbar
// figure below is measured off a screenshot or read out of the C++ of a
// Windhawk mod that replicates stock behaviour. Those two kinds of number must
// not be allowed to look alike: one can be checked and the other is a design
// decision, and a reader six months from now cannot tell them apart unless
// this file says which is which.

// HOW A COMPONENT REACHES THIS FILE, AND THE ONE LINE IT MUST CARRY.
//
//     import ".."
//
// A file under components/ has an implicit import of components/ and of
// nothing else. Without that line `Fluent` is not in scope, and the way it
// fails is at RUNTIME, per read:
//
//     WARN scene: @themes/windows/components/Chip.qml[3:-1]:
//                 ReferenceError: Fluent is not defined
//
// MEASURED, NOT ASSUMED. Two copies of one component in a scratch tree under
// labwc, one with the import and one without. With it the read returns 4.
// Without it, the ReferenceError above.
//
// qmllint DOES catch it, as [unqualified], and the import is NOT reported
// unused once something actually reads through it -- both directions checked
// the same way, by putting a real read into a real component and running
// tests/qml-lint.sh over it. An earlier note here claimed the opposite in both
// directions and it was wrong: the edit that was supposed to insert the read
// had been anchored on a string the file does not contain, so what got
// measured was an import with nothing using it. Which is the failure this
// repository keeps meeting from the other side -- a harness that passes over
// nothing -- arriving this time in the measurement rather than in the test.
//
// tests/qml-rules.sh checks the pairing anyway, and the reason is the budget
// rather than the coverage: [windows:unqualified] sits at 130 today and is
// going to move on almost every commit while this theme is being drawn, so a
// missing import is +1 against a number somebody is already editing. A rule
// that names the file and the singleton does not get absorbed into a baseline
// edit the way a single count does.
//
import QtQuick
import qs

QtObject {
    id: root

    // --- GEOMETRY: the two radii, and there is no third ----------------------
    //
    // Fluent 2's whole radius ramp is 0/2/4/6/8/12/16/24/32. THERE IS NO 7
    // ANYWHERE IN WINDOWS 11 -- a 7 measured off a screenshot is an 8px outer
    // arc minus the 1px border sitting inside it.
    readonly property int controlRadius: 4    // ControlCornerRadius: buttons, fields, list backplates
    readonly property int overlayRadius: 8    // OverlayCornerRadius: windows, flyouts, dialogs, menus

    // ToolTip is Microsoft's own documented exception -- 4 and not 8, "due to
    // its small size" -- and it is worth naming rather than leaving a reader to
    // wonder whether the tooltip was simply missed.
    readonly property int tooltipRadius: root.controlRadius

    // --- TYPE: offsets from the user's size, absolute value at the default ---
    //
    // Windows sets NO line heights. The *TextBlockStyle styles carry family,
    // size and weight and nothing else; the published line heights are what
    // Segoe's own metrics produce. With any substitute face they have to be set
    // explicitly or the vertical rhythm drifts, which is why they are here.
    readonly property real captionSize: Theme.fontSize - 2      // 12 at the default
    readonly property real bodySize: Theme.fontSize             // 14
    readonly property real bodyLargeSize: Theme.fontSize + 4    // 18
    readonly property real subtitleSize: Theme.fontSize + 6     // 20
    readonly property real titleSize: Theme.fontSize + 14       // 28

    readonly property real captionLine: Math.round(root.captionSize * 16 / 12)
    readonly property real bodyLine: Math.round(root.bodySize * 20 / 14)
    readonly property real bodyLargeLine: Math.round(root.bodyLargeSize * 24 / 18)
    readonly property real subtitleLine: Math.round(root.subtitleSize * 28 / 20)
    readonly property real titleLine: Math.round(root.titleSize * 36 / 28)

    // Semibold and NEVER Bold: that is Windows 11's typography rule in as many
    // words. Theme.fontWeight is the theme's own token and windows/theme.json
    // sets it to 600, so this reads it rather than repeating the number.
    readonly property int strongWeight: Theme.fontWeight
    readonly property int normalWeight: Font.Normal

    // --- MOTION: three durations and one spline, and that is the whole set ---
    //
    // WinUI ships exactly one easing resource, ControlFastOutSlowInKeySpline
    // = 0,0,0,1. There is no ControlSlowAnimationDuration; the shell spec adds
    // cubic-bezier(1,0,1,1) for gentle exits and (0.55,0.55,0,1) for
    // point-to-point moves, and those are the only other two curves in the
    // system.
    readonly property int fasterMs: 83
    readonly property int fastMs: 167     // == Theme.animDuration under this theme
    readonly property int normalMs: 250

    // Qt takes a cubic bezier as the two control points, flattened.
    readonly property var easeOut: [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]        // 0,0,0,1
    readonly property var easeGentleExit: [1.0, 0.0, 1.0, 1.0, 1.0, 1.0] // 1,0,1,1
    readonly property var easePointToPoint: [0.55, 0.55, 0.0, 1.0, 1.0, 1.0]

    // HOVER IS NOT IN THAT LIST, and leaving it out is the single most
    // load-bearing line in this file. Windows swaps a control's brush on a
    // `DiscreteObjectKeyFrame KeyTime="0"` -- instantly, with no transition at
    // all. Reveal was Windows 10 and is dead; the SystemReveal* resources still
    // exist as unreferenced legacy keys. A 150ms fade on hover is the tell that
    // gives away a recreation faster than any wrong colour, because every
    // Windows control in the same session is doing it without one.
    readonly property int hoverMs: 0

    // --- STATE: which way the fills move ------------------------------------
    //
    // Hover BRIGHTENS and press DIMS. #15FFFFFF over #08FFFFFF, and the same
    // relationship in light mode with black. Getting it the other way round is
    // the second-best tell after animating the hover. These name the scheme
    // levels rather than restating them so that there is one place to look when
    // somebody asks what level 3 is for.
    readonly property color fillRest: Theme.surfaceContainer
    readonly property color fillHover: Theme.surfaceContainerHigh
    readonly property color fillPress: Theme.surface
    readonly property color fillSubtleHover: Theme.surfaceContainerHigh
    readonly property real disabledOpacity: 0.4

    // --- THE LIT EDGE -------------------------------------------------------
    //
    // ControlElevationBorderBrush: a vertical gradient in ABSOLUTE mapping over
    // 3px, stop 0.33 at ControlStrokeColorSecondary and stop 1.0 at
    // ControlStrokeColorDefault. Absolute mapping is why the brighter stroke
    // occupies the top ~1px whatever the control's height is.
    //
    // In DARK the emphasis is at the TOP and there is no flip. In light the
    // same brush carries ScaleY=-1 and the emphasis is at the bottom. But the
    // ACCENT variant keeps the flip in dark, so an accent button gets a dark
    // bottom edge while the neutral button beside it has a light top one --
    // they disagree on purpose and copying one onto the other is wrong.
    readonly property real elevationTop: 0.094     // #18FFFFFF
    readonly property real elevationRest: 0.071    // #12FFFFFF
    readonly property real elevationStop: 0.33
    readonly property int elevationSpan: 3
    readonly property real accentEdgeBottom: 0.137 // #23000000, black

    // Pressed drops the gradient to a flat stroke. That, and not any movement,
    // is what reads as "pushed in".

    // --- SHADOWS ------------------------------------------------------------
    //
    // DERIVED, NOT MEASURED. DropShadowRecipe.h gives elevation = z/2, a
    // directional shadow blurred by the elevation and offset down by half of
    // it, and a dark-theme opacity of 0.26 below elevation 16. ElevationHelper
    // gives the depths: flyout 32, tooltip 16, card 8. Dark shadows are about
    // twice as opaque as light ones, which the layering docs acknowledge
    // without quantifying and the source quantifies.
    readonly property real shadowOpacity: 0.26
    readonly property int cardShadowBlur: 4
    readonly property int cardShadowY: 2
    readonly property int tooltipShadowBlur: 8
    readonly property int tooltipShadowY: 4
    readonly property int flyoutShadowBlur: 16
    readonly property int flyoutShadowY: 8

    // --- CONTROLS -----------------------------------------------------------

    // ToggleSwitch. The pressed thumb is a squished pill: WIDER, not taller.
    readonly property int switchTrackWidth: 40
    readonly property int switchTrackHeight: 20
    readonly property int switchThumbRest: 12
    readonly property int switchThumbHover: 14
    readonly property int switchThumbPressWidth: 17
    readonly property int switchThumbPressHeight: 14
    readonly property int switchTravel: 20

    // Slider. The visible thumb is 22 because the 18px element carries a
    // Border with Margin="-2". The inner dot's published scales and Microsoft's
    // own comments beside them disagree -- the code renders 10.3/14/8.5 and the
    // comments say the intent was 12/14/10. The intent is what Windows looks
    // like, so the intent is what is here.
    readonly property int sliderTrackHeight: 4
    readonly property int sliderTrackRadius: 2
    readonly property int sliderThumb: 22
    readonly property int sliderDotRest: 12
    readonly property int sliderDotHover: 14
    readonly property int sliderDotPress: 10
    readonly property int sliderRowHeight: 32

    // Button, ComboBox and TextBox all sit at 32.
    readonly property int controlHeight: 32
    readonly property int controlPaddingH: 11
    readonly property int fieldPaddingLeft: 10

    // TextBox focus: the border goes 1,1,1,2 with the bottom edge in accent and
    // the fill INVERTS to a near-opaque dark rather than brightening. And it
    // happens instantly -- DiscreteObjectKeyFrame at time zero, like the hover.
    readonly property int focusUnderline: 2

    // CheckBox and RadioButton.
    readonly property int checkBox: 20
    readonly property int checkGlyph: 12

    // --- NAVIGATION AND CARDS -----------------------------------------------
    //
    // The selection indicator is 3x16 at radius 2, flush with the pill's left
    // edge and vertically centred. THE SELECTED PILL'S FILL IS IDENTICAL TO THE
    // HOVER FILL -- selection is carried entirely by this bar, and a
    // recreation that gives selection its own backplate colour has invented a
    // state Windows does not have.
    readonly property int navItemHeight: 36
    readonly property int navItemPitch: 40
    readonly property int navIconColumn: 40
    readonly property int navIcon: 16
    readonly property int navLabelLeft: 48
    readonly property int indicatorWidth: 3
    readonly property int indicatorHeight: 16
    readonly property int indicatorRadius: 2

    // SettingsCard, verbatim from the Community Toolkit. Cards STACK WITH A GAP
    // and stay fully rounded; they do not join. The top-rounds/middle-squares
    // rule exists only INSIDE a SettingsExpander.
    readonly property int cardMinHeight: 68
    readonly property int cardPadding: 16
    readonly property int cardIconMax: 20
    readonly property int cardIconGap: 20
    readonly property int cardActionGutter: 24
    readonly property int expanderChildHeight: 52
    readonly property int expanderChildIndent: 58

    // --- SCROLL BAR ---------------------------------------------------------
    //
    // A 2px line at rest inside a 12px gutter, expanding to 6px. The thumb
    // colour is the same in rest, hover and press: the affordance is entirely
    // the width and the track fading in behind it.
    readonly property int scrollGutter: 12
    readonly property int scrollLineRest: 2
    readonly property int scrollLineHover: 6
    readonly property int scrollThumbMin: 30
    readonly property int scrollRadius: 3
    readonly property int scrollExpandDelayMs: 400
    readonly property int scrollContractDelayMs: 500

    // --- TASKBAR: OURS. Microsoft publishes none of this ---------------------
    //
    // The running indicator's HEIGHT is the one figure with a real source: the
    // literal `3` in taskbar-labels.wh.cpp, which reads stock geometry. Its
    // widths are corroborated across a Windhawk XAML dump and a CSS clone but
    // are not published anywhere, and every value found in a Windhawk theme is
    // an artistic override rather than a baseline. The button box and the
    // hover fill are read off screenshots.
    //
    // Two things research did settle, and both are negatives worth keeping:
    // the taskbar does NOT change material when a window is maximised, and
    // there is no separate "several windows" indicator state.
    readonly property int taskButton: 40
    readonly property int indicatorRunningWidth: 6
    readonly property int indicatorFocusedWidth: 16
    readonly property int indicatorThickness: 3
    readonly property int indicatorBottomGap: 2
}
