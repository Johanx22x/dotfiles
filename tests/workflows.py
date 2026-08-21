#!/usr/bin/env python3
"""Ask whether the workflows in .github/workflows/ will actually run.

Every other check in tests/ asks a question about the repository's content.
This one asks a question about the thing that asks the questions, because that
layer had nobody watching it and it failed exactly the way an unwatched layer
does -- quietly.

WHAT WENT WRONG, AND WHY IT WAS INVISIBLE. checks.yml triggered on
`pull_request: branches: [master]`. Once this repository moved to stacked pull
requests, where a pull request's base is the branch below it, such a pull
request matched no trigger and no check of any kind started on it. Pull
requests #58 and #59 merged that way. A check that never starts leaves no
failure, no red tick and no entry on the page: it is indistinguishable from a
check nobody ever wrote. That is the whole difficulty -- a broken check
announces itself, an absent one does not -- so the only defence is something
that goes looking.

THE TWO HALVES, AND WHY NEITHER IS ENOUGH ALONE.

  actionlint knows GitHub's schema and this script does not. It is the thing
  that catches `pull_reqest:` for `pull_request:`, an action reference with no
  ref, an expression naming a context that does not exist -- every way a
  workflow file can be wrong enough that GitHub declines to run it. Rewriting
  any of that here would be writing a worse actionlint.

  This script knows THIS repository's rules and actionlint does not. Pointed at
  checks.yml as it stood before the fix, actionlint says nothing at all, and it
  is right not to: filtering a `pull_request` trigger by base branch is a
  perfectly ordinary thing for a workflow to do. It is wrong HERE, for a reason
  that lives in how this repository is worked rather than in the file.

Run it from anywhere:  tests/workflows.py
"""

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
WORKFLOWS = REPO / ".github" / "workflows"

problems: list[str] = []


def fail(where: str, message: str) -> None:
    problems.append(f"{where}: {message}")


# --- The `on:` trap ---------------------------------------------------------
# YAML 1.1 -- which is what PyYAML implements, and what yamllint's `truthy`
# rule is complaining about when it objects to workflow files -- reads a bare
# `on` as the boolean true. So `yaml.safe_load` hands back the key `True` and
# not the string "on", and a naive `spec.get("on")` finds nothing on every
# workflow ever written. GitHub's own parser does not do this; the quirk is
# only ever on this side of the fence.
def triggers(spec: dict) -> dict:
    on = spec.get(True, spec.get("on"))
    if on is None:
        return {}
    if isinstance(on, str):            # on: push
        return {on: None}
    if isinstance(on, list):           # on: [push, pull_request]
        return {name: None for name in on}
    return on                          # on: {push: {...}}


# --- Read them all ----------------------------------------------------------
files = sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml"))
if not files:
    print("workflows: no workflow files found -- that cannot be right", file=sys.stderr)
    sys.exit(2)

specs: dict[Path, dict] = {}
for path in files:
    try:
        spec = yaml.safe_load(path.read_text())
    except yaml.YAMLError as exc:
        # A workflow GitHub cannot parse does not run, and the way it says so
        # is a line on the Actions tab that nobody opens when nothing appears
        # to be wrong with their pull request.
        fail(path.name, f"is not valid YAML: {exc}")
        continue
    if not isinstance(spec, dict):
        fail(path.name, "parses to something that is not a mapping")
        continue
    specs[path] = spec

print(f"workflows: {len(specs)} workflow file(s)")

