// How the windows theme draws a small closed choice: a SettingsCard with a
// segmented control in its content slot. The public half -- what the pages
// write, what an option is, and what `chosen` means -- is
// components/ChoiceRow.qml.
//
// SEGMENTS AND NOT A DROPDOWN, which is this theme's answer and is the same
// answer genesis gave for the same reason: a dropdown hides every option but
// the chosen one behind a click, which is the right trade when there are twenty
// of them and the wrong one when there are three. It also needs a popup
// surface, a focus grab and a way out of it, none of which this shell has --
// the tray menus are the only popup in it and they come off D-Bus. Windows'
// own answer at this count is the Segmented control, not the ComboBox.
//
// ONE STOREY AND NOT TWO, which is where this parts company with genesis.
// Genesis stacks the segments under the label because side by side they were
// squeezed into whatever was left after "Interface font"; a SettingsCard puts
// its content on the right and sizes the header column to what is left, so the
// segments get exactly the width they need and the label elides instead. The
// facade anticipated this in as many words -- "a theme drawing this control
// some other way has a different second storey or none" -- which is why the
// height crosses the seam at all.
//
// WINDOWS' OWN WRAP IS NOT IMPLEMENTED AND THAT IS WORTH KNOWING. SettingsCard
// has a RightWrapped visual state that moves the content presenter onto a
// second grid row below the header, triggered at SettingsCardWrapThreshold =
// 476 (286 with no icon). The settings pane here is 820 less a 320 rail, so it
// sits near that threshold rather than comfortably above it. Implementing it
// means a state machine over the card's own width and a second row height, and
// it is not drawn until something is actually clipping.
//
// SELECTION IS AN ACCENT BAR AND NOT A FILL, which is the rule NavigationView
// states outright: its selected pill has EXACTLY the same fill as its hover
// state, and the 3x16 indicator at radius 2 is what carries selection. A
// recreation that gives selection its own backplate colour has invented a state
// Windows does not have. Microsoft publishes no theme resources for the
// segmented control itself, so the bar below is that rule applied to this
// control rather than a number read out of a file -- it is the same indicator,
// turned on its side and put under the segment instead of beside it.
//
// IT READS `row` AND NEVER WRITES TO IT. `row.value` is what the page handed
// down; a click on a segment calls `row.chosen(...)` to ask for a different
// one. And the unpacking of an option is the facade's: `row.valueOf()` and
// `row.labelOf()` are called, never reimplemented here, because they are the
// API's contract about what a caller may put in `options` and getting them
// backwards would mean drawing the right control around the wrong answer.

import QtQuick
import qs
import qs.components
import ".."

