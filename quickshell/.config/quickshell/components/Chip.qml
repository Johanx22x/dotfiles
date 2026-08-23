// A word in a pill. THIS IS THE HALF THE PAGES SEE; the pixels are in
// themes/<theme>/components/Chip.qml.
//
// THREE CHIPS AND NOT ONE, which is why `role` is the first property below.
// This absorbed three shapes that were drawn three times in three files and
// were the same pill with three jobs:
//
//   Button  the display page's own Chip -- thirteen call sites, the segmented
//           rotation control and every action on that page. Pressable, filled
//           or outlined, and the only one of the three with a glyph.
//   Badge   the updates page's StateChip. A tinted state word, and NOT a
//           button: no MouseArea, no signal, no pointer cursor. That is not
//           `filled: false` -- an outlined chip still lights up and still shows
//           a hand -- which is exactly why it needs a role of its own.
//   Key     one key cap out of a chord, on the keybinds page and in the
//           cheatsheet. Two-tone by whether it is the key or a modifier.
//
// An unknown role draws as a Button. The vocabulary is closed and it is three
// words long; a fourth belongs in this comment before it belongs in the theme.
//
// IT LIVED UNDER pages/display/ AND ITS HEADER SAID IT SHOULD, which is worth
// recording because the argument was good and the facts under it moved. It
// said: this is the display page's button, shaped by what that page needed,
// and every other page uses ActionRow, ConfirmButton or a bare MouseArea
// instead -- so moving it up a level would be claiming it is the shell's
// button, a bigger claim than one file can support. Three files were drawing
// the same pill by then. Sixteen call sites across four pages and the
// cheatsheet is the support that was missing.
//
// ---------------------------------------------------------------------------
// THE ONE PLACE THE HOST DRIVES THE LAYOUT, AND WHY IT HAS TO
// ---------------------------------------------------------------------------
//
// `padding` and `labelFont` below are the exception to the rule the rest of
// this directory keeps: the theme owns shape, layout and metrics, and nothing
// about how a thing is drawn crosses the seam downwards.
//
// modules/settings/pages/KeybindsPage.qml computes the width of its key gutter
// by ADDING CHIPS UP -- `chipSpacing * (n - 1)` plus, per key,
// `FontMetrics.advanceWidth(key) + chipPadding`. Its own header says why that
// is the right shape and what it costs: a model that does not add up the same
// numbers the chip is drawn with drifts, and it drifts SILENTLY. The chords
// simply start hanging off the edge again, which is the bug the model was
// written to fix. The cheatsheet's BindRow does the same arithmetic over the
// same pill.
//
// Before the split those numbers were literals in two files and kept in step by
// hand. After it, a theme that drew this pill with its own padding or its own
// type size would put the chords back over the edge with nothing failing to
// load, nothing failing a test and nothing in a log. So for the Key role the
// host hands the chip the two numbers its model used, and the theme uses them:
//
//   padding     the total width added to the label -- NOT per side. It is
//               the number the gutter model adds, so it has to mean exactly
//               what the model means by it.
//   labelFont   the font the host measured with. Handing the FontMetrics' own
//               font over, rather than two files independently spelling out
//               Theme.fontSize - 1.5, is what makes the measured chip and the
//               drawn chip provably the same chip.
//
// The chord's SPACING stays with the host too: the chips sit in the host's Row
// and that Row's `spacing` is the third number in the same sum.
//
// Leave both at their defaults -- `padding: -1` and an unset font -- and the
// theme uses its own, which is what the Button and Badge roles do.
//
// ---------------------------------------------------------------------------
//
// `label` OR `name`: exactly the split components/ListRow.qml carries, for
// exactly the same reason. SettingsSearch indexes anything with a non-empty
// `label`, so the thirteen display-page chips -- "Apply", "Keep", "90°" -- are
// in the search index today and stay there under `label`. A state word and a
// key cap are not settings and were never in it; those go under `name`. One
// shared `label` would have put roughly two hundred key caps into the index.
//
// THE ROOT IS AN Item AND THE DISPLAY PAGE'S Chip WAS A Rectangle. Same test as
// ToggleRow, same answer: over all thirteen sites nothing sets `color`,
// `radius` or `border`. What they set is `label`, `glyph`, `filled`, and the
// ordinary Item properties `enabled`, `visible` and `anchors`.

