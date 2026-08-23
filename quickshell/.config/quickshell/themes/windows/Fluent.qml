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
//     import qs.themes.windows
//
// AND NOT `import ".."`, WHICH LOOKS RIGHT, PASSES EVERY STATIC CHECK, AND
// FAILS SILENTLY. This is worth the space because it cost a full round of
// wrong conclusions and because nothing in the tree would have caught it.
//
// The relative import works when a file is loaded as a TYPE FROM A MODULE, and
// does not when the same file is loaded BY URL. Every theme file is loaded by
// URL: ThemeSurface calls setSource on the seven surfaces, and each of the
// twenty-nine facades calls setSource on its component. So the one path that
// works is the one no theme file is ever on.
//
// The failure has no error attached to it. `Fluent` still resolves --
// `typeof Fluent` is "object" -- but it resolves to the TYPE rather than to
// the singleton instance, so every property reads `undefined`. What reaches
// the log is one line per binding, naming the consumer and never this file:
//
//     WARN scene: .../components/ScrollBar.qml[109:5]:
//                 Unable to assign [undefined] to double
//
// MEASURED BOTH WAYS on the whole theme under labwc, with the theme selected
// and everything built: relative imports 2240 of those warnings in eighteen
// seconds, module imports ZERO. Not a sample, not a reading of one file.
//
// WHAT IT COSTS, SAID PLAINLY. A theme that spells its own name in an import
// cannot be copied with `cp -r` -- the copy keeps importing THIS theme's
// singleton, which is the exact hazard genesis avoids by reaching its own
// parts relatively. Genesis is unaffected because it imports its own
// directories for TYPES, and a type resolves either way; only a singleton's
// properties need the module. If this theme is ever the seed for another, the
// import line is the thing to rewrite, and there are forty-four of them.
//
// tests/qml-rules.sh enforces the pairing and it enforced the WRONG ONE for a
// while: written before this was measured, it required `import ".."` and would
// have sent anyone who fixed the bug back into it.
//
import QtQuick
import qs

