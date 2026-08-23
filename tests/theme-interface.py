#!/usr/bin/env python3
"""Ask whether every theme in this repository implements the whole interface.

A theme is a directory the shell loads its drawing out of at runtime. The host
never imports one and never instantiates a type from one: it asks
`modules/Themes.qml` to turn a path into a URL and loads that URL. So a theme
is not checked by the compiler, it is not checked by qmllint -- which reads
`quickshell/.config/quickshell` and finds a theme's files only as files nothing
imports -- and it is not checked by anything else in here.

WHAT GOES WRONG WHEN NOTHING ASKS, and it is worse than a missing file usually
is, because the failure is per USE and not per theme.
`themes/genesis/components/README.md` is explicit that there is no per-file
fallback: `modules/Themes.qml` falls back to the shipped theme when a MANIFEST
cannot be read, and nothing at all falls back when one FILE inside an otherwise
usable theme is absent. A theme missing `components/ToggleRow.qml` gets a
Loader in `Loader.Error` and one Quickshell warning naming the path, per row,
per open -- and the settings window still opens, still scrolls, and draws
twenty-eight rows of nothing where the rows were. The shell comes up.
`tests/shell-load.sh` comes up green: it asserts on `ReferenceError`,
`TypeError`, `Unable to assign`, `is not a type`, `Syntax error` and
`Binding loop detected`, and a Loader that cannot find a file produces none of
those six.

WHERE THE LIST OF FILES COMES FROM, WHICH IS THE ONE DECISION IN THIS FILE.

It is DERIVED FROM THE HOST -- from the side that does the asking -- and not
written down here, and not read off the theme that ships with the shell. There
were three candidates and only one of them is checkable against anything:

  A LIST IN THIS FILE, hand-written. It catches a file deleted from a theme,
  which is the point. It also goes stale in exactly the way a list maintained
  by hand goes stale, silently, at the moment somebody splits a twenty-first
  component -- and there is direct evidence of that happening here rather than
  in the abstract. `themes/genesis/components/README.md` opens by saying
  "Nineteen components have a theme half, which is every `.qml` in this
  directory" and prints the nineteen names. `components/ScrollBar.qml` calls
  `Themes.surface("components/ScrollBar.qml")`, and
  `themes/genesis/components/ScrollBar.qml` is on disk. The list was one short
  before it was a day old, in the same branch that wrote it.

  THE SHIPPED THEME, listed by walking `themes/genesis/`. This cannot go stale.
  It also cannot fail: a file deleted from genesis deletes the requirement in
  the same stroke, so the one thing the check exists to catch is the one thing
  it would be blind to. And it over-requires in the other direction, because a
  theme's INTERNALS are its own -- genesis has fifty `.qml` files and the
  interface names twenty-seven of them. The other twenty-three (`bar/Clock.qml`,
  the whole of `island/`, `launcher/ClipboardPicker.qml`) are reached by
  relative import from inside genesis and are nothing the host has ever heard
  of. A theme that draws its clock differently, or has no island at all, is a
  legal theme.

  THE HOST'S OWN CALL SITES, which is what this does. Two greps: the `file:`
  of every `ThemeSurface` in `shell.qml`, and every literal string handed to
  `Themes.surface()` anywhere under `components/` and `modules/`. That list is
  the definition of the interface rather than a copy of it -- a facade that
  loads a theme file is a file the theme must have, by construction -- so it
  cannot go stale, and a file deleted from ANY theme, genesis included, is
  still missing against it. The requirement and the requirer move together
  because they are the same line of code.

  What it cannot see is a facade deleted together with its call sites. That is
  the correct answer rather than a hole: a component the host has stopped
  loading is a component no theme owes it any more.

THE FLOORS ARE ON THE DERIVATION AND NOT ON THE INTERFACE. Two greps that stop
matching return nothing, and a check that requires nothing of every theme
passes every theme -- in the same words it uses when it means it. So the counts
below are a floor under the greps: they say "the derivation still works", not
"the interface may not shrink". They sit well below today's 7 and 20 for that
reason, and if a legitimate change ever takes the real number below one of
them, the floor is what should move.

AND THERE HAS TO BE MORE THAN ONE THEME. `tests/fixtures/theme-probe/` exists
because a check that reads one theme's files and compares them against a list
derived from the host has proved that genesis is complete, and nothing else. It
is deliberately ugly and it deliberately lives outside `themes/` so that
nothing on the desktop offers it: it is copied into a sandbox by
`tests/shell-load.sh` and it is the second implementation the seam has ever
had. This file requires it to be complete on the same terms as genesis, which
is the only thing that keeps it in step.

Run it from anywhere:  tests/theme-interface.py
"""

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHELL_DIR = REPO / "quickshell" / ".config" / "quickshell"
THEMES_DIR = SHELL_DIR / "themes"