# --- actionlint -------------------------------------------------------------
# WITH ITS SHELLCHECK GATED AT error, which is the same line tests/shell-lint.sh
# draws and for the same reason its header gives at length: a check that is red
# the day it arrives is a check everybody learns to scroll past. actionlint
# runs shellcheck over every `run:` block -- coverage nothing else here has,
# since those scripts live inside YAML and `git ls-files` cannot see them --
# and at its default severity the two SC2016 notes already in
# xwayland-satellite-watch.yml would have made this permanently red over two
# deliberately single-quoted expressions. shellcheck reads SHELLCHECK_OPTS out
# of the environment, so the setting reaches it through actionlint without
# actionlint having to offer a flag for it.
actionlint = shutil.which("actionlint")
if actionlint:
    env = dict(os.environ, SHELLCHECK_OPTS="--severity=error")
    result = subprocess.run(
        [actionlint, "-oneline"], cwd=REPO, env=env,
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        for line in (result.stdout + result.stderr).splitlines():
            fail("actionlint", line)
    else:
        print("workflows: actionlint is happy")
elif os.environ.get("GITHUB_ACTIONS"):
    # NOT SKIPPED IN CI, EVER. Skipping a missing tool is the right answer on a
    # machine where somebody has not installed it yet and the wrong one here:
    # the day the pacman line in checks.yml loses `actionlint`, a silent skip
    # would take this check with it and print a green tick either way, which is
    # this file's own subject matter.
    fail("actionlint", "is not installed, and in CI that is a failure, not a skip")
else:
    print("workflows: actionlint not installed, skipping it -- pacman -S actionlint")

# --- This repository's own rules -------------------------------------------
for path, spec in specs.items():
    name = path.name
    on = triggers(spec)

    # A workflow with no trigger is a file that runs never. It is legal YAML,
    # it is legal to GitHub, and it is silent.
    if not on:
        fail(name, "has no `on:` trigger, so it never runs")

    # RULE ONE, and the reason this file exists. A `pull_request` trigger is
    # how a check gates a pull request in this repository, and gating must not
    # depend on where the branch happens to be aimed. Stacked pull requests
    # aim at each other; the next stack will invent branch names that are not
    # written down anywhere yet, and a base filter goes quiet for them without
    # saying anything.
    #
    # `pull_request_target` is deliberately not covered. notify-discord.yml
    # uses it with `branches: [master]` and that filter is its content, not a
    # mistake: it announces that master has moved, and a pull request merging
    # into the middle of a stack has not moved master.
    settings = on.get("pull_request") or {}
    if isinstance(settings, dict):
        for key in ("branches", "branches-ignore"):
            if key in settings:
                fail(
                    name,
                    f"filters `pull_request` by `{key}: {settings[key]}`. A pull "
                    "request based on another branch -- which is every stacked "
                    "one -- would match no trigger and run nothing at all. "
                    "Remove the filter.",
                )

    # RULE TWO: what carries secrets does not check out the branch.
    #
    # `pull_request_target` runs with the repository's secrets available even
    # when the pull request comes from a fork, and it runs the workflow file
    # from the BASE branch -- which is what makes it safe, and what stops being
    # safe the moment the job checks out the head and runs anything from it.
    # notify-discord.yml says "Do not add a checkout step here" in its header
    # and has said so since it was written. A sentence in a comment is not a
    # check; this is.
    if "pull_request_target" in on:
        for job in (spec.get("jobs") or {}).values():
            for step in (job or {}).get("steps") or []:
                uses = str(step.get("uses", ""))
                run = str(step.get("run", ""))
                if uses.startswith("actions/checkout"):
                    fail(name, f"is `pull_request_target` and uses {uses}")
                if re.search(r"\bgit\s+(clone|fetch|checkout)\b", run):
                    fail(name, "is `pull_request_target` and checks out by hand in a `run:`")

# --- RULE THREE: every check is wired into a workflow -----------------------
# The header of checks.yml makes a point of every check being a script in
# tests/ that runs on its own, so that nobody has to push a branch to run one.
# The cost of that shape is that WIRING a new check into a workflow is a
# separate act from writing it, and a separate act is one that can be
# forgotten -- leaving an executable test in the tree that passes locally,
# that nobody runs, and that therefore guards nothing. Same bug as the trigger,
# one floor down.
#
# The test is deliberately dumb: does the file's path appear anywhere in any
# workflow file. That covers `run: tests/foo.sh` and it covers the longer forms
# with $GITHUB_WORKSPACE in front, without this script having to understand
# shell.
workflow_text = "\n".join(p.read_text() for p in files)
checks = sorted(
    p for p in (REPO / "tests").iterdir()
    if p.suffix in {".sh", ".py"} and os.access(p, os.X_OK)
)
for check in checks:
    rel = check.relative_to(REPO).as_posix()
    if rel not in workflow_text:
        fail(
            rel,
            "is an executable check that no workflow names, so nothing ever "
            "runs it. Add a step to .github/workflows/checks.yml, or drop the "
            "executable bit if it is a helper rather than a check.",
        )
print(f"workflows: {len(checks)} executable check(s) in tests/")

# --- Verdict ----------------------------------------------------------------
if problems:
    print(file=sys.stderr)
    for problem in problems:
        print(f"workflows: {problem}", file=sys.stderr)
    print(file=sys.stderr)
    print("workflows: the CI above would not do what it looks like it does.", file=sys.stderr)
    sys.exit(1)

print("workflows: the workflows run, and they run on every pull request")
