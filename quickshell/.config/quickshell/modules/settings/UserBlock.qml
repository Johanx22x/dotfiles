// Who this desktop belongs to, at the top of the sidebar. THIS IS THE HALF THE
// WINDOW SEES; the pill, the round portrait and the two lines of text are in
// themes/<theme>/components/UserBlock.qml.
//
// The macOS arrangement, and it earns its place for the same reason there: a
// settings window is where you go to change things about YOUR session, and
// the name at the top is what says whose session it is. It is also the only
// entry in the rail that is a person rather than a subject, which is why it
// sits above the list with a gap rather than inside it.
//
// THE PICTURE IS OPTIONAL, and the fallback is the initial over the accent --
// what every application that has ever had this problem settles on. It is
// what a fresh machine shows: there is no AccountsService user record here and
// the GECOS field in /etc/passwd is empty, so there is no full name either and
// the username stands in for both. Which of the two is drawn is the theme's
// business; that there is a fallback at all is a promise, and the theme file
// keeps it.
//
// The picture itself is ~/.face, set from the User page of this window through
// the `desktop-avatar` script. It is deliberately NOT a path of this shell's
// own: ~/.face is the freedesktop convention, so a display manager finds the
// same picture.
//
// ---------------------------------------------------------------------------
// THE CACHE-BUST DID NOT MOVE, AND IT IS WHY THIS FACADE HAS A PROPERTY THE
// THEME MUST BIND TO RATHER THAN A PATH IT COULD HAVE READ ITSELF
// ---------------------------------------------------------------------------
//
// An Image caches by URL. The URL of the profile picture never changes -- only
// its contents do -- so a theme that bound `source: "file://" + <path>` would
// draw the first portrait this session ever saw and never another one, in a
// window that otherwise works.
//
// A query string would be the shorter trick and it is not available: appending
// ?v=2 to a file:// URL asks the filesystem for a file whose name ends in
// "?v=2".
//
// What is left is setting the source to nothing and back, which is a sequence
// of two writes and therefore something that has to be DONE rather than bound.
// It is done here, once, into `avatarSource`, and every theme binds its Image
// to that one property. `cache: false` on that Image is a HARD REQUIREMENT and
// not a suggestion: without it the second assignment is answered out of Qt's
// pixmap cache and the portrait silently stops updating after the first change.
// There is no way for this side to require it -- it is a property of an object
// the theme owns -- so it is written here, in the theme file, and in
// themes/genesis/components/README.md's rule 7 sense it is a promise about
// behaviour.

// NO `import qs` HERE, unlike every other facade in this window. There is no
// design token left on this side: the block's height is 56 because that is
// what it was, and everything that reads a colour or a font moved into the
// theme file. tests/qml-lint.sh gates on unused-imports, so the import that
// would have been kept out of habit is the one it names.
import QtQuick
import qs.modules

Item {
    id: root

    property bool selected: false

    signal clicked

    readonly property string avatarPath: SessionInfo.avatarPath

    // RELOADED BY HAND, because an Image will not do it on its own. See the
    // header for the whole of it.
    readonly property int revision: SessionInfo.avatarRevision

    // WHAT THE THEME'S Image BINDS TO. Not a binding on this side: it is
    // assigned twice in a row, and a binding cannot be two values in one turn.
    property string avatarSource: ""

    function reload(): void {
        root.avatarSource = "";
        root.avatarSource = `file://${root.avatarPath}`;
    }

    // Three ways in, and all three are the same two writes. `revision` is the
    // one that matters -- it is what the User page bumps after writing a new
    // ~/.face -- and the other two are what fills the property in the first
    // place and what covers a HOME that arrives after this item was built.
    Component.onCompleted: root.reload()
    onAvatarPathChanged: root.reload()
    onRevisionChanged: root.reload()

    width: parent ? parent.width : implicitWidth
    implicitWidth: 200
    implicitHeight: Math.max(56, drawing.implicitHeight)

    // Identical to ToggleRow's loader, and deliberately not factored out: see
    // themes/genesis/components/README.md on why the sixteen lines are copied
    // into each facade rather than shared through a base type.
    Loader {
        id: drawing

        anchors.fill: parent

        readonly property string drawingUrl: Themes.surface("components/UserBlock.qml")

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
