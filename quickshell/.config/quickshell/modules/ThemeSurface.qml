// ONE SURFACE OF THE CURRENT THEME, LOADED OUT OF THE THEME'S DIRECTORY.
//
// This is the seam made mechanical: shell.qml still decides that there is a
// bar and which screens it goes on, and this loads whatever the current theme
// draws a bar with. `file` is a path inside the theme directory --
// "bar/Bar.qml", "ScreenCorners.qml" -- and modules/Themes.qml turns it into
// a URL. Nothing here, and nothing in shell.qml, names a theme.
//
// A QtQuick Loader AND NOT Quickshell's LazyLoader, which was chosen by
// measurement and is worth writing down because LazyLoader is the one that
// looks purpose-built. Three primitives can hold a PanelWindow in 0.3.1 and
// all three map a real layer surface; they differ in the two things this
// needs, which are handing the surface its screen BEFORE it is created and
// letting the theme change while the shell is up:
//
//   LazyLoader     swaps only if `active` is toggled off and on around the
//                  change, and has no way to pass an initial property. The
//                  screen has to be assigned after the fact, and a PanelWindow
//                  created with no screen is created on the DEFAULT one: every
//                  surface would be mapped on the wrong monitor and moved,
//                  once per screen, at every startup. Measured, not feared --
//                  two bars both came up on HEADLESS-2 and one then moved.
//
//   BoundComponent binds its own properties into the created object, so the
//                  screen does arrive first and the window is right from its
//                  first frame. But its source is fixed at creation:
//                  "BoundComponent.url cannot be set after creation" is what
//                  the log says when the theme changes, and the old theme
//                  stays on screen.
//
//   Loader         setSource(url, properties) is both halves at once --
//                  initial properties, so the screen is there before the
//                  window exists, and a fresh source whenever it is called
//                  again. It is the one that does what this needs.
//
// WHY THE GUARD IN build(), which is not defensive programming. setSource is a
// CALL and not a binding, so this has to notice the URL changing for itself --
// and the first read of `surfaceUrl` emits its own change signal, so the
// obvious pair of Component.onCompleted plus onSurfaceUrlChanged builds twice
// and tears the first one down. Comparing against what is already loaded makes
// the pair idempotent: one window per screen at startup, measured.
//
// AND WHAT A Loader GIVES UP, said here rather than left to be noticed. Only
// LazyLoader is Reloadable, and a Reloadable is what Quickshell matches
// against the previous revision so a window can be REUSED instead of rebuilt
// across a hot reload. A surface held by a Loader is not matched, so editing
// something under modules/ or components/ now rebuilds the theme's windows
// where it used to hand them back. It is a reload the shell already survives
// -- the alternative was every surface coming up on the wrong monitor at every
// login -- but it is the one thing here that is worth a look with your own
// eyes rather than a headless run.
//
// The theme's files are watched -- editing one reloads the shell -- but not
// because of anything here. Loading by URL never registers a watch; the import
// list in shell.qml is what does, and modules/Themes.qml has the account of
// why the two are separate. A theme shell.qml does not import loads through
// this file exactly the same way and is not watched.

import QtQuick
import qs.modules

Loader {
    id: root

    // The ShellScreen this surface belongs to, from the Variants in shell.qml.
    // Handed to the theme's file as an initial property, which is what lets a
    // theme keep `required property var modelData` on it.
    required property var modelData

    // Where the file lives inside the theme directory.
    required property string file

    readonly property string surfaceUrl: Themes.surface(root.file)

    function build(): void {
        if (String(root.source) === root.surfaceUrl)
            return;

        root.setSource(root.surfaceUrl, {
            modelData: root.modelData
        });
    }

    Component.onCompleted: root.build()
    onSurfaceUrlChanged: root.build()
}