QtObject {
    id: root

    // --- MATERIAL: THE BAR AND THE FLYOUTS ARE NOT THE SAME TRANSPARENCY ----
    //
    // Measured off photographs, not off the docs, and the docs would have led
    // the other way: Microsoft describes one acrylic recipe and it is the same
    // recipe for both. What the pictures show is that the TASKBAR carries the
    // wallpaper's colour plainly -- a blue wallpaper gives a blue-tinged bar --
    // while a FLYOUT over the same wallpaper stays a fairly solid grey. Same
    // material, two results, because the taskbar sits on the desktop and a
    // flyout sits on whatever is under it.
    //
    // One reference agent put it best after collecting thirty-four of these:
    // "acrylic is not one number". A taskbar menu over magenta goes visibly
    // purple; a desktop watermark reads straight through a volume flyout; a
    // flyout over red stays stubbornly neutral. Getting the value right from
    // the XAML would not have saved us.
    //
    // So the bar uses Theme.glass(), which the theme's surfaceAlpha token
    // drives, and everything that opens ON TOP of something uses this. The
    // difference is not decoration: at the bar's transparency a launcher panel
    // showed the file manager's sidebar through itself, legibly.
    readonly property real flyoutAlpha: 0.94

    function acrylic(colour: color): color {
        return Qt.alpha(colour, root.flyoutAlpha);
    }

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

    // --- TYPE: RATIOS of the user's size, and the units are not the same ---
    //
    // THIS BLOCK USED TO ADD AND IT WAS WRONG TWICE OVER. It read
    // `captionSize: Theme.fontSize - 2` with "12 at the default" beside it,
    // on two assumptions that do not hold:
    //
    //   1. that Theme.fontSize is 14. It is Config.fontSize, whose default is
    //      ELEVEN (Config.qml), so every "absolute value at the default"
    //      written here named a number the file never computed.
    //   2. that an offset preserves a ratio. It does not. Windows' ramp is
    //      12 / 14 / 18 / 20 / 28, which is multiplicative; a fixed offset
    //      tracks it at the small end and drifts badly at the large one. The
    //      old titleSize came out 19% short.
    //
    // Ratios fix both, and they are ratios of BODY because that is what
    // Windows' ramp is a ramp of.
    //
    // AND THE UNITS ARE NOT THE SAME, WHICH IS THE PART THAT BITES. Windows
    // publishes its ramp in epx, which are pixels at 96 DPI. Theme.fontSize is
    // a POINT size, because it is shared with kitty. 11 pt is 14.67 epx, which
    // is why Body lands close to Windows' 14 without anybody arranging it.
    // So: everything named *Size below is POINTS and goes to font.pointSize,
    // and everything named *Line is PIXELS and goes to a height or to
    // lineHeight with Text.FixedHeight. Mixing them silently sets a line box
    // three quarters the size of the glyphs in it.
    readonly property real captionSize: Theme.fontSize * 12 / 14
    readonly property real bodySize: Theme.fontSize
    readonly property real bodyLargeSize: Theme.fontSize * 18 / 14
    readonly property real subtitleSize: Theme.fontSize * 20 / 14
    readonly property real titleSize: Theme.fontSize * 2          // 28 / 14

    // Windows sets NO line heights. The *TextBlockStyle styles carry family,
    // size and weight and nothing else; the published line heights are what
    // Segoe's own metrics produce. With any substitute face they have to be
    // set explicitly or the vertical rhythm drifts, which is why they are here.
    //
    // The 4/3 is points to pixels. Prefer the *Ratio properties below where a
    // Text will take them: a ratio has no unit and so cannot be got wrong.
    readonly property real captionLine: Math.round(root.captionSize * 16 / 12 * 4 / 3)
    readonly property real bodyLine: Math.round(root.bodySize * 20 / 14 * 4 / 3)
    readonly property real bodyLargeLine: Math.round(root.bodyLargeSize * 24 / 18 * 4 / 3)
    readonly property real subtitleLine: Math.round(root.subtitleSize * 28 / 20 * 4 / 3)
    readonly property real titleLine: Math.round(root.titleSize * 36 / 28 * 4 / 3)

    // The same five as unit-free multipliers, for
    // `lineHeightMode: Text.ProportionalHeight`.
    readonly property real captionLineRatio: 16 / 12
    readonly property real bodyLineRatio: 20 / 14
    readonly property real bodyLargeLineRatio: 24 / 18
    readonly property real subtitleLineRatio: 28 / 20
    readonly property real titleLineRatio: 36 / 28

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

    // MenuFlyoutPresenterThemeMinWidth. A flyout does not shrink to its widest
    // label: three short words would otherwise give a menu barely wider than
    // the words in it, which is not a shape Windows ever draws.
    readonly property int menuMinWidth: 128

    // SettingsCard, verbatim from the Community Toolkit. Cards STACK WITH A GAP
    // and stay fully rounded; they do not join. The top-rounds/middle-squares
    // rule exists only INSIDE a SettingsExpander.
    readonly property int cardMinHeight: 68
    readonly property int cardPadding: 16
    readonly property int cardIconMax: 20
    readonly property int cardIconGap: 20
    readonly property int cardActionGutter: 24

    // SettingsCardContentMinWidth. Applied to every Slider, ComboBox and
    // TextBox a card holds, so that a stack of cards lines its controls up
    // down the right-hand edge instead of each one ending where its content
    // happens to.
    readonly property int cardContentMinWidth: 120
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
    readonly property int taskIcon: 24

    // The Start mark: four panes with a one-pixel gutter. OURS, measured off a
    // close-up -- the logo reads a shade smaller than an application icon
    // beside it, which is what keeps it from looking like a grid button.
    readonly property int startMark: 19
    readonly property int startGutter: 2

    // THE TASKBAR CORNER. Its items are shorter than the bar and share one
    // hover backplate each; the whole group sits at the right edge with the
    // clock last. OURS, measured off a close-up: the icons are the same 16 the
    // rest of Windows draws symbols at, the items are 34 tall inside a 48 bar,
    // and the padding is what separates a glyph from its own backplate's edge.
    readonly property int trayItemHeight: 34
    readonly property int trayIcon: 16
    readonly property int trayPadding: 8
    readonly property int badgeHeight: 14

    // ---- THE SEARCH FLYOUT ----
    //
    // OURS. Microsoft publishes nothing about this screen: it is a WebView2
    // surface rather than XAML, which is verifiable from the Windhawk styler
    // mod that matches its source URL. Measured off a photograph of it.
    //
    // THE FIELD IS A PILL and that is the number that matters here. The
    // Settings search box is a 4px box; this one is fully rounded, and it is
    // among the first things the eye reads on the screen.
    readonly property int searchFieldHeight: 40
    readonly property int chipHeight: 30
    readonly property int resultRowHeight: 44
    readonly property int resultBestHeight: 62
    readonly property int resultIcon: 24
    readonly property int resultBestIcon: 32
    readonly property int previewIcon: 64

    // ---- QUICK SETTINGS ----
    //
    // OURS, measured off a photograph. Microsoft publishes nothing about this
    // panel, and the shape it publishes elsewhere would have led the wrong
    // way: a tile is a WIDE RECTANGLE with its label OUTSIDE it, not a square
    // with the word inside.
    readonly property int quickWidth: 360
    readonly property int quickPadding: 16
    readonly property int quickCardGap: 8
    readonly property int quickTileGap: 8
    readonly property int quickTileHeight: 48
    readonly property int quickTileLabelGap: 6
    readonly property int quickTileChevron: 40
    readonly property int quickSliderHeight: 52
    readonly property int quickFooterHeight: 48
    readonly property int quickMediaHeight: 156

    // The hidden-icons flyout behind the corner's chevron. OURS.
    readonly property int trayOverflowCell: 44

    // The clipboard history, Win+V. OURS -- Windows draws it as a flyout of
    // rounded tiles and publishes no metric for any of them.
    readonly property int clipboardCardHeight: 64
    readonly property int clipboardGap: 6
    // CORRECTED AGAINST A PHOTOGRAPH. These were 6 and 16 and 3, taken from a
    // Windhawk mod's source -- and every published width for this indicator
    // comes from a mod that REDESIGNS it into a pill or a bubble. A close-up
    // of a real taskbar shows the running state is a small DIM DOT, not a
    // short pill: about four pixels wide against sixteen for the focused bar,
    // and dim enough that it reads as a dot rather than as a line.
    readonly property int indicatorRunningWidth: 4
    readonly property int indicatorFocusedWidth: 16
    readonly property int indicatorThickness: 3
    readonly property int indicatorBottomGap: 3

    // ---- A MODAL PAGE OVER THE DESKTOP -------------------------------------
    //
    // OURS. Microsoft publishes no margin between a window and the edge of the
    // screen, and these two windows are not ones anybody can drag: the
    // cheatsheet and the wallpaper picker are Settings-shaped pages laid over
    // the desktop with the smoke behind them. 60 is the breathing room that
    // makes such a page read as a window ON the desktop rather than as a new
    // desktop.
    //
    // IN HERE BECAUSE TWO SURFACES READ IT. It was written twice, once in each
    // of them, with a comment in each saying it agreed with the other -- which
    // is the arrangement this file exists to end.
    readonly property int sheetMargin: 60

    // A SETTINGS PAGE IS CAPPED, AND THE NUMBER IS PUBLISHED. The Community
    // Toolkit's SettingsPageExample.xaml -- the sample the official docs point
    // at -- wraps the whole page in MaxWidth="1000", which is why a Settings
    // window maximised on a 2560-wide monitor still lays its cards out down the
    // left. It is why the cheatsheet's one column does not become a line length
    // nobody can track back from.
    readonly property int pageMaxWidth: 1000

    // SettingsSectionHeaderTextBlockStyle, verbatim from the same file:
    // BodyStrong with Margin="1,30,0,6". The 30 above and the 6 below are the
    // whole of the rhythm of a Settings page -- what separates one group from
    // the next without a rule, a tint or a box.
    readonly property int sectionHeaderAbove: 30
    readonly property int sectionHeaderBelow: 6

    // ---- A LINE OF TEXT THAT IS NOT IN A CONTROL ---------------------------
    //
    // OURS, and a decision rather than a measurement, so it says so. The
    // definition list on the About page -- "Edition / Windows 11 Home Single
    // Language" -- runs at a pitch of about 1.75 line boxes in
    // settings-system-about.jpg. That is right for the five rows an expander
    // holds and wrong for the eleven a monitor card stacks: at 1.75 that card
    // runs past four hundred pixels before the first control on it. So this is
    // the tighter option -- four pixels above the line box and four below --
    // and the pitch that follows is about 1.2 boxes.
    //
    // A two-line search result gets the same leading for the same reason, and
    // it is the number that has to land inside resultRowHeight above.
    readonly property int textLeading: 4

    // ---- THE FRAMED STRIP WINDOWS CALLS AN InfoBar -------------------------
    //
    // OURS. WinUI ships an InfoBar and none of the sources listed at the top of
    // this file was read for these two numbers -- its resource dictionary is
    // not among them -- so they are a design decision and are marked as one.
    // What they aim at is the shape every framed strip in the Settings
    // photographs has: a one-pixel frame at the control radius, a tinted fill
    // of the strip's own colour, and the glyph, the sentence and the buttons on
    // one line inside it.
    //
    // The four-pixel inset the frame is pulled in by is NOT here. That one is
    // the host's, and modules/settings/pages/display/PendingBanner.qml is both
    // where it is written down and where it says the inset is the theme's to
    // draw.
    readonly property int bannerPadding: 8
    readonly property real bannerTint: 0.12

    // ---- HOW FAR A FLYOUT FLOATS OFF THE TASKBAR ---------------------------
    //
    // OURS, measured off ref/tray-volume-flyout.jpg: on a 1600px-wide shot of a
    // 1920 desktop the volume flyout's right edge stands about 13px clear of
    // the screen edge, which is a shade over fifteen at full size. Windows
    // leaves the same air at the bar. Twelve is the Fluent ramp's value nearest
    // that and it is what components/Popout.qml holds the panel off by, on all
    // four sides so that the clamp at the screen edge gets the same clearance
    // the bar does.
    //
    // It is here rather than in theme.json because it is a fact about how this
    // theme draws a flyout, not a knob: the host's Popout has no idea a gap
    // exists and could not use one.
    readonly property int flyoutInset: 12

    // ---- THE SCROLL BAR'S TWO OTHER TIMES ----------------------------------
    //
    // The delays are already in the SCROLL BAR block above; these are what
    // happens once a delay is up. ScrollBar_themeresources.xaml:
    // ScrollBarExpandDuration and ScrollBarContractDuration are both
    // 00:00:00.167 -- the same ControlFastAnimationDuration as `fastMs` -- and
    // ScrollBarOpacityChangeDuration is 00:00:00.083, which is `fasterMs`.
    // They are named here so a reader of components/ScrollBar.qml is not left
    // to work out which of the three durations is which by elimination.
    readonly property int scrollExpandMs: root.fastMs
    readonly property int scrollTrackFadeMs: root.fasterMs

    // ---- THE SEGMENTED LEVEL METER -----------------------------------------
    //
    // OURS, ALL OF IT. Windows has no level meter: the volume mixer draws a
    // moving fill inside the slider's own track and nothing else in the shell
    // shows a signal level at all. So the ticks are a design decision, and the
    // one thing they are answering to is components/LevelMeter.qml's promise
    // that this must not read as a second slider under the first one.
    //
    // A three-pixel tick on a five-pixel pitch is the coarsest spacing that
    // still moves smoothly at speech rates on a 120px meter -- about forty
    // ticks -- and it is visibly not a continuous bar at arm's length, which
    // is the whole point of it.
    readonly property int meterTick: 3
    readonly property int meterPitch: 5
    readonly property int meterHeight: 4

    // ---------------- The settings window ----------------
    //
    // Everything above came out of Microsoft's source. The five alphas and
    // sizes here came out of Microsoft's source AND out of the photographs in
    // the brief, which is a distinction worth keeping: where the two disagreed
    // the photograph won, and the line says so.

    // CardStrokeColorDefault, #19000000 -- BLACK at ten per cent, which is why
    // it is an alpha here and not a colour role. Measured in
    // ref/settings-system-about.jpg: the gap between two stacked cards reads
    // #1c1c1c over a #202020 pane, and 0.9 x 32 is 28.8. Theme.outlineVariant
    // is #2f2f2f under this scheme and would draw a LIGHTER line there, which
    // is the wrong direction for a card edge.
    readonly property real cardStrokeAlpha: 0.098

    // LayerFillColorDefault, #4C3A3A3A: the fill the settings window's content
    // pane carries over the window's own mica. It is what makes the right-hand
    // pane read lighter than the navigation pane in
    // ref/settings-personalization-taskbar.jpg -- +13 on every channel -- while
    // both are the same colour in a shot taken with transparency off.
    readonly property real layerAlpha: 0.3

    // OURS, and arithmetic rather than a measurement: the toolkit stacks
    // SettingsCards four apart, the Column the host puts the rows in is fixed
    // at spacing 2, so each card gives up one pixel at the top and one at the
    // bottom and the gap adds up to the four Windows draws.
    readonly property int cardGapInset: 1

    // The margin around a section heading in the toolkit's own sample page:
    // Margin="0,30,0,6".
    readonly property int sectionHeaderTop: 30
    readonly property int sectionHeaderBottom: 6

    // A PICTOGRAM IS A CHARACTER HERE, so an icon size is a text size. 20 is
    // FontIcon's own default and the box SettingsCard clamps a header icon to;
    // 16 is what NavigationView asks its icons for.
    readonly property real glyphSize: Theme.fontSize * 20 / 14
    readonly property real glyphSmallSize: Theme.fontSize * 16 / 14

    // The gap between a toggle's word and its track. OURS: in
    // ref/settings-touchpad-mica.png -- a 150% shot -- the last ink of "On"
    // sits 21 pixels left of the track, which is 14 at 100%. That is measured
    // from INK and a Text item's box ends a pixel or two past it, so the
    // number written here is the round one under the measurement.
    readonly property int switchLabelGap: 12

    // MenuFlyoutItem: 32 tall -- measured on the flyout in
    // ref/settings-flyout-menu.jpg, two items 48 apart at 150% -- with its
    // highlight inset four pixels from each side of the menu. The Explorer
    // context menu in ref/contextmenu-explorer-dark.png is NOT this control
    // and its rows are taller; the flyout inside the settings window is.
    readonly property int menuItemHeight: 32
    readonly property int menuItemInset: 4

    // NumberBoxMinWidth. A stepper is a NumberBox with its spin buttons
    // inline, and this is what stops the number's column collapsing onto the
    // two buttons.
    readonly property int numberBoxMinWidth: 120

    // The portrait at the top of the navigation pane. OURS: measured 60 across
    // in ref/settings-personalization-taskbar.jpg, which is a 1:1 shot -- the
    // nav pill in it is exactly 36 tall.
    readonly property int userAvatar: 60

    // ListViewItemMinHeight, out of the ListViewItem resources. It is the
    // floor a list row gets when it is drawn as a card of its own -- the shape
    // Windows gives every list of things in Settings, from installed apps to
    // paired devices.
    readonly property int listRowHeight: 40
}
