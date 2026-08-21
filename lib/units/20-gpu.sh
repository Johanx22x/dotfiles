# shellcheck shell=bash
# The graphics driver.
#
# THE ONE THING THE OLD SCRIPT REFUSED TO TOUCH, and the refusal was right for
# the reason it gave: a driver for a card you do not have is not a harmless
# mistake. What was wrong with it was the conclusion. "Install nothing and put a
# paragraph at the end telling you to do it by hand" leaves the single most
# machine-specific decision in the whole setup as the one thing with no support
# at all -- on a repository whose entire argument is that the machine can answer
# what the machine knows.
#
# So the card is read off the bus, the answer is offered rather than assumed,
# and "none" is a first-class answer for a machine whose driver comes from
# somewhere else -- a distribution that ships it, a laptop with a vendor
# installer, a virtual machine.

gpu_meta() {
  echo "GPU driver"
  echo "packages/gpu/<vendor>.txt, for the card this machine actually has"
}

gpu_requires() { echo packages; }

# WHAT lspci SAYS, NOT WHAT IS INSTALLED. Asking "is nvidia-utils here" would
# answer a different question and get it wrong in both directions: an AMD
# machine that once had an NVIDIA card would still say nvidia, and a fresh
# install of anything says nothing at all.
#
# The grep is the one from the notes: -A2 because the "Kernel driver in use"
# line is two below the device, and (VGA|3D) because a laptop's discrete card
# announces itself as a 3D controller rather than as a VGA one.
gpu_detect() {
  local text
  command -v lspci >/dev/null || return 0

  text="$(lspci -k 2>/dev/null | grep -A2 -E '(VGA|3D)' || true)"
  # First match wins and NVIDIA is asked first, because the machine this repo
  # comes from is exactly the awkward case: an Intel iGPU that is present, has
  # no monitor attached and drives nothing, alongside the card that does.
  if   grep -qi 'nvidia'          <<<"$text"; then echo nvidia
  elif grep -qiE 'amd|ati|radeon' <<<"$text"; then echo amd
  elif grep -qi 'intel'           <<<"$text"; then echo intel
  fi
}

# The profile wins over the hardware, because "none" is an answer the hardware
# cannot give.
gpu_vendor() {
  local vendor
  vendor="$(state_get gpu.vendor)"
  [[ -n $vendor ]] && { printf '%s\n' "$vendor"; return 0; }
  gpu_detect
}

gpu_list() { printf '%s\n' "$DOT/packages/gpu/$1.txt"; }

gpu_available() {
  local vendor
  vendor="$(gpu_vendor)"

  if [[ $vendor == none ]]; then
    echo "the driver is handled somewhere else"
    return 1
  fi
  if [[ -z $vendor ]]; then
    echo "no card recognised on the bus"
    return 1
  fi
  if [[ ! -f "$(gpu_list "$vendor")" ]]; then
    echo "there is no packages/gpu/$vendor.txt"
    return 1
  fi
}

gpu_check() {
  local vendor names=() missing=()
  vendor="$(gpu_vendor)"

  mapfile -t names < <(pkg_read_list "$(gpu_list "$vendor")")
  mapfile -t missing < <(pkg_missing "${names[@]}")

  if (( ${#missing[@]} )); then
    echo "missing:$vendor, ${#missing[@]} of ${#names[@]} packages"
  else
    echo "ok"
  fi
}

gpu_apply() {
  local vendor detected names=()

  detected="$(gpu_detect)"
  vendor="$(state_get gpu.vendor)"

  # ASKED ONCE AND REMEMBERED. Detection picks the default, so the common answer
  # is Enter -- but it is offered rather than applied, because this is the one
  # step here that can leave a machine without a working display, and "none" has
  # to be reachable for a machine whose driver comes from elsewhere.
  if [[ -z $vendor ]]; then
    ui_say "   lspci says: ${detected:-nothing recognised}"
    ui_say "   'none' is a real answer: the driver may come from somewhere else."
    vendor="$(ui_choose_one \
      "$(case "$detected" in nvidia) echo 1 ;; amd) echo 2 ;; intel) echo 3 ;; *) echo 4 ;; esac)" \
      nvidia amd intel none)"
    state_set gpu.vendor "$vendor"
    state_save
  fi

  if [[ $vendor == none ]]; then
    ui_say "   none: nothing to install."
    return 0
  fi

  # ONLY packages/gpu/nvidia.txt HAS BEEN RUN ON REAL HARDWARE. The other two
  # resolve against the repositories and no further, and each says so at the top
  # of itself -- which is worth repeating out loud at the moment somebody is
  # about to install one of them.
  if [[ $vendor != nvidia ]]; then
    ui_warn "   packages/gpu/$vendor.txt has never been run on a real card."
    ui_say  "   Every name in it resolves; that is all that has been checked."
  fi

  mapfile -t names < <(pkg_read_list "$(gpu_list "$vendor")")
  pkg_install "gpu/$vendor" "${names[@]}"
}

unit_register gpu
