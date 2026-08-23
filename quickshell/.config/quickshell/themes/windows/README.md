# windows

Windows 11, dark, drawn by Quickshell.

## WHAT THIS IS AT THIS COMMIT

**A copy of genesis with a different manifest and different tokens.** Nothing
in it has been redrawn yet. It exists first so that everything after it has
somewhere to land and something green to move: the tests run against it, the
picker lists it, and a component redrawn tomorrow replaces a file that already
loads today rather than creating one that never did.

If you are reading this and the theme still looks like genesis with square
corners, that is not a bug, that is this commit.

## THE POINT OF IT

Genesis proved the seam holds. It did not prove the seam is *enough*, because
genesis is the design the seam was cut around — the interface was drawn to fit
what was already there. The fixture in `tests/fixtures/theme-probe/` does not
answer the question either: it is flat magenta rectangles on purpose, and it
demonstrates the mechanism, not a look.

This theme is the first one designed against a specification written by
somebody else. If it comes out right, twenty-nine components and seven surfaces
were the correct cut. If it needs surfaces the host does not offer, that is the
finding, and it is worth more than the theme.

## WHERE THE NUMBERS COME FROM

Not from screenshots, where there was a choice. Microsoft ships its design
system as source and most of what this theme needs is read out of it:

| What | Where |
|---|---|
| Colour, radii, motion, shadows, control geometry | `microsoft/microsoft-ui-xaml`, `controls/dev/CommonStyles/*_themeresources.xaml` |
| The settings card and expander | `CommunityToolkit/Windows`, `components/SettingsControls` |
| The sixteen ANSI slots | Windows Terminal's shipped **Campbell** scheme |
| Taskbar and Start geometry | **Nothing.** Microsoft publishes none of it |

**In a WinUI theme dictionary, `x:Key="Default"` IS the dark dictionary.**
`x:Key="Light"` is light. Getting that backwards is the single most common way
a Fluent recreation goes wrong, and it goes wrong invisibly — every colour is a
real Microsoft colour, just the other theme's.

The taskbar is shell chrome and has no public design documentation at all. Its
numbers here are measured off screenshots or read out of the C++ of Windhawk
mods that replicate stock behaviour. Every one of them is called out at its
line in `theme.json`, and where a value is ours rather than Microsoft's the
comment says so. **A number nobody published is a design decision wearing a
measurement's clothes**, and the two are not allowed to look alike in this
directory.

## WHAT IT PINS

Nothing yet. It will pin `windows-11-dark` — 78 roles taken from the source
above — once that scheme lands, and at that point choosing this theme moves
kitty, GTK, Zen and the shell together. That is what `pinned` is for, and
`Theme.qml` names this exact case when it explains why a theme carrying private
colours was declined rather than deferred: it *"would produce a Windows shell
over a Catppuccin terminal."*

## WHAT IT WILL NOT BE ABLE TO DO

Listed here because they were found before the work started rather than during
it, and because the next person to read this file will otherwise think they are
bugs:

- **Tray context menus stay genesis's.** `components/MenuView.qml` has no theme
  half — it is a delegate end to end, so a theme half would get no checking
  from qmllint and pay the full cost anyway. Separator colour, entry height and
  entry spacing are not ours.
- **The settings search empty state** is plain host `Text`.
- **`SectionNote`** is host-drawn at fourteen sites; the explanatory sentence
  under a settings group follows tokens, not our drawing.
- **The display page's arrangement map** is outside the interface. Four of its
  widgets are ours; the map and its dragger are not.
- **The settings window is a `FloatingWindow` at 820x580.** Its size and its
  fifteen-page list are host-owned.

## THE TWO HOST CHANGES THIS THEME ASKED FOR

Both were made before it, both are their own commits, and both are listed here
because a theme that needed the host to move is a fact about the interface:

1. **The notification daemon moved host-side.** It used to live in
   `notifications/Notifications.qml`, which is a theme file, so every theme
   would have had to reimplement `org.freedesktop.Notifications` or leave the
   desktop with no notifications at all while it was selected.
2. **`railWidth` became a token.** Windows' navigation pane is 320px and the
   facade declared 210 on itself. Drawing cannot fix a rail width: the label
   column, the icon gutter and the selection pill inset all derive from it.

## READ NEXT

`components/README.md` in `themes/genesis/` — the seven rules, the leaf and
slot patterns, and the empty-implementation pattern. They are not genesis's
rules, they are the interface's, and this theme obeys them.
