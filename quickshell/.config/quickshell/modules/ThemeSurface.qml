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
//
// ---------------------------------------------------------------------------
// WHAT A SWAP LOOKS LIKE, WHICH IS A DIFFERENT QUESTION FROM WHETHER IT WORKS.
//
// Everything above is about the swap being CORRECT. This is about it being
// watchable, and it is written down because the answer turned out to be an
// argument for not building anything. Measured by capturing frames out of the
// headless compositor tests/shell-load.sh already builds -- labwc, pixman, the
// probe fixture dropped in as a second theme with its barHeight pushed to 120
// against genesis's 48 so that a swap is unmistakable -- sampled about every
// 17 ms across 40 swaps in two sessions. ONE swap cannot answer any of this: a
// state that lasts a single refresh is missed two times in three at that
// sampling gap, and the first three swaps measured here happened to be the
// clean ones and said the whole thing was already perfect.
//
// THE SEVEN SURFACES CUT TOGETHER, and that was the thing worth checking.
// Seven independent Loaders is seven chances to stagger, and they do not take
// them: the seven setSource calls of a swap run back to back with nothing
// logged between them, 7 to 12 ms end to end -- one pass of one property
// change, well inside a frame. On screen they move together too. The bar, the
// rounded corners and a sheet that was open all leave in the same captured
// frame and all arrive in the same captured frame; no frame has one of them
// under the old theme beside another under the new.
//
// WHAT THE SCREEN SHOWS IS 100 TO 150 ms LONG AND IS NOT THAT. The QML objects
// exist immediately; their pixels do not. A layer surface has to be created,
// configured, acked and painted before the compositor has anything to draw,
// and until then the old one is gone. Thirty-one of the forty swaps showed the
// whole shell -- bar and rounded corners together -- absent for about an
// eighth of a second. It is not this file's to shorten: an interval in the
// same range appears between two themes with IDENTICAL barHeights, which rules
// out the reflow when the new theme's tokens land, and it did not shrink over
// twenty-four swaps of the same two themes, which rules out compiling them.
//
// AND THE OTHER NINE ARE THE ARGUMENT AGAINST A CROSSFADE. Three had no gap
// and nothing odd in them at all; the other six had no gap either, because the
// outgoing surfaces outlived the incoming ones being mapped -- and the one
// frame where both are up is the ugliest thing in the whole measurement, so
// the swaps with no gap in them are also the only ones with a fault to see.
// The new bar maps while the old bar's exclusive zone still
// stands, so it is placed UNDER it: two bars stacked down the top of the
// screen, or, when the old one goes first, the new bar floating with a band of
// bare desktop above it. That is not a near miss, it is what two layer
// surfaces of two different themes on one screen looks like, photographed --
// and a crossfade is a machine for producing it deliberately, for 250 ms
// instead of for one frame. Theme.qml's note beside recolorDuration reaches
// the same conclusion from the other direction, about colour rather than
// structure, and it was already measured there.
//
// SO NOTHING HERE ANIMATES AND NOTHING HERE OVERLAPS. The cut is the design.
// What was actually wrong was never the timing, and it is the paragraph below.
//
// WHAT AN OPEN SURFACE COSTS, AND WHY build() CLOSES THEM. The four sheets and
// the bar's popout are drawn by the theme and driven by host state that a swap
// does not touch, so a sheet open across one is destroyed and rebuilt STILL
// OPEN -- the power menu was captured going down under genesis and coming back
// up in the probe, open, in the same place. That reads like the swap being
// transparent and it is not: everything those surfaces do in the act of
// OPENING is skipped, because they never open again. The carousel reveals the
// applied wallpaper from its onVisibleChanged and so returns scrolled to the
// first thumbnail instead; the launcher clears its field there and so returns
// looking empty while still holding what was typed; the cheatsheet fetches the
// binds there and so returns showing whatever was last fetched. Each comes
// back subtly WRONG rather than plainly gone, which is the worse of the two.
// modules/Surfaces.qml is the one place that knows what may be on screen, so
// closeAll() below puts all of it away first -- and that call has to happen
// here, in the swap itself, rather than in a Connections over there. The note
// on closeAll() is where the ordering was measured and why it cannot.

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

        // A SWAP AND NOT THE FIRST BUILD, which is the whole meaning of the
        // test: nothing is loaded only at startup, and everything below is
        // about what is already on screen. See WHAT AN OPEN SURFACE COSTS in
        // the header.
        if (String(root.source) !== "")
            Surfaces.closeAll();

        root.setSource(root.surfaceUrl, {
            modelData: root.modelData
        });
    }

    Component.onCompleted: root.build()
    onSurfaceUrlChanged: root.build()
}
