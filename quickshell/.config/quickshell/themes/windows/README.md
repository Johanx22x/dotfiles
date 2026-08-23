# windows

Windows 11, dark, drawn by Quickshell.

## THE ONE RULE THIS THEME EXISTS TO ENFORCE

**Look at a photograph before you write a line, and photograph your own work
before you call it done.**

There was a first attempt at this theme. It was built entirely from Microsoft's
published source — `microsoft-ui-xaml`, the Community Toolkit, the Fluent 2
token files — and it got every number right. Johan looked at it and called it
"a cheap adaptation of genesis made to look like Windows 11", and he was
correct. Nobody had ever looked at a real Windows 11.

Here is what a photograph corrected that reading could not:

| Built from the docs | What a photograph shows |
|---|---|
| the running indicator is a 6px grey pill | it is a small **dim dot**, about four pixels; every published width comes from a mod that *redesigns* it |
| the taskbar corner is icons then clock | the **clock is rightmost**; icons sit to its left |
| the keyboard layout is a glyph | it is **two stacked lines**, "ENG" over "IN" |
| the search field has a 4px radius | in the search flyout it is a **pill** |
| search results are `ListViewItem`s | the results screen is **not XAML at all** — it is a WebView2 surface, so there is no metric to look up |
| the search flyout is one column | it is **two**: results, and a preview of the selection with its actions |
| a Quick Settings tile is a square with a label in it | it is a **wide rectangle with the label outside**, and Wi-Fi and Bluetooth are **split** tiles with their own chevron segment |
| one acrylic recipe for everything | the **taskbar is much more transparent than a flyout**; the same documented material gives three different results over three wallpapers |
| stacking surfaces means darkening | **everything that comes forward gets lighter** — a dark theme built the other way reads inverted |

None of those is a small correction. Together they are the difference between
the two attempts.

## WHAT WINDOWS DOES NOT HAVE, AND SO NEITHER DOES THIS

The first attempt began with `cp -r genesis windows`, so **every object in it
existed because it was copied rather than because anyone decided a Windows 11
desktop has one**. That is the structural failure, and deleting the offenders
one by one would only have treated the symptom. This theme was written from
nothing.

Not on the taskbar: no media island, no dashboard, no logo pill, no settings
gear, no power button, no updates glyph, no notification bell. Windows has none
of them there — Start holds the power button, Quick Settings holds the toggles,
and the unread count sits **on the clock**, which is why the clock here is a
door and in genesis it is a reading.

The media controls are not deleted; they are **moved**. Windows puts them in a
card above the Quick Settings grid, and that is where they are. The object was
never wrong. Its place was.

## WHERE THE NUMBERS COME FROM

| What | Where |
|---|---|
| Colour, radii, motion, shadows, control geometry | `microsoft/microsoft-ui-xaml`, `controls/dev/CommonStyles/*_themeresources.xaml` |
| The settings card and expander | `CommunityToolkit/Windows`, `components/SettingsControls` |
| The sixteen ANSI slots | Windows Terminal's shipped **Campbell** scheme |
| The taskbar, Start, Quick Settings, the search flyout | **nothing.** Microsoft publishes none of it |

**In a WinUI theme dictionary, `x:Key="Default"` IS the dark dictionary.**
Getting that backwards is the most common way a Fluent recreation goes wrong,
and it goes wrong invisibly: every colour is a real Microsoft colour, just the
other theme's.

Where nothing is published, the value is marked **`OURS`** at its line in
`Fluent.qml` or in `theme.json`. That distinction is not tidiness. A number
nobody published is a design decision wearing a measurement's clothes, and the
two must not be allowed to look alike.

## THE FIVE THINGS THIS THEME ASKED THE HOST FOR

A theme that needs the host to move is a fact about the interface, so they are
listed rather than buried:

1. **The notification daemon moved host-side.** It lived in a theme file, so
   every theme would have had to reimplement `org.freedesktop.Notifications` or
   leave the desktop with none while it was selected.
2. **`railWidth` became a token.** Windows' navigation pane is 320 and the
   facade declared 210 on itself. Drawing cannot fix a rail width.
3. **`barAtBottom` became a token.** `components/Popout.qml` is a host window
   that has to open on the bar's inner side, and the host cannot see where a
   theme put its bar.
4. **`surfaceAlpha` became a token.** `glassAlpha` was `Config.opacity`
   outright — the dial that also moves kitty, Zen and Nautilus. Those are
   windows and the dial is the user's; the shell's own chrome was inheriting
   the terminal's number by accident, and at 0.95 no amount of correct drawing
   would have made a taskbar that carries a wallpaper's colour.
5. **`Compositor.windowsOn()` publishes the open windows.** A Windows taskbar
   is a list of what is open. Without it the centre of the bar was empty, and
   that emptiness was read as "nothing running in a headless compositor" for
   longer than it should have been.

## THE ONE HEX LITERAL

`#4D000000`, the smoke behind the power flyout. There is no scheme role for it,
it is identical in Microsoft's light and dark dictionaries, and it is cited at
its line. Everything else on screen comes from `Theme`.

## WHAT IT PINS

`windows-11-dark`, 78 roles read out of the source above. Choosing this theme
runs `desktop-scheme pin`, so kitty, GTK, Zen and the shell move together —
and the appearance page stops offering a colour scheme while it is drawn,
because a theme whose look is fixed must not keep asking which colours you
want. Same for the transparency slider.

## WHAT IT WILL NOT BE ABLE TO DO

- **Tray context menus stay genesis's.** `components/MenuView.qml` has no theme
  half at all — it is a delegate end to end.
- **`SectionNote`** is host-drawn at fourteen sites.
- **The display page's arrangement map** is outside the interface.
- **The settings window is a `FloatingWindow` at 820x580**; its size and its
  fifteen-page list are host-owned.
- **The accent still comes from the wallpaper.** That is authentic — Windows'
  own default is "pick an accent colour from my background" — but it means a
  green wallpaper gives a green taskbar indicator, exactly as it would there.

## READ NEXT

`themes/genesis/components/README.md` — the seven rules, the leaf and slot
patterns, and the empty-implementation pattern. They are not genesis's rules,
they are the interface's, and this theme obeys them.

`Fluent.qml` — every Windows number that is not a colour, with its source at
its line. Reach it with `import qs.themes.windows` and **never** `import ".."`:
the relative form resolves the type rather than the singleton when a file is
loaded by URL, which is how every theme file is loaded, and it fails silently.
Measured: 2240 `Unable to assign [undefined]` warnings against zero.