# THE FIXTURE, AND WHY IT IS NAMED HERE RATHER THAN FOUND. It is the one theme
# that is not in themes/, so there is nothing to glob it out of -- and being
# named is what makes its ABSENCE a failure. A fixture that had to be
# discovered would take this check back to one theme by being deleted.
PROBE = REPO / "tests" / "fixtures" / "theme-probe"

# The one file the greps below cannot find, because nothing loads it through
# Themes.surface(): it is what MAKES a directory a theme. `modules/Themes.qml`
# reads it to check the interface number and falls back to the shipped theme
# when it cannot, and `Theme.qml` reads it again for the palette source.
#
# theme.json is deliberately NOT here. It is the theme's design tokens and it
# is optional by construction -- Theme.qml's `onLoadFailed` leaves every token
# at the host's default, so "a theme that ships no theme.json is a theme that
# changed nothing", which is a legal theme and the fixture is one.
MANIFEST = "manifest.json"

# Floors on the two greps. See the header: these are not a budget on the
# interface, they are an assertion that the derivation still finds it.
MIN_SURFACES = 5
MIN_COMPONENTS = 15

problems: list[str] = []


def fail(where: str, message: str) -> None:
    problems.append(f"{where}: {message}")


# --- What the host asks a theme for -----------------------------------------
# The surfaces, from shell.qml. `file:` is a path inside the theme directory
# and modules/ThemeSurface.qml is what turns it into a URL.
shell_qml = SHELL_DIR / "shell.qml"
if not shell_qml.is_file():
    print(f"theme-interface: {shell_qml} is missing -- has the layout changed?",
          file=sys.stderr)
    sys.exit(2)

surfaces = sorted(set(re.findall(r'^\s*file: "([^"]+)"',
                                 shell_qml.read_text(), re.MULTILINE)))

# The components, from every facade that loads a theme half. A literal string
# only: modules/ThemeSurface.qml's own `Themes.surface(root.file)` is the
# mechanism rather than a call site and matches nothing here, which is right.
components: set[str] = set()
for qml in sorted(SHELL_DIR.rglob("*.qml")):
    # Not inside a theme. Nothing under themes/ calls Themes.surface() today,
    # and a theme that did would be asking the host for its own file.
    if THEMES_DIR in qml.parents:
        continue
    components.update(re.findall(r'Themes\.surface\("([^"]+)"\)', qml.read_text()))

required = sorted(set(surfaces) | components)

if len(surfaces) < MIN_SURFACES:
    fail("shell.qml", f"named only {len(surfaces)} ThemeSurface file(s), and this "
                      f"check needs at least {MIN_SURFACES} to be reading the "
                      "shell at all. Has the `file:` spelling changed?")
if len(components) < MIN_COMPONENTS:
    fail("components", f"only {len(components)} Themes.surface(\"...\") call site(s) "
                       f"found under {SHELL_DIR.name}, and this check needs at "
                       f"least {MIN_COMPONENTS}. Has the facade mechanism changed "
                       "shape?")

print(f"theme-interface: the host asks a theme for {len(required)} file(s) -- "
      f"{len(surfaces)} surface(s), {len(components)} component(s)")

