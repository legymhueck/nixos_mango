// NixOS from the minimal ISO -- compile with: typst compile nixos-install-guide.typ
#set document(title: "NixOS from the minimal ISO")
#set page(paper: "a4", margin: (x: 1.6cm, y: 1.6cm), numbering: "1 / 1")
#set text(size: 10pt, lang: "en")
#set par(justify: false, leading: 0.6em)
#set heading(numbering: "1.")
#show heading.where(level: 1): set text(size: 13pt)
#show heading.where(level: 1): set block(above: 1.3em, below: 0.7em)
#show raw: set text(font: ("DejaVu Sans Mono", "Liberation Mono"), size: 8pt)
#show raw.where(block: true): it => block(
  width: 100%, fill: luma(245), stroke: 0.5pt + luma(190),
  inset: 6pt, radius: 2pt, above: 0.6em, below: 0.8em, it,
)

#let note(body) = block(
  width: 100%, inset: 7pt, fill: rgb("#f1f5fa"),
  stroke: (left: 2pt + rgb("#3b6ea8")), above: 0.6em, below: 0.8em,
  [*Note.* #body],
)
#let warn(body) = block(
  width: 100%, inset: 7pt, fill: rgb("#fbf1f0"),
  stroke: (left: 2pt + rgb("#b3372d")), above: 0.6em, below: 0.8em,
  [*Careful.* #body],
)
#let file(name) = block(above: 0.8em, below: 0pt, sticky: true,
  text(font: "DejaVu Sans Mono", size: 8.5pt, weight: "bold", name))

#align(center)[
  #text(19pt, weight: "bold")[NixOS from the minimal ISO]
  #v(-2pt)
  #text(9.5pt)[UEFI · GPT · LUKS2 · Btrfs (zstd) · 8 GB swap file + zram · flakes · Home Manager · MangoWM · Noctalia]
]
#v(4pt)

*Assumptions.* x86_64, UEFI, the whole disk gets wiped. Placeholders to replace:
disk `/dev/nvme0n1`, hostname `nixbox`, user `m`, time zone, keyboard layout.
The ISO is the current stable minimal ISO; the system tracks `nixos-unstable`
(rolling, like Arch). Everything lives in one git-tracked flake.
*One passphrase:* the LUKS passphrase is typed at boot, then the system logs in automatically and
unlocks the keyring with that same passphrase. Use *the same string* as login password for `m`.

= Optional: SSH into the live ISO

The NixOS installer ISO runs `sshd` by default, and its firewall opens SSH port 22 automatically. No separate enable or firewall command is normally needed. First connect the ISO to your network (wired Ethernet or `nmtui` for Wi-Fi), then on its console set a temporary root password and find its address:

```sh
sudo -i
passwd                       # set a temporary root password for this live session
ip -brief address            # note the ISO's LAN address
systemctl is-active sshd || systemctl start sshd  # start it only if it is not already active
```

From another computer on the same network, connect using that address:

```sh
ssh root@192.168.1.42        # replace with the address shown above
```

Accept the host key on first connection and enter the temporary root password. The password is only for the live ISO;
it does not set the installed system's password. In the SSH session, continue with the commands below and omit `sudo -i`.

= Boot the installer and get online

```sh
sudo -i                     # root shell (live ISO: no password)
loadkeys de-latin1          # optional: console keymap
ls /sys/firmware/efi        # must exist, otherwise you booted in BIOS mode
nmtui                       # Wi-Fi (wpa_cli if the ISO ships wpa_supplicant); wired just works
ping -c1 nixos.org
```

Enable flakes and the Noctalia binary cache for the installer (otherwise Noctalia is compiled locally, which is slow and RAM-hungry).
Use a config file; a multi-line `NIX_CONFIG` variable breaks if the line breaks get lost while copying.

```sh
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
extra-substituters = https://noctalia.cachix.org
extra-trusted-public-keys = noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=
EOF
nix config show | grep -E 'substituters|trusted-public|experimental'   # must list noctalia
```

= Partition, encrypt, format

