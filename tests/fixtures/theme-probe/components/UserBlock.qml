// UserBlock, as the probe draws it: the username on a magenta strip with the
// portrait -- square, because nothing here is round -- on the left of it.
//
// `cache: false` ON THE Image IS NOT DECORATION AND THIS FIXTURE KEEPS IT. The
// facade reloads the portrait by setting `avatarSource` to nothing and back,
// because an Image caches by URL and the URL of ~/.face never changes. Without
// `cache: false` the second write is answered out of Qt's pixmap cache and the
// picture silently stops updating after the first change. It is a promise no
// facade could require -- the Image belongs to whoever draws it -- so it is
// rule 7, and it is written here for the same reason it is written in genesis.
//
// Rule 4: the whole block asks the facade and never acts. The window answers
// by clearing the search and selecting page zero, and this file does not know
// that.
//
// SessionInfo is reached with `import qs.modules.settings` and not through
// `row`: rule 5 says host state is imported the way every other theme file
// imports it.

import QtQuick
import qs
import qs.modules.settings

Rectangle {
    id: root

    required property UserBlock row

    implicitHeight: 32
    color: root.row.selected ? "#00ff00" : "#ff00ff"

    Image {
        id: picture

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: root.height
        source: root.row.avatarSource
        // NOT OPTIONAL. See the top of this file.
        cache: false
        fillMode: Image.PreserveAspectCrop
    }

    Text {
        anchors.left: picture.right
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        // The initial is what a machine with no ~/.face shows, and this fixture
        // is always one: the sandbox HOME has no picture in it.
        text: picture.status === Image.Ready
            ? SessionInfo.displayName
            : SessionInfo.user.charAt(0).toUpperCase()
        color: "#ffff00"
        font.family: Theme.fontFamily
        elide: Text.ElideRight
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.row.clicked()
    }
}
