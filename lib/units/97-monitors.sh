# shellcheck shell=bash
# Monitors. NOT rewritten automatically, and that is deliberate: which screen
# is the main one, where the others sit around it and whether any is rotated is
# a layout decision, not something to guess from an EDID. What can be done for
# you is the mechanical half -- reading the descriptions off the hardware that
# is actually plugged in, and saying whether the configuration already knows
# about each screen.
#
# So this unit's _apply prints commands rather than running them, and its
# _check is the whole point of it.
#
# THE NAMES ARE NOT THE SAME NAMES IN THE TWO COMPOSITORS. Both build a
# monitor's description from the same three EDID fields and only one of them
# normalises the manufacturer, so this machine's portrait screen is
# "GIGA-BYTE TECHNOLOGY CO. LTD. GS27FA ..." under Hyprland and "GIGA-BYTE
# TECHNOLOGY CO., LTD. GS27FA ..." -- with the comma -- under niri. Copying a
# name across gets a monitor that silently keeps its preferred mode and no
# rotation. `desktop-monitors` knows that, which is why everything below asks
# it rather than grepping for itself.

monitors_meta() {
  echo "Monitors"
  echo "checks every attached screen against what the configuration records"
}

monitors_requires() { echo symlinks; }

# THIS IS THE UNIT THAT MOST OFTEN CANNOT ANSWER, and saying so plainly is the
# job. Reading the attached monitors means asking a running compositor over its
# socket; from a TTY, over ssh or in a chroot there is nothing to ask, and a
# check that guessed from a config file would report a machine as fine whose
# second screen has never been configured.
monitors_available() {
  if [[ -n ${NIRI_SOCKET:-} ]] && command -v niri >/dev/null; then
    return 0
  fi
  if command -v hyprctl >/dev/null && hyprctl monitors -j >/dev/null 2>&1; then
    return 0
  fi
  echo "no compositor running to ask"
  return 1
}

monitors_tool() { printf '%s\n' "$HOME/.local/bin/desktop-monitors"; }

# EVERY NAME THIS MACHINE HAS RECORDED, from both of the places one can live.
#
# The generated file is read through the script's own output rather than parsed
# here: there is one parser for that format and it lives with the thing that
# writes it.
#
# UNDER HYPRLAND THERE IS A SECOND PLACE, and reading only the first is exactly
# the mistake this check exists to avoid. hyprland.lua carries a hand-written
# monitor block and dofile()s the generated ~/.config/hypr/monitors.lua after
# it, with a later hl.monitor for the same output winning -- so a screen named
# in the tracked config IS configured, and reporting it as unrecorded would
# send somebody off to write a record that is already there.
#
# Under niri there is no second place, by design: an `output` block in an
# included file is IGNORED when the including file names the same monitor, so
# config.kdl declares none at all and the generated monitors.kdl owns them
# outright.
monitors_recorded() {
  local tool
  tool="$(monitors_tool)"
  "$tool" 2>/dev/null | grep -v '^\( \|Main monitor:\|No monitors recorded\)' || true

  if [[ -z ${NIRI_SOCKET:-} && -f "$HOME/.config/hypr/hyprland.lua" ]]; then
    # hyprland.lua writes them "desc:like this" and the generated file writes
    # 'desc:like this', so both quotes end the match.
    grep -ohP "desc:\K[^\"']+" "$HOME/.config/hypr/hyprland.lua" | LC_ALL=C sort -u || true
  fi
}

monitors_attached() {
  local tool
  tool="$(monitors_tool)"
  "$tool" list --json 2>/dev/null | jq -r '.[].description' || true
}

monitors_check() {
  local recorded=() attached=() desc missing=0 total=0

  command -v jq >/dev/null || { echo "na:jq is not installed"; return 0; }
  [[ -x "$(monitors_tool)" ]] || { echo "na:desktop-monitors is not linked yet"; return 0; }

  mapfile -t recorded < <(monitors_recorded)
  mapfile -t attached < <(monitors_attached)

  (( ${#attached[@]} )) || { echo "na:the compositor listed no monitors"; return 0; }

  for desc in "${attached[@]}"; do
    total=$(( total + 1 ))
    # Descriptions carry spaces, commas and a trailing space on at least one
    # real monitor, so membership is compared whole-line and fixed-string and
    # never through word splitting or a pattern.
    if ! printf '%s\n' "${recorded[@]}" | grep -qxF -- "$desc"; then
      missing=$(( missing + 1 ))
    fi
  done

  if (( missing )); then
    echo "missing:$missing of $total screens are not recorded"
  else
    echo ok
  fi
}

monitors_apply() {
  local recorded=() attached=() desc unconfigured=0

  # BOTH OF THESE ARE NOTES, AND NEITHER USED TO BE ANYTHING. This unit writes
  # nothing at all -- it compares the attached screens against the recorded ones
  # and prints instructions -- so nothing here can leave a machine half
  # configured. What it CAN do is silently not run, and the two ways it does
  # that both used to `return 0` with a line on screen and nothing in the
  # summary, so a run ended with no mention that the one step needing a human
  # decision had never been reached.
  if ! command -v jq >/dev/null; then
    ui_say "   jq is not installed, so the monitors cannot be read."
    ui_say "   It is in packages/required/shell.txt."
    fail_note "monitors" "jq is not installed, so the attached screens could not be read" \
      "sudo pacman -S --needed jq && ./install.sh apply monitors"
    return 0
  fi
  if [[ ! -x "$(monitors_tool)" ]]; then
    ui_say "   ~/.local/bin/desktop-monitors is missing -- apply 'symlinks' first."
    fail_note "monitors" "$(monitors_tool) is not linked, so the screens could not be compared" \
      "./install.sh apply symlinks && ./install.sh apply monitors"
    return 0
  fi

  mapfile -t recorded < <(monitors_recorded)
  mapfile -t attached < <(monitors_attached)

  for desc in "${attached[@]}"; do
    if printf '%s\n' "${recorded[@]}" | grep -qxF -- "$desc"; then
      ui_ok "   recorded:     $desc"
    else
      ui_bad "   not recorded: $desc"
      unconfigured=1
    fi
  done

  if (( ! unconfigured )); then
    ui_ok "   every attached monitor is accounted for, nothing to change"
    return 0
  fi

  # NOTHING IS WRITTEN HERE. The commands are printed and the person runs the
  # one they want, after arranging the screens the way they like them -- which
  # is a decision, and the only one in this whole script that no amount of
  # detection can make.
  cat <<'END'

   Those screens work -- both compositors give an unconfigured output its
   preferred mode, no rotation and an automatic position -- but nothing places
   them or sets a rate.

   Arrange them the way you like them, then record what is on screen:

       desktop-monitors seed

   or look at what is connected and set one at a time:

       desktop-monitors list

   That writes ~/.config/hypr/monitors.lua under Hyprland and
   ~/.config/niri/monitors.kdl under niri. Both are generated and gitignored,
   so the tracked configs never need editing -- and under niri, putting an
   output block into config.kdl would SHADOW the generated file for good,
   because an output named in the including file wins over the include.

   The settings window (SUPER + C) does the same thing from a display page that
   applies a change live and puts it back unless you confirm it.
END
}

unit_register monitors
