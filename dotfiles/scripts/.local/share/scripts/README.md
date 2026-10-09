# Scripts directory

Conventions used here:

- Canonical script and helper filenames use `kebab-case` where practical.
- Older `snake_case` or mixed-case shell script names are kept as compatibility wrappers.

If you are calling scripts manually, prefer the canonical names, for example:

- `add-to-i2c-group.sh`
- `antigravity-to-path.sh`
- `create-luks-container.sh`
- `create-ssh-key.sh`
- `diskstation-mount.sh`
- `firefox-bitwarden.sh`
- `firefox-ublock-origin.sh`
- `format-and-mount.sh`
- `git-init.sh`
- `localsend-open-port.sh`
- `mount-128.sh`
- `nfs-mount.sh`
- `ssh-permissions.sh`
- `ufw-libvirt.sh`
- `umount-128.sh`
- `yubikey-enroll.sh`
- `ssh-ready.ps1`
- `tpm-key-change.adoc`

Home Manager installs this directory's regular files into
`~/.local/share/scripts`. Apply changes with
`sudo nixos-rebuild switch --flake .#nixbox` from the repository root.