Rectangle {
    id: root

    // The facade, handed in by its Loader as an initial property. See the note
    // in this directory's ToggleRow.qml on why it is `required`, why it is
    // typed rather than `var`, and why `ChoiceRow` here is the facade and not
    // this file.
    required property ChoiceRow row

    // ---------------- The hoist ----------------
    //
    // EVERYTHING RULE 1 BUYS STOPS AT THE EDGE OF A DELEGATE. Inside the
    // Repeater below, `row.anything` is exactly as unchecked as
    // `property var row` would have made the whole file -- measured both ways
    // in themes/genesis/components/README.md, where the same misspelling landed
    // as a named [missing-property] at the top level and as nothing at all one
    // scope down. ChoiceRow is where that bites hardest, because unpacking an
    // option is two function calls across the seam per item.
    //
    // So the seam is crossed HERE, at the top level, where it is checked, and
    // the delegate binds to plain JavaScript. `valueOf` and `labelOf` are the
    // facade's own and are called rather than reimplemented; what comes out is
    // a list of {text, value} that knows nothing about ChoiceRow.
    //
    // AND `value` IS DELIBERATELY NOT IN THAT LIST. Folding the current
    // selection into the model would rebuild every delegate on every click --
    // the segment under the pointer would be destroyed and replaced mid-hover.
    // It is hoisted separately so that choosing changes one binding and builds
    // nothing.
    readonly property var segments: {
        const options = root.row.options;
        const out = [];
        for (let i = 0; i < options.length; i++) {
            const option = options[i];
            out.push({
                text: root.row.labelOf(option),
                value: root.row.valueOf(option)
            });
        }
        return out;
    }

    readonly property var currentValue: root.row.value

    // THE CALL ACROSS THE SEAM IS A FUNCTION AND NOT A LINE IN THE DELEGATE,
    // for the same reason as the hoist above: a function body is the file's own
    // scope, so `root.row.chosen(...)` here is a checked read of a typed facade,
    // while the same line written inside the delegate would be checked by
    // nothing.
    function choose(value: var): void {
        root.row.chosen(value);
    }

    // WHAT IS LEFT AFTER THE HOIST, MEASURED. qmllint over the seven rows this
    // theme redrew reports exactly two [unqualified] findings and both are in
    // the Repeater below: `root.currentValue` and `root.choose(...)`. Neither
    // touches `row`, so nothing that crosses the seam is unchecked -- what
    // remains is a delegate naming an id from the component outside it, which
    // is the one shape `pragma ComponentBehavior: Bound` would fix and which
    // tests/qml-lint.sh's own header rules out for this tree. The same seven
    // rows drawn by genesis report nine.

    // SettingsCardContentMinWidth is 120 in SettingsCard.xaml and is NOT
    // applied here. Microsoft applies it to Sliders, ComboBoxes and TextBoxes
    // -- controls whose width says nothing -- and a segmented control's width
    // is its options. Padding three short words out to 120 would leave a gap
    // inside the track that means nothing.

    // WHAT THE FACADE READS BACK. 68 is SettingsCardMinHeight; the segment
    // track is a 32-tall control inside 16 of padding, so it fits under the
    // floor and the floor is what this reports until a label wraps past it.
    implicitHeight: Math.max(Fluent.cardMinHeight, header.implicitHeight + Fluent.cardPadding * 2, track.height + Fluent.cardPadding * 2)

    radius: Fluent.controlRadius
    color: mouse.containsMouse ? Fluent.fillHover : Fluent.fillRest

    border.width: 1
    border.color: Theme.outlineVariant

    // SettingsCard's own transition and the only animation in this file:
    // `<win:BrushTransition Duration="0:0:0.083" />` on PART_RootGrid's
    // background. Fluent.hoverMs is 0 for everything else on purpose, and the
    // segments below therefore swap their fills instantly.
    Behavior on color {
        ColorAnimation {
            duration: Fluent.fasterMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Fluent.easeOut
        }
    }

    // The dim is drawing and it lives here; `enabled` itself arrives down the
    // item tree with nothing forwarded by hand. See rule 6 in
    // themes/genesis/components/README.md.
    opacity: root.enabled ? 1 : Fluent.disabledOpacity

    // The card lights up as one object and takes no clicks of its own; the
    // segments are the targets.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // SettingsCardHeaderIconMargin is "2,0,20,0" -- a 20-wide icon column and a
    // 20 gap to the words. See ToggleRow.qml in this directory on why the 20 is
    // honoured as a box and the 2 is not carried.
    Item {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        visible: root.row.glyph !== ""
        width: root.row.glyph !== "" ? Fluent.cardIconMax : 0
        height: Fluent.cardIconMax

        Text {
            anchors.centerIn: parent

            text: root.row.glyph
            font.family: Theme.fontFamily
            font.pointSize: Theme.iconSize
            color: Theme.textOnSurface
        }
    }

    Row {
        id: header

        anchors.left: mark.right
        anchors.leftMargin: root.row.glyph !== "" ? Fluent.cardIconGap : 0
        anchors.right: track.left
        // HeaderPanel's own Margin="0,0,24,0": the gutter Windows keeps in
        // front of a card's content whatever the content turns out to be.
        anchors.rightMargin: Fluent.cardActionGutter
        anchors.verticalCenter: parent.verticalCenter

        spacing: Theme.itemSpacing

        // 14 at Normal weight: SettingsCard sets `FontWeight Normal` outright,
        // and Windows keeps Semibold for emphasis. It elides rather than
        // wrapping because of the mark beside it -- a wrapped label would take
        // the info glyph down to a second line, away from the words it belongs
        // to.
        Text {
            id: headerText

            anchors.verticalCenter: parent.verticalCenter

            width: Math.min(implicitWidth, header.width - (hintMark.visible ? hintMark.width + header.spacing : 0))
            elide: Text.ElideRight

            text: root.row.label
            font.family: Theme.fontFamily
            font.pointSize: Fluent.bodySize
            font.weight: Fluent.normalWeight
            color: Theme.textOnSurface
        }

        // A hit area larger than the glyph: the mark itself is about ten pixels
        // across, which is a target you have to aim at. 20 is the header icon
        // column, reused here so the two marks on one card agree.
        Item {
            id: hintMark

            anchors.verticalCenter: parent.verticalCenter

            visible: root.row.hint !== ""
            width: Fluent.cardIconMax
            height: Fluent.cardIconMax

            Text {
                anchors.centerIn: parent

                text: Icons.info
                font.family: Theme.fontFamily
                font.pointSize: Theme.iconSize
                color: hintMouse.containsMouse ? Theme.primary : Theme.outline
            }

            MouseArea {
                id: hintMouse

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
        }
    }

    // Aligned with the card's own padding, NOT with the mark that opens it: the
    // mark sits after the label, most of the way across a card that is itself
    // most of the pane's width, so a note wide enough to read would start there
    // and run off the right edge -- where the Flickable clips it. The vertical
    // decision is Tooltip's; the band it must not cover is this whole card.
    Tooltip {
        text: root.row.hint
        shown: hintMouse.containsMouse

        x: Fluent.cardPadding
        z: 200
    }

    // ---------------- The segmented control ----------------
    //
    // One outlined track at the control radius and the control height, with the
    // segments touching inside it. They touch because that is what makes them
    // ONE control: a gap here and it is a row of loose buttons, which is the
    // thing the facade's header says this must not become.
    Rectangle {
        id: track

        anchors.right: parent.right
        anchors.rightMargin: Fluent.cardPadding
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: strip.implicitWidth + 2
        width: implicitWidth
        height: Fluent.controlHeight
        radius: Fluent.controlRadius

        color: "transparent"
        border.width: 1
        border.color: Theme.outlineVariant

        Row {
            id: strip

            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            Repeater {
                // The hoisted list, not `row.options`. See the note at the top
                // of this file on why the seam is crossed above and not here.
                model: root.segments

                Rectangle {
                    id: segment

                    required property var modelData

                    readonly property bool current: segment.modelData.value === root.currentValue

                    width: caption.implicitWidth + Fluent.controlPaddingH * 2
                    height: parent.height

                    // The outer arc less its 1px stroke, which is the whole of
                    // why there is no 7 anywhere in Windows 11.
                    radius: Fluent.controlRadius - 1

                    // THE SELECTED FILL AND THE HOVER FILL ARE THE SAME COLOUR,
                    // deliberately. Selection is the bar below, not the
                    // backplate. Instant, with no Behavior: Windows swaps a
                    // control's brush on a DiscreteObjectKeyFrame at KeyTime 0.
                    color: segment.current || segmentMouse.containsMouse ? Fluent.fillSubtleHover : "transparent"

                    Text {
                        id: caption

                        anchors.centerIn: parent

                        text: segment.modelData.text
                        font.family: Theme.fontFamily
                        font.pointSize: Fluent.bodySize
                        font.weight: Fluent.normalWeight
                        color: segment.current ? Theme.textOnSurface : Theme.textOnSurfaceVariant
                    }

                    // NavigationView's indicator, turned on its side: 3 across
                    // the short way, 16 the long way, radius 2, flush with the
                    // edge and centred on the other axis. Microsoft publishes
                    // no resources for the segmented control, so this is the
                    // selection rule applied rather than a measurement.
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter

                        visible: segment.current
                        width: Fluent.indicatorHeight
                        height: Fluent.indicatorWidth
                        radius: Fluent.indicatorRadius

                        color: Theme.primary
                    }

                    // `segment.enabled` AND NOT `root.enabled`, which is not a
                    // shortcut. A MouseArea shadows `enabled` with a flag of its
                    // own and does not follow the item tree, but an Item's
                    // `enabled` IS the effective value computed down that tree
                    // -- measured in rule 6 of
                    // themes/genesis/components/README.md, where a Rectangle
                    // under a disabled ancestor reads false while the MouseArea
                    // under it reads true. Reading the delegate's own id keeps
                    // this a qualified read; naming `root` here would be one
                    // more unchecked reach out of the delegate.
                    MouseArea {
                        id: segmentMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: segment.enabled
                        onClicked: root.choose(segment.modelData.value)
                    }
                }
            }
        }
    }
}
