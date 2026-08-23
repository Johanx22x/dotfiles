// A titled group of settings rows: a heading, then a card holding the rows.
// THIS IS THE HALF THE PAGES SEE; the heading, the action chip and the card
// are in themes/<theme>/components/SettingsSection.qml.
//
// THE NAME IS THE API. Forty-nine call sites across fifteen pages write
// `SettingsSection { ... }`, and three files -- MonitorCard, NightLightSection
// and ArrangementSection -- have one as their ROOT TYPE and add required
// properties of their own to it. Renaming this to `Section` because the facade
// is thinner than the component it replaced would be a rename of fifty-two
// files to save a word, which is the opposite of what the split is for.
//
// ---------------------------------------------------------------------------
// THE COLUMN OF ROWS DID NOT MOVE, AND IT COULD NOT HAVE
// ---------------------------------------------------------------------------
//
// `default property alias content: rows.data` is what puts the rows a page
// writes between these braces INTO THE CARD rather than beside the heading,
// and an alias binds a name on this type to a property of an object IN THIS
// DOCUMENT. A Loader cannot host one: the alias is resolved when this file is
// parsed and `drawing.item.rows` does not exist then. So the Column stays here
// and the theme is handed it -- the same arrangement, and for the same reason,
// as the TextInput in components/SearchField.qml, whose header has the longer
// account of it.
//
// AND IT IS THE RIGHT PLACE ANYWAY, for a reason that is specific to this
// component: rows arrive from Repeaters as well as from the file, and a
// Repeater creates its delegates as children of the item it is written in.
// That item is `rows`. A Column that lived in the theme would be a Column the
// Repeaters were not writing into.
//
// SO THE THEME POSITIONS AN OBJECT IT DOES NOT OWN: it puts `row.rows` in the
// `data` of a slot inside its card, and the anchors below re-evaluate against
// that slot because they are bound to `parent` and `parent` is what changed.
//
// WHAT A THEME CANNOT CHANGE, said out loud because it is the price. The
// spacing between rows is set below and a theme cannot pick another one --
// only where the column sits and what is drawn around it. It is the same trade
// SearchField makes with the input's font, and it is what keeping the alias
// costs. The margins around the column ARE the theme's: they are the slot's,
// not this Column's.
//
// The heading sits OUTSIDE the card rather than inside it. Inside, it would
// be the first row of a list of rows and would have to be styled hard enough
// not to be read as one; outside, the indent alone does the work and the card
// stays a list of like things. That is a promise about shape and it now lives
// in the theme file, which is the only place that can keep it.

import QtQuick
import qs.modules

Item {
    id: root

    // `glyph` and `title` STAY ON THIS SIDE, and not only because the pages
    // set them. modules/settings/SettingsSearch.qml builds its index by
    // walking the live object tree and duck-types a section as anything with
    // a non-empty string `title` and no `label`; the walk recurses into the
    // Loader below and into the theme's items, so a theme that re-declared
    // either name would index every section twice. See rule 3 in
    // themes/genesis/components/README.md.
    property string glyph: ""
    property string title: ""

    // Rows written between this component's braces land in the card, not next
    // to the heading. See the header for why the Column is on this side.
    default property alias content: rows.data

    // An optional action for the whole section, shown as a small chip at the
    // right end of the heading.
    //
    // IT IS THE HEADING'S AND NOT A ROW OF ITS OWN, which is the point. A
    // section-wide action put inside the card becomes a row that looks like a
    // setting and is not one, and two of those stacked above a grid is what
    // made the wallpaper page read as heavy: three horizontal bands of
    // furniture before any content. Up here it costs no vertical space at
    // all -- the heading line was already there with nothing on its right.
    property string actionText: ""
    property string actionGlyph: ""

    signal actionTriggered

    // THE FLOOR IS THE ROWS THEMSELVES, which is what a missing theme file
    // degrades to here rather than a fixed number. A theme that never slots
    // the column leaves it anchored to this item, laying its rows out at full
    // width with no card behind them: legible, and what a section with no
    // card would look like anyway. Read off the Loader and not off
    // `Loader.item`, for the reason in ToggleRow's header.
    implicitHeight: Math.max(rows.implicitHeight, drawing.implicitHeight)

    // ---------------- The rows, which the theme places ----------------
    //
    // Exposed so the theme can put the column somewhere and measure its card
    // against it. `readonly` because the theme's business with it is to hold
    // it and to read its `implicitHeight`, not to swap it, and a page has no
    // business with it at all -- the rows go in through the default property
    // above.
    readonly property Column rows: rows

    Column {
        id: rows

        // LEFT AND RIGHT TO THE PARENT, VERTICALLY CENTRED IN IT, and every
        // one of those reads `parent` on purpose: the theme reparents this
        // into its own slot and anchors bound to `parent` follow it there.
        //
        // The explicit width is not decoration -- the rows inside take theirs
        // from this column, see the note at the top of ToggleRow -- and the
        // inset that keeps a hovered row's pill off the card's rounded corner
        // is the SLOT's now, so that a theme with a different corner can give
        // it a different inset.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // The same descending order SettingsPage puts on the sections, and
        // for the same reason: a tooltip hangs downwards out of its row and
        // has to cover the rows below it, which it cannot do from inside one
        // of them. See the long note in SettingsPage.qml, and the longer one
        // in components/Tooltip.qml about what a flipped note needs on top of
        // this.
        //
        // IT RUNS OVER THE REAL ROWS AND IT HAS TO. `children` here is what
        // the pages wrote plus whatever the Repeaters made, in that order --
        // the theme's slot holds ONE child, this column, and restacking that
        // would order nothing. Which is the second reason this object is on
        // this side of the seam.
        //
        // It matters more here than in SettingsPage, because rows arrive from
        // Repeaters as well as from the file -- which is why this is hooked to
        // the signal and not only to completion.
        onChildrenChanged: rows.restack()
        Component.onCompleted: rows.restack()

        function restack(): void {
            for (let i = 0; i < children.length; i++)
                children[i].z = children.length - i;
        }
    }

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    //
    // THE THEME'S FILE IS UNDER components/ EVEN THOUGH THIS ONE IS NOT.
    // Everything a theme draws lives in one of the directories shell.qml
    // imports for the file watcher, and `themes/<theme>/components` is the one
    // that holds the shared widgets. A `settings/` directory beside it would
    // be invisible to the watcher until somebody added the import, which is
    // how this tree's own components directory spent its first hours.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/SettingsSection.qml")

        function build(): void {
            if (String(drawing.source) === drawing.drawingUrl)
                return;

            drawing.setSource(drawing.drawingUrl, {
                row: root
            });
        }

        Component.onCompleted: drawing.build()
        onDrawingUrlChanged: drawing.build()
    }
}
