// The base of every page in the settings window: a column of sections, and
// the two things the window needs to know about a page.
//
// WHY A BASE COMPONENT AND NOT JUST A Column. The window has to build the
// navigation rail and the search index without knowing what pages exist --
// otherwise adding one means editing three places and forgetting the third.
// A page declares its own name and glyph here, the rail is a Repeater over
// the page list, and search walks the same objects. One file per page, and
// the file says everything about itself.

import QtQuick
import "root:/"

Column {
    id: root

    // Shown in the rail, and the first thing search matches on.
    property string title: ""
    property string glyph: ""

    // Extra words that should find this page even though they appear nowhere
    // on it. "brightness" finding the display page, "hotkey" finding the
    // keybinds one. Kept short: this is for the word someone would actually
    // type, not for a thesaurus.
    property var keywords: []

    // Where this page sits in the rail. Assigned by the window once, on the
    // way past -- a page does not know its own position in a list it is not
    // holding, and hardcoding it in each file is how the rail and the pages
    // end up disagreeing.
    property int index: -1

    // IS THIS PAGE WORTH OFFERING AT ALL on this machine?
    //
    // Four pages drive things through the compositor -- monitors, input,
    // keybinds -- and there is no honest way to show them where the compositor
    // cannot do it: every control would be dead, and a settings window full of
    // switches that do nothing is worse than one that is shorter.
    //
    // So a page can opt out, and it does so by asking what the compositor CAN
    // DO rather than which one it is -- `available: Compositor.can("...")`. A
    // page that says nothing is available, which is the right default: most of
    // this window is audio, network, wallpaper and appearance, and none of that
    // cares what is drawing the screen.
    //
    // An unavailable page is not built differently and not hidden with a
    // property: it is left out of the window's page list entirely, so it takes
    // no rail entry, no index, and no place in search.
    property bool available: true

    // ON SCREEN OR NOT, and this is the only honest answer to that question
    // in this window. Every page is built and kept alive so that none of them
    // forgets where you were, which means `visible` cannot be left to default
    // to true -- pages that turn hardware on when they are looked at (the
    // Wi-Fi scanner, Bluetooth discovery) read exactly this property, and if
    // it lied they would scan forever in the background.
    visible: SettingsState.currentPage === root.index

    // A plain fallback rather than an implicitWidth: a Column computes its
    // own implicit size from its children and refuses to have one assigned
    // ("implicitWidth is a read-only property"), which is what stopped the
    // whole shell loading the first time this file existed.
    width: parent ? parent.width : 400

    // No `default property` here: Column already has one (`data`), so
    // sections written between this component's braces land in it. Declaring
    // another would shadow the positioner's own and the sections would stop
    // being laid out.
    spacing: Theme.groupSpacing

    // EARLIER SECTIONS PAINT OVER LATER ONES, which is the opposite of what a
    // Column does on its own and is the whole fix for tooltips.
    //
    // A tooltip hangs DOWNWARDS out of the row it explains, so it overlaps
    // whatever comes after it -- and `z` only orders an item among its own
    // SIBLINGS. The note carries z: 100, which wins inside its row and buys
    // nothing outside it: the row is buried three levels down, and the next
    // section is a sibling of the CARD, not of the note. So a tooltip on the
    // last row of a card was drawn under the next section's heading and under
    // the next card, which is what this is here to stop.
    //
    // Descending z rather than raising one item, because the rule generalises:
    // anything that hangs out of a section belongs over what follows it, and
    // nothing in this window overlaps upwards. Positive and not negative -- a
    // child with z below zero paints behind its own parent's background, so
    // 0, -1, -2 would have posted the sections behind the cards.
    //
    // Re-run when the children change, since a page can add a section after it
    // has loaded.
    onChildrenChanged: root.restack()
    Component.onCompleted: root.restack()

    function restack(): void {
        for (let i = 0; i < children.length; i++)
            children[i].z = children.length - i;
    }
}
