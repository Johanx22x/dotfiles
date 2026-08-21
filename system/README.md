# system

The part of this setup that lives outside `$HOME`, and therefore outside stow.

Nothing here is a symlink and nothing here is linked. `/etc` belongs to the
machine and to pacman — pacman writes `.pacnew` files beside anything it finds
edited, and a symlink into a git repository turns every one of those into a
question about which side is real. So these are **copies and recipes**.

**Nothing here is installed for you, and that is deliberate.**
`./install.sh apply etc` compares every row against the machine, shows you the
diff, and prints the exact command:

```
sudo install -Dm 0644 ~/dotfiles/system/default-grub /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

It runs none of them, with or without `--yes`. Two reasons, and the first is not
about risk. **Half of these files are about one machine**: `fstab` names this
box's UUIDs, `default-grub` points at a `CyberGRUB-2077` theme this repository
does not carry, `modprobe-nvidia-gaming.conf` is for this card, and
`sddm-Xsetup` is where these screens sit. Installing this machine's `fstab` on
another one does not reproduce a setup; it produces a machine that will not
boot. The second reason is that these are the files that decide whether a
machine boots at all, and a container cannot prove anything useful about writing
them — so the one part of the installer that could leave a box unbootable would
also have been the only part with no test behind it.

`./install.sh check` reads the same table and reports what differs without
touching anything — and tells **drift in content apart from drift in comments**,
because several of these files differ from `/etc` only in the language of their
comments and a unit that shouts about that every day is a unit nobody reads.

## The table

| Source | Destination | Mode | Kind |
|---|---|---|---|
| `default-grub` | `/etc/default/grub` | `0644` | copy |
| `fstab` | `/etc/fstab` | `0644` | reference |
| `linux.preset` | `/etc/mkinitcpio.d/linux.preset` | `0644` | copy |
| `linux-lts.preset` | `/etc/mkinitcpio.d/linux-lts.preset` | `0644` | copy |
| `mkinitcpio.conf` | `/etc/mkinitcpio.conf` | `0644` | copy |
| `modprobe-nvidia-gaming.conf` | `/etc/modprobe.d/nvidia-gaming.conf` | `0644` | copy |
| `modules-load-ntsync.conf` | `/etc/modules-load.d/ntsync.conf` | `0644` | copy |
| `pacman.conf` | `/etc/pacman.conf` | `0644` | copy |
| `reflector.conf` | `/etc/xdg/reflector/reflector.conf` | `0644` | copy |
| `sddm-10-general.conf` | `/etc/sddm.conf.d/10-general.conf` | `0644` | copy |
| `sddm-Xsetup` | `/usr/share/sddm/scripts/Xsetup` | `0755` | copy |
| `zram-generator.conf` | `/etc/systemd/zram-generator.conf` | `0644` | copy |
| `bluetooth-main.conf` | `/etc/bluetooth/main.conf` | `0644` | recipe |
| `snapper-root` | `/etc/snapper/configs/root` | `0640` | recipe |

**The table is the interface.** `lib/units/95-etc.sh` parses exactly these rows,
so a new file in this directory reaches the installer by being added here — and
one that is not in the table is reported by name rather than silently ignored.

## The three kinds

**copy** — the file here is what should be at the destination. `check` diffs the
two and `apply` shows you the diff and the `sudo install -Dm <mode>` line that
would apply it, plus `mkinitcpio -P` or `grub-mkconfig` where the file is an
input to one of those. Running it is yours.

**reference** — the file here is a *record of what the machine has*, and must
not be installed anywhere else. There is exactly one, and it is `fstab`: **the
UUIDs in it belong to the original machine.** Installing it on another box gives
you a machine that does not boot. So `apply` prints the opposite direction for
this kind — the `cp` that updates the copy in the repo from the live file, which
is a change git can show you and undo.

**recipe** — not a copy at all, but a document describing edits to make to a
file that belongs to a package and is mostly left at its defaults. There is
nothing to diff, so `check` leaves these out of its counts and `apply` points at
the document.

## Two that are not obvious

`sddm-Xsetup` does **not** go under `/etc`. It goes to
`/usr/share/sddm/scripts/Xsetup`, which is inside a package's own directory —
so a `sddm` upgrade can overwrite it and there is no `.pacnew` to warn you. It
is also the one file here that is executable. What it does is arrange the
monitors for the greeter, which runs on Xorg and knows nothing about the
compositor's rotation; without it the portrait screen comes up sideways on the
login screen.

`bluetooth-main.conf` is a **recipe and not a copy**. `/etc/bluetooth/main.conf`
is a long file of distribution defaults and this desktop needs exactly two lines
of it changed, so the file here is the reasoning plus the two `sed` commands.
Copying the whole thing in would mean carrying every default bluez ever changes
and finding out about it through a `.pacnew`.

`snapper-root` is a recipe for the same reason and one more: `/etc/snapper/
configs/root` is `0640 root:root`, so it cannot be read without root, and a
`check` that needed sudo would not be a check. It is also not a file you write
by hand — `snapper -c root create-config /` creates it and `snapper -c root
set-config` edits it — so a copy would be the wrong shape even if it could be
read.

## What each one is for

| | |
|---|---|
| `default-grub` | `GRUB_TOP_LEVEL` puts mainline ahead of the LTS kernel, which `10_linux`'s name sort would otherwise reverse. `GRUB_DISABLE_OS_PROBER` is set explicitly so `grub-mkconfig` stops warning on every run |
| `fstab` | the data and game subvolumes, and the NTFS disk. Machine-specific — see above |
| `linux.preset` | vmlinuz + initramfs in `/boot` rather than a UKI in the ESP, because `/boot` lives inside `@` and therefore inside the btrfs snapshots |
| `linux-lts.preset` | the same, with **no fallback initramfs**: the LTS kernel already *is* the fallback, and its emergency image cost 318 MB in every snapshot |
| `mkinitcpio.conf` | NVIDIA loaded early through `MODULES`, and the `kms` hook deliberately removed — it autodetected nouveau plus ~100 MB of GSP firmware, and the Intel iGPU's i915/xe, none of which drive a monitor here |
| `modprobe-nvidia-gaming.conf` | KMS on, VRAM preserved across suspend, and a larger mapped-memory limit for games |
| `modules-load-ntsync.conf` | one word: `ntsync`. Wine's synchronisation primitives |
| `pacman.conf` | `[multilib]` on (Steam is a 32-bit binary), `ParallelDownloads`, `Color`, `CheckSpace` |
| `reflector.conf` | mirror selection by measured rate with **no country filter**, so a faster mirror across a border is not ruled out |
| `sddm-10-general.conf` | the greeter's theme and `XCURSOR_THEME`, which it does not inherit from anybody |
| `sddm-Xsetup` | the greeter's monitor layout — see above |
| `zram-generator.conf` | 16 GiB of zstd-compressed swap in RAM, on a machine with 31 GiB of it |
| `bluetooth-main.conf` | `FastConnectable` and `AutoEnable`, so a PS5 pad comes back on its own |
| `snapper-root` | the snapshot retention this machine keeps, as deltas from snapper's own template |

## Adding one

Two steps, and the second is the one to forget: put the file here, then add its
row to the table above. The `etc` unit walks this directory and reports anything
it finds that the table does not mention — the same shape `seeds/` uses, and for
the same reason.