```sh
DISK=/dev/nvme0n1                      # check with lsblk
wipefs -af $DISK
parted -s $DISK -- mklabel gpt
parted -s $DISK -- mkpart ESP fat32 1MiB 1GiB
parted -s $DISK -- set 1 esp on
parted -s $DISK -- mkpart nixos 1GiB 100%
udevadm settle

mkfs.fat -F 32 -n BOOT /dev/disk/by-partlabel/ESP
cryptsetup luksFormat /dev/disk/by-partlabel/nixos      # type YES, choose the passphrase
cryptsetup open /dev/disk/by-partlabel/nixos cryptroot  # name must stay "cryptroot"
mkfs.btrfs -L nixos /dev/mapper/cryptroot
```

#note[Only `/boot` (kernel, initrd) stays unencrypted; systemd-boot cannot unlock disks, the initrd asks for the passphrase.]

== Btrfs subvolumes and mounts

`@nix` is separate so root snapshots do not contain the store; `@log` survives a root rollback.

```sh
M=/dev/mapper/cryptroot
mount $M /mnt
for s in @ @home @nix @log; do btrfs subvolume create /mnt/$s; done
umount /mnt

O=compress=zstd,noatime
mount -o $O,subvol=@ $M /mnt
mkdir -p /mnt/{boot,home,nix,var/log}
mount -o $O,subvol=@home $M /mnt/home
mount -o $O,subvol=@nix  $M /mnt/nix
mount -o $O,subvol=@log  $M /mnt/var/log
mount -o umask=0077 /dev/disk/by-label/BOOT /mnt/boot
findmnt -R /mnt                         # sanity check
```

Create a Btrfs-compatible 8 GB swap file on the root subvolume and enable it now, plus temporary zram on top. The live ISO has
neither, and its own store (`/nix/.rw-store`) is a RAM-backed tmpfs, so evaluating the flake and building can fill 8 GB of RAM:

```sh
btrfs filesystem mkswapfile --size 8g /mnt/swapfile
swapon /mnt/swapfile
modprobe zram
Z=$(zramctl -f -s 4G -a zstd) && mkswap "$Z" && swapon -p 100 "$Z"   # compressed RAM first, the file is overflow
swapon --show                           # swap file and zram must both be listed
free -h
```

= Generate the config and write the flake

```sh
nixos-generate-config --root /mnt
cd /mnt/etc/nixos
grep stateVersion configuration.nix     # remember this value, you need it below
```

`hardware-configuration.nix` is the only generated file you keep; check that it lists the four subvolumes, `/boot`
and `boot.initrd.luks.devices."cryptroot"`.
Layout: `flake.nix`, `configuration.nix` (system), `home.nix` (user), `hardware-configuration.nix`.
Replace `configuration.nix` with the file below (`nano configuration.nix`).

#file("flake.nix")
```nix
{flake.nix}
```

#file("home.nix")
```nix
{home.nix}
```

#file("mango-home.nix")
```nix
{mango-home.nix}
```

#file("mango-system.nix")
```nix
{mango-home.nix}
```

#note[Mango reads `~/.config/mango/config.conf` *instead of* its shipped example, so every bind you do not list does not exist.
The module validates the generated file at build time; a typo fails the rebuild, not your login.]

= Login, keyring, password managers

*How it works.* The initrd asks for the LUKS passphrase and keeps it in the kernel keyring. greetd logs `m` in without
asking (`initial_session`), and a PAM session rule (`pam_fde_boot_pw`) hands that passphrase to gnome-keyring, which uses it as
the password of the `login` keyring (created on first login). Brave, Bitwarden Desktop and Ente Auth store their secrets there,
so they never prompt. Firefox, the browser extensions and the two Proton apps need nothing from it.

*Rules.* LUKS passphrase = login password of `m` (also used by `sudo` and the Noctalia lock screen, which authenticates via the
PAM service `login`). Do not set an empty user password. If you change the password later, the keyring keeps the old one.

*Test after the first login* (should print `b false`):

```sh
busctl --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login \
  org.freedesktop.Secret.Collection Locked
```

