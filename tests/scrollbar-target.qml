// The three shapes components/ScrollBar.qml is placed in, and nothing else.
//
// THE BAR IS THE REAL ONE, imported straight out of quickshell/ by relative
// path, so an edit to its margins moves the numbers scrollbar-target.py
// asserts. So is ScrollList, for the one shape that is a ScrollList.
// Everything else is a stand-in on purpose: the question is which item
// receives a press at a given x, and a MouseArea that records its own name
// answers that exactly where a real row would answer it by opening a page
// this bench would then have to go looking for.
//
// WHICH SHAPE IS THE WHOLE QUESTION, because the three do not stack the same
// way and the stacking decides who hears the press:
//
//   beside   The bar is a SIBLING of the list, placed in padding outside it.
//            The settings rail, the page pane, the search results, the
//            notification history and the cheatsheet are all this. It is
//            declared after the list, so it is above it.
//
//   view     The bar is declared INSIDE a ListView or a GridView. Those
//            override the default property back to `data`, so the bar is a
//            child of the view item and a later sibling of the contentItem
//            holding the delegates -- again above the rows. The launcher grid
//            and the clipboard list are this.
//
//   list     The bar is ScrollList's own, declared in the base document,
//            while the call site's Column is appended to the same
//            `flickableData` afterwards. The rows are therefore ABOVE the
//            bar, which is the opposite of the other two and is measured here
//            because nothing in the tree says so.
//
// The window edge is modelled by `sceneWidth`: a press outside the surface is
// never delivered, and two of the settings bars reach past it.
import QtQuick
import "../quickshell/.config/quickshell/components"

Item {
    id: scene

    width: Case.sceneWidth
    height: 400

    // Who heard the last press. The bar cannot set this -- it is the shipping
    // file and has no hook to hang one on -- so a press it takes is read off
    // the scroll it performs instead, which is why every shape drives a
    // Flickable that has somewhere to go.
    property string lastHit: ""
    property Flickable driven: null

    function reset(): void {
        scene.lastHit = "";
        if (scene.driven)
            scene.driven.contentY = 0;
    }

    // Read back rather than reached into: `driven` crosses to Python as an
    // opaque pointer, and the one number wanted off it is this.
    function drivenY(): real {
        return scene.driven ? scene.driven.contentY : 0;
    }

    function tookIt(): string {
        if (scene.lastHit !== "")
            return scene.lastHit;
        if (scene.driven && scene.driven.contentY !== 0)
            return "bar";
        return "nobody";
    }

    // NOT `anchors.fill`, and that is not tidiness: a Loader with a size of
    // its own resizes what it loads to match, so a list declared 780 wide
    // came out 820 and every number below moved with it.
    Loader {
        sourceComponent: Case.shape === "beside" ? besideShape
            : Case.shape === "view" ? viewShape : listShape
    }

    // ---------------- beside ----------------
    Component {
        id: besideShape

        Item {
            anchors.fill: parent

            Flickable {
                id: besideList

                x: Case.listLeft
                y: 0
                width: Case.listRight - Case.listLeft
                height: 300
                contentHeight: 3000
                interactive: false
                clip: true

                MouseArea {
                    width: besideList.width
                    height: 3000
                    onPressed: scene.lastHit = "content"
                }
            }

            // TWO BARS AND ONLY ONE OF THEM ANSWERS, which is how the
            // DEFAULTS get asserted rather than whatever the bench felt like
            // passing. Every call-site case below leaves the margins alone,
            // so an edit to either default moves those rows; the one case
            // that sets them exists to say the properties are still wired to
            // something, and would otherwise be the only thing measured.
            //
            // `wanted: false` is the component's own off switch and it takes
            // the MouseArea with it -- `enabled: root.visible` -- so the
            // silent one is inert rather than merely invisible.
            ScrollBar {
                view: besideList
                wanted: !Case.tuned

                x: Case.barX
                y: 0
                height: 300
            }

            ScrollBar {
                view: besideList
                wanted: Case.tuned

                x: Case.barX
                y: 0
                height: 300

                grabMarginInward: Case.inward
                grabMarginOutward: Case.outward
            }

            Component.onCompleted: scene.driven = besideList
        }
    }

    // ---------------- view ----------------
    Component {
        id: viewShape

        Item {
            ListView {
            id: realView

            x: Case.listLeft
            y: 0
            width: Case.listRight - Case.listLeft
            height: 300

            // The one thing in here that is ever false. Qt bounds a press
            // target at a CLIPPING ancestor and nowhere else -- an unclipped
            // parent does not stop a child's MouseArea reaching past it --
            // and the outward margin's whole justification is that a clip is
            // what usually eats it. So the bench turns this off once.
            clip: Case.viewClips

            // Interactive when the case says so. The press-target sweeps set
            // it false -- a press is not a drag and an inert view keeps the
            // bands clean -- but the drag-steal row needs the view ARMED,
            // because a Flickable that cannot flick cannot steal and the row
            // would pass over nothing. The launcher's real list is
            // interactive whenever it overflows, which is whenever the bar
            // exists at all.
            interactive: Case.viewInteractive ?? false
            model: 40

            delegate: MouseArea {
                width: ListView.view.width
                height: 40
                onPressed: scene.lastHit = "content"
            }

            ScrollBar {
                view: realView
                wanted: !Case.tuned

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
            }

            ScrollBar {
                view: realView
                wanted: Case.tuned

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                grabMarginInward: Case.inward
                grabMarginOutward: Case.outward
            }

            Component.onCompleted: scene.driven = realView
            }
        }
    }

    // ---------------- list ----------------
    Component {
        id: listShape

        Item {
            ScrollList {
            id: realList

            x: Case.listLeft
            y: 0
            width: Case.listRight - Case.listLeft
            height: 300
            contentHeight: rows.implicitHeight

            Column {
                id: rows

                width: realList.width

                Repeater {
                    model: 40

                    Rectangle {
                        width: rows.width
                        height: 40

                        // Opaque only where a case asks for it. Every real
                        // row in the tree is "transparent" at rest and paints
                        // on hover or selection, so this is the hovered row
                        // and the question is what it does to the bar under
                        // the pointer.
                        color: Case.rowColour

                        Loader {
                            anchors.fill: parent
                            sourceComponent: Case.rowsClickable ? clickableRow : inertRow
                        }
                    }
                }
            }

            Component.onCompleted: scene.driven = realList
            }
        }
    }

    Component {
        id: clickableRow

        MouseArea {
            // `Case.rowZ` is the control for the bar's own `z: 1`. Stacking
            // in Qt Quick is per parent: a z inside a row orders that row's
            // own children and cannot lift anything over a sibling of the
            // row's ancestor. So a row carrying z=99 must still lose to a bar
            // at z=1, and if it ever does not, one is enough is wrong.
            z: Case.rowZ

            onPressed: scene.lastHit = "content"
        }
    }

    Component {
        id: inertRow

        Item {}
    }
}