import QtQuick
import qs
import qs.modules

Item {
    id: root

    // "button", "badge" or "key". See the header.
    property string role: "button"

    // See the note above on which of these two to set.
    property string label: ""
    property string name: ""

    readonly property string chipText: root.label !== "" ? root.label : root.name

    // Button only. The other two roles are a bare word by design: a state word
    // with a picture beside it would be a fourth vocabulary for the installer's
    // four answers, and a key cap with a glyph is not a key cap.
    property string glyph: ""

    // THE EMPHASISED ONE, in whichever sense the role has: the selected segment
    // and the action carrying the page's intent for a Button, and the key at
    // the end of the chord -- as against the modifiers before it -- for a Key.
    property bool filled: false

    // Button only, and NOTHING SETS EITHER OF THEM. All thirteen call sites
    // take the defaults. They are kept because the fill and its ink are a pair
    // and the pair is the whole reason the palette can follow the wallpaper --
    // M3 guarantees contrast per pair, so a page that fills a chip with
    // Theme.warning has to name the ink that goes with it in the same breath.
    // Kept, and not designed for: the theme reads them and no shape here bends
    // to accommodate a caller that does not exist.
    property color accent: Theme.primary
    property color accentText: Theme.textOnPrimary

    // Badge only: the colour the state word is tinted with. The switch that
    // turns a state into a tone is the installer's vocabulary and stays on the
    // page -- see the same note on components/ListRow.qml's `badgeTone`.
    property color tone: Theme.textOnSurfaceVariant

    // See the long note in the header. -1 means "the theme's own".
    property int padding: -1

    // See the long note in the header. Null means "the theme's own".
    //
    // `var` AND NOT `font`, WHICH WAS MEASURED THE HARD WAY. Declared as a
    // `font`, this property has no unset state to test: QML default-constructs
    // it from the application font, so its family comes back non-empty and a
    // Button that never named a face was drawn in the application's font
    // instead of the theme's. It showed up as a chip 19 pixels wider than the
    // one it replaced. A null default has an unset state that is actually
    // unset.
    property var labelFont: null

    signal activated

    // NEVER PRESSED FOR THE BADGE OR THE KEY, and that is a promise this file
    // cannot require: the two are readings, not controls, and it is written
    // down in themes/genesis/components/Chip.qml next to the half that keeps
    // it. Same arrangement as InfoRow, and see rule 7 of that directory's
    // README.

    // THE WIDTH COMES BACK ACROSS THE SEAM, WHICH IS THE ONE RULE IN
    // themes/genesis/components/README.md THIS COMPONENT BREAKS, so it is worth
    // being exact about why.
    //
    // Rule 2 is "report implicitHeight, and never implicitWidth", and its
    // reason is a loop: a settings row fills its parent Column, a Column sizes
    // itself to its widest child, so a row that reported a width would be
    // sizing itself to the thing that is sizing itself to it. A chip is not in
    // that shape. It fills nothing -- it is content-sized inside a Row that
    // packs it -- and the theme's width comes from its own text and padding and
    // never from this item's width. There is no loop, and there is no other
    // answer available: how wide a word in a pill is, is a text metric, and a
    // text metric belongs to whoever chose the font.
    //
    // Read off the Loader and not `Loader.item` for the reason ToggleRow gives:
    // `Loader.item` is declared QObject and every read through it costs a
    // [missing-property] that tests/qml-lint.sh gates on.
    implicitWidth: drawing.implicitWidth

    // The shortest of the three roles, so it never clips the other two -- the
    // theme reports 28, 20 or 22 and this only catches a theme that reported
    // nothing at all. See ToggleRow for the two ways that happens.
    implicitHeight: Math.max(20, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/Chip.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()

        // See ToggleRow for why there is no status handler here either.
    }
}
