# system

The part of this setup that lives outside `$HOME`, and therefore outside stow.

Nothing here is a symlink and nothing here is linked. `/etc` belongs to the
machine and to pacman — pacman writes `.pacnew` files beside anything it finds
edited, and a symlink into a git repository turns every one of those into a
question about which side is real. So these are **copies and recipes**.

**Nothing here is installed for you, nothing here is checked for you, and the
installer does not know this directory exists.** These files are documentation:
a written record of what this machine needs outside `$HOME`, kept in git so the
reasoning is somewhere other than one person's memory. Applying one is a person
reading the table below and running the command themselves:

```
sudo install -Dm 0644 ~/dotfiles/system/default-grub /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

**Half of these files are about one machine**: `fstab` names this box's UUIDs,
`default-grub` turns the OS prober off because there is no second operating
system on this disk, `modprobe-nvidia-gaming.conf` is for this card, and
`sddm-Xsetup` is where these screens sit. Installing this machine's `fstab` on another one does
not reproduce a setup; it produces a machine that will not boot. So the useful
thing to know about a row is what it is for, which is what this file is.

## There is no `etc` unit, and that is on purpose

There used to be one. It wrote these files with `sudo install -Dm` and then
offered to run `mkinitcpio -P` and `grub-mkconfig`, which made it the one part
of the installer that could leave a machine unable to boot and the only part a
container could not test — a container's `/etc` boots nobody, the initramfs
would be built for a kernel that is not running, and `grub-mkconfig` would
enumerate the runner's disks. So it was cut back to comparing and reporting.

The reporting half was dropped too, and for a different reason: **it is noise
everywhere.** Half of these files describe this one machine, so on any machine
they are compared against, most rows differ and always will. A row that reports
drift on every run, on every machine, and that no `apply` can ever turn green,
is not a finding — it is a line people learn to skip, sitting in a table whose
whole value is that every line in it means something.

Do not rebuild it. Nothing was overlooked here: the table stays because it is
worth reading, not because something is meant to be reading it.

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

**The table is for people.** Nothing parses it, so a file added to this
directory without a row here is a file whose reason nobody wrote down.

## The three kinds

**copy** — the file here is what should be at the destination. To see where the
machine stands, `diff` the two; to put it there, `sudo install -Dm <mode>`,
followed by `mkinitcpio -P` or `grub-mkconfig` where the file is an input to one
of those. Editing an input to a generator changes nothing until the generator
runs, which is the failure mode worth remembering: the file says what you meant
and the machine carries on as it was.

**reference** — the file here is a *record of what the machine has*, and must
not be installed anywhere else. There is exactly one, and it is `fstab`: **the
UUIDs in it belong to the original machine.** Installing it on another box gives
you a machine that does not boot. The only direction worth running for this
kind is the opposite one — `cp /etc/fstab ~/dotfiles/system/fstab`, catching the
record up with the machine, which is a change git can show you and undo.

**recipe** — not a copy at all, but a document describing edits to make to a
file that belongs to a package and is mostly left at its defaults. There is
nothing to diff; read the file here and run what it says.

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
configs/root` is `0640 root:root`, so it cannot even be read without root. It
is also not a file you write
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
row to the table above and a line to *What each one is for*. Nothing enforces
it, so a file with no row is a file whose reason is lost the week after it is
added — which is the whole thing this directory exists to prevent.
