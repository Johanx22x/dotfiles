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
}