# --- The interface number this host speaks ----------------------------------
# A theme whose manifest claims a different one is refused at runtime and the
# shell draws the fallback in its place, loudly but only in a log nobody reads
# on a desktop that looks merely unchanged. A theme that lives in this
# repository and cannot be loaded by it is a bug in the theme.
themes_qml = (SHELL_DIR / "modules" / "Themes.qml").read_text()
match = re.search(r"readonly property int interfaceVersion: (\d+)", themes_qml)
if not match:
    print("theme-interface: modules/Themes.qml no longer declares "
          "`readonly property int interfaceVersion` -- this check cannot read "
          "what the host speaks", file=sys.stderr)
    sys.exit(2)
interface_version = int(match.group(1))
print(f"theme-interface: this host speaks interface {interface_version}")

# --- Every theme there is ---------------------------------------------------
themes = sorted(p for p in THEMES_DIR.iterdir() if p.is_dir()) if THEMES_DIR.is_dir() else []

# THE FIXTURE IS OUTSIDE themes/ AND MUST STAY THERE. It is not a theme
# anybody may choose; it is a second implementation kept for the checks. A
# picker offers what is in themes/, so a fixture that drifted in there would be
# a deliberately ugly desktop one click away.
if PROBE.parent.resolve() == THEMES_DIR.resolve() or THEMES_DIR in PROBE.parents:
    fail(PROBE.relative_to(REPO).as_posix(),
         "has moved inside themes/, where a theme picker would offer it. It is "
         "a test fixture and belongs under tests/fixtures/.")

if not PROBE.is_dir():
    fail("tests/fixtures/theme-probe",
         "is missing. It is the second implementation of the interface and the "
         "only thing that makes this check -- and the per-theme startups in "
         "tests/shell-load.sh -- more than a statement about genesis.")
else:
    themes.append(PROBE)

# THE FLOOR ON THE COLLECTION, for the same reason the two above are floors on
# the greps. One theme is the state this whole file was written to get out of,
# and zero themes would make every loop below run no times and print a pass.
if len(themes) < 2:
    fail("themes", f"found only {len(themes)} theme(s) to check. One theme cannot "
                   "show that the host is neutral about which theme it draws -- "
                   "it can only show that theme is complete.")

# --- Does each of them implement the whole thing ----------------------------
for theme in themes:
    where = theme.relative_to(REPO).as_posix()

    missing = [f for f in required if not (theme / f).is_file()]
    if missing:
        fail(where, f"is missing {len(missing)} file(s) the host loads by path:\n"
                    + "\n".join(f"        {f}" for f in missing))

    manifest_path = theme / MANIFEST
    if not manifest_path.is_file():
        # Said separately from the list above because the consequence is
        # different in kind: no manifest is not a blank widget, it is the whole
        # theme refused and the shipped one drawn in its place.
        fail(where, f"has no {MANIFEST}, which is what makes a directory a theme. "
                    "modules/Themes.qml would refuse it and fall back.")
        continue

    try:
        manifest = json.loads(manifest_path.read_text())
    except json.JSONDecodeError as exc:
        fail(f"{where}/{MANIFEST}", f"is not JSON: {exc}")
        continue

    declared = manifest.get("interface")
    if declared != interface_version:
        fail(f"{where}/{MANIFEST}",
             f"claims interface {declared!r} and this shell speaks "
             f"{interface_version}. modules/Themes.qml refuses a theme it does "
             "not speak and draws the fallback instead, so this theme is in the "
             "repository and cannot be loaded by it.")

    # NOT FATAL AT RUNTIME AND FATAL HERE, deliberately. Themes.qml warns about
    # the mismatch and loads the theme anyway, because the DIRECTORY is what it
    # loads from and the name is a label. In a repository it is a different
    # thing: a theme copied from another one and left with the original's
    # manifest is exactly the mistake nothing else would notice.
    if manifest.get("name") != theme.name:
        fail(f"{where}/{MANIFEST}",
             f"calls itself {manifest.get('name')!r} in a directory called "
             f"{theme.name!r}.")

print(f"theme-interface: {len(themes)} theme(s) checked -- "
      + ", ".join(t.name for t in themes))

# --- Verdict ----------------------------------------------------------------
if problems:
    print(file=sys.stderr)
    for problem in problems:
        print(f"theme-interface: FAIL {problem}", file=sys.stderr)
    sys.exit(1)

print("theme-interface: every theme implements every file the host loads by path")