#warn[This PAM trick is community-documented (NixOS Discourse, jdw.codeberg.page), not part of NixOS itself. The config evaluates and the PAM stack has the right order (inject passphrase, then unlock keyring), but it has not been run on hardware.
If Brave or Ente Auth ask for a keyring password, use the fallback: run `nix shell nixpkgs#seahorse -c seahorse`, create a keyring
named _Login_ with an *empty* password and make it the default. At rest it is then unencrypted inside your home directory,
which sits on the LUKS volume anyway. If a wrong keyring already exists, delete `~/.local/share/keyrings/login.keyring` and log in again.]

= Install

```sh
cd /mnt/etc/nixos
git init && git add -A                   # flakes ignore untracked files
swapon --show                            # swap file and zram still active?
nixos-install --flake /mnt/etc/nixos#nixbox --no-root-passwd --max-jobs 1 --cores 2
nixos-enter --root /mnt -c 'passwd m'    # same string as the LUKS passphrase
reboot                                   # remove the USB stick
```

`--max-jobs 1 --cores 2` limits parallel compilation (RAM per compiler job); downloads from the caches are not affected.

Boot: type the LUKS passphrase, Mango starts by itself. Noctalia starts from the autostart script;
`SUPER + d` opens its launcher, `SUPER + Return` a terminal. Then run the keyring test above.

= After the first boot

Flakes do not read `/etc/nixos`, so move the repo where you want it (and put it on a remote):

```sh
sudo mv /etc/nixos ~/nixos && sudo chown -R "$USER": ~/nixos
cd ~/nixos && git add -A && git commit -m "initial system"
sudo nixos-rebuild switch --flake .          # picks the nixbox entry via the hostname
```

#table(
  columns: (auto, 1fr), stroke: 0.4pt + luma(170), inset: 4.5pt,
  [*Task*], [*Command*],
  [apply changes (system and Home Manager)], [`sudo nixos-rebuild switch --flake .`, then `SUPER + r` to reload Mango],
  [try without a boot entry], [`sudo nixos-rebuild test --flake .`],
  [update everything], [`nix flake update && sudo nixos-rebuild switch --flake .`],
  [update one input only], [`nix flake update noctalia`],
  [generations / rollback], [`nixos-rebuild list-generations`, `sudo nixos-rebuild switch --rollback`],
  [find an option], [search.nixos.org (options) and Home Manager option search; `man configuration.nix`],
)

= If something breaks

#set text(size: 9.5pt)
- *Warnings "unknown experimental feature '='", "...'extra-substituters'":* the config lines were joined into one. Redo the `nix.conf` step above (`unset NIX_CONFIG` first) and check with `nix config show`.
- *Installer freezes or the screen stops (RAM full):* look at `swapon --show` and `free -h` from a second TTY or over SSH. If needed, hard-reset, then redo `cryptsetup open`, the mounts and both `swapon` steps in the swap section; whatever was already downloaded or built stays in `/mnt/nix/store`, so the retry resumes.
- *"path ... is not tracked by Git"* or a file seems ignored: `git add` it.
- *Passphrase asked twice or no auto-login:* `boot.initrd.systemd.enable` must be on; check `journalctl -u greetd -b`.
- *Black screen or back at the same screen:* greetd restarts the session; switch to a TTY (Ctrl+Alt+F2), run `mango` to read its output; `journalctl --user -b` for the rest.
- *No bar:* run `noctalia` in a terminal and read the error. A Noctalia config error is also caught at build time.
- *Noctalia compiles for ages:* the Cachix key is missing or the input has `follows`; check `nix.settings` above.
- *Option names used here:* `programs.mango`, `wayland.windowManager.mango`, `programs.noctalia`. Noctalia v5 (this guide) is the native rewrite; the old Quickshell version (`noctalia-shell`) is different.

#v(1fr)
#text(8pt, fill: luma(90))[Sources: docs.noctalia.dev (NixOS, Mango, IPC, FAQ); mangowm/mango `nix/` modules; Home Manager manual; wiki.nixos.org (Mango, Greetd); NixOS Discourse thread "Automatically unlocking the gnome-keyring using LUKS key with greetd"; jdw.codeberg.page/blog/nixos-automatic-login.]
