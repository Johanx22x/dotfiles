# seeds

**This is not a stow package. Never stow it.** Every other top-level directory
here is linked into `$HOME`; this one is *copied* out of, once, by `install.sh`.

A seed is a starting point. The installer copies it to its destination **only
if nothing is there yet**, and never overwrites. From that moment the file
belongs to the machine, not to the repo — edit it in place, and nothing here
will touch it again.

| Seed | Copied to |
|---|---|
| `qt6ct.conf` | `~/.config/qt6ct/qt6ct.conf` |
| `mimeapps.list` | `~/.config/mimeapps.list` |

## Why these two are not symlinks

Because the applications that own them **rewrite them**, and a symlink into a
git repo turns every rewrite into a change to the repository.

`qt6ct` rewrites `qt6ct.conf` in full whenever you save its settings. It does
not preserve comments: the nine-line explanation above `color_scheme_path` was
once mangled into a single URL-encoded line
(`%23%20icon_theme=Adwaita and NOT breeze-dark…`). It also stores
`[SettingsWindow] geometry=@ByteArray(…)`, which is nothing but where you last
left the settings window — machine state, dropped from the seed.

`mimeapps.list` is rewritten by **any** application that claims a default
handler, which is something a browser or a file manager will do on its own.

Symlinked, both left every machine with a permanently dirty working tree and a
collision on every `git pull`. Copied, each machine keeps its own and the repo
keeps a clean starting point.

## What they are for

They are not decoration — a fresh clone without them comes up wrong:

- **`qt6ct.conf`** puts Qt on the **Adwaita** icon theme. Anything that asks Qt
  for an icon *by name* resolves it against that theme, so tray menus asking
  for `bluetooth-symbolic` — present in Adwaita, absent from breeze-dark — get
  a magenta chequerboard from Quickshell's icon provider instead. The reasoning
  is written out in full inside the file.
- **`mimeapps.list`** is the default-application table: Brave for the web,
  Celluloid for video, Loupe for images, zathura for PDFs.

## Editing them

Change a seed and nothing happens to a machine that already has the file —
that is the point. To adopt a change, delete your copy and re-run the seed step
of `install.sh`, or merge it by hand. To capture what your machine has drifted
to, copy the live file back over the seed and read the diff before keeping it:
it will have collected geometry, generated absolute paths and whatever else the
application felt like storing.
