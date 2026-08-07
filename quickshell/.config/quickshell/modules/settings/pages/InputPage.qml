// Mouse and keyboard: how far the pointer moves for a given push, and how
// fast a held key repeats.
//
// ALL OF IT IS THE COMPOSITOR'S. Hyprland owns libinput here; the shell never
// sees a pointer event that is not already scaled by these numbers, and
// cannot apply any of them itself. Everything on this page goes out through
// `hypr-tweak` -- one state file, one generated tweaks.lua, `hyprctl eval`
// for the running session. See that script's header.
//
// WHAT IS NOT HERE, and each absence is a decision rather than a gap:
//
//   - The keyboard LAYOUT. It is the single clearest thing in this
//     configuration that belongs to one machine and one person: these
//     dotfiles are pulled by a second machine with a different one, which is
//     the whole reason local.lua exists and is gitignored. A settings window
//     writing it into a shared generated file would hand this machine's
//     layout to that one on the next pull.
//   - Per-device settings. Hyprland can configure each mouse separately with
//     hl.device, and a page that offered it would need a device list, a
//     per-device store and a way to talk about a mouse that is not plugged in
//     today. The values here are the defaults every device inherits, which is
//     what somebody adjusting their pointer speed actually means.
//   - Anything touchpad. There is no touchpad on this machine, and a section
//     that is always empty teaches the eye to skip the page.

import QtQuick
import "root:/"
import "root:/components"
import "root:/modules/settings"

SettingsPage {
    id: root

    title: "Input"
    glyph: Icons.mouse
    keywords: ["mouse", "pointer", "sensitivity", "speed", "acceleration",
        "accel", "scroll", "natural scroll", "keyboard", "repeat", "delay",
        "key repeat"]

    SettingsSection {
        width: parent.width
        glyph: Icons.mouse
        title: "Mouse"

        // STORED IN HUNDREDTHS AND SHOWN AS A FRACTION. Hyprland takes
        // -1.0..1.0 and the script keeps whole numbers, because bash has no
        // floating point and a shell script that shells out to bc to check a
        // number is a shell script looking for a different language. The
        // conversion happens once, here and in the script, and the two agree
        // because neither of them rounds.
        StepperRow {
            glyph: Icons.mouse
            label: "Pointer speed"
            value: Config.sensitivity
            from: -100
            to: 100
            step: 5
            display: (Config.sensitivity / 100).toFixed(2)
            onMoved: value => Config.setTweak("sensitivity", value)

            hint: "Zero is the hardware's own speed, which is what libinput "
                + "reports before anything is applied to it. Negative is "
                + "slower, positive is faster; this is not a DPI setting and "
                + "the mouse's own is untouched."
        }

        ChoiceRow {
            glyph: Icons.tune
            label: "Acceleration"
            options: [
                { label: "Adaptive", value: "adaptive" },
                { label: "Flat", value: "flat" }
            ]
            value: Config.accel
            onChosen: value => Config.setTweak("accel", value)

            hint: "Adaptive moves the pointer further when the mouse moves "
                + "faster, which is what a desktop expects. Flat maps "
                + "movement one to one at any speed, which is what a game "
                + "expects — if you have ever turned acceleration off in a "
                + "shooter, this is that setting."
        }

        ToggleRow {
            glyph: Icons.swapVertical
            label: "Natural scrolling"
            checked: Config.naturalScroll
            onToggled: value => Config.setTweak("natural-scroll", value ? 1 : 0)
        }
    }

    SettingsSection {
        width: parent.width
        glyph: Icons.keyboard
        title: "Keyboard"

        // THE TWO HALVES OF HOLDING A KEY DOWN, and they are easy to confuse
        // because both are "how fast does it repeat". The delay is how long
        // before the first repeat -- the guard against a key held a moment too
        // long turning into ten characters. The rate is how quickly they come
        // after that.
        StepperRow {
            glyph: Icons.keyboard
            label: "Repeat delay"
            value: Config.repeatDelay
            from: 150
            to: 800
            step: 25
            suffix: " ms"
            onMoved: value => Config.setTweak("repeat-delay", value)

            hint: "How long a key has to be held before it starts repeating."
        }

        StepperRow {
            glyph: Icons.keyboard
            label: "Repeat rate"
            value: Config.repeatRate
            from: 10
            to: 80
            step: 5
            suffix: "/s"
            onMoved: value => Config.setTweak("repeat-rate", value)

            hint: "Characters per second once it has started."
        }
    }
}
