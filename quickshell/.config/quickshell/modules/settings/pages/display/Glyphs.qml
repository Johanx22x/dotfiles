// Glyphs that are not in Icons yet.
//
// TEMPORARY, and they belong in Icons.qml -- they are here only because that
// file is being edited elsewhere. Move them when it is free; the codepoints
// should not change on the way. This file is where the display page's local
// ones were collected when the page was split up, and it exists so that the
// three parts that draw them do not each grow a copy.
//
// All of them were read out of the installed font's cmap rather than looked up
// by name, which is the rule Icons.qml's own comments set after two of its
// entries turned out to draw a bluetooth speaker and a shower head:
//
//   python3 -c "from fontTools.ttLib import TTFont; \
//     print(TTFont('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf') \
//       .getBestCmap()[0xF014D])"

pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property string chevronLeft: String.fromCodePoint(0xF0141)     // nf-md-chevron_left
    readonly property string check: String.fromCodePoint(0xF012C)           // nf-md-check
    readonly property string screenRotation: String.fromCodePoint(0xF0475)  // nf-md-screen_rotation
    readonly property string relativeScale: String.fromCodePoint(0xF0452)   // nf-md-relative_scale
    readonly property string arrowExpand: String.fromCodePoint(0xF0616)     // nf-md-arrow_expand
    readonly property string timerSand: String.fromCodePoint(0xF051F)       // nf-md-timer_sand

    // For the Keep button, which used to carry a tick. A tick said "yes, this
    // is fine" and the button now also writes the change to disk, so it says so
    // -- read out of the cmap like the rest: 0xF0193 is md-content_save. The
    // undo of it did NOT need adding, because Icons.restore is already 0xF099B,
    // md-restore; the Forget chip uses that rather than an eighth local.
    readonly property string contentSave: String.fromCodePoint(0xF0193)     // nf-md-content_save

    // THERE WAS A SEVENTH AND IT IS GONE, which is worth recording because the
    // reason it existed was a bug and not a gap. The cmap check above caught
    // Icons.clipboard pointing at 0xF0385 -- md-MUSIC_BOX_OUTLINE in the font
    // installed here -- while its comment called it nf-md-clipboard_text, which
    // is 0xF014D. So the Copy config chip carried a local `clipboardText` and
    // the launcher's clipboard mode drew a music box. Icons.clipboard is
    // 0xF014D now, so the chip uses it and the duplicate is deleted rather than
    // left to drift.
}
