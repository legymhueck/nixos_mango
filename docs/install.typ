// NixOS from the minimal ISO -- compile with: typst compile nixos-install-guide.typ
#set document(title: "NixOS from the minimal ISO")
#set page(paper: "a4", margin: (x: 1.9cm, y: 1.9cm), numbering: "1 / 1")
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

= NixOS in 60 seconds (for Arch users)

#block(breakable: false)[
#set text(size: 9pt)
#table(
  columns: (auto, 1fr), stroke: 0.4pt + luma(170), inset: 4.5pt,
  table.header([*Arch*], [*NixOS*]),
  [`pacman -Syu`], [`nix flake update`, then `sudo nixos-rebuild switch --flake .`],
  [`pacman -S foo`], [add `foo` to `environment.systemPackages` (system) or `home.packages` (user), rebuild],
  [`pacman -Rns foo`], [delete the line, rebuild; `sudo nix-collect-garbage -d` frees the store],
  [edit `/etc`, `systemctl enable`], [options: `services.*`, `programs.*`, `networking.*`. `/etc` is generated and read-only],
  [dotfiles in `~/.config`], [Home Manager: `programs.*`, `xdg.configFile`, `home.file`; rebuilt together with the system],
  [AUR, `makepkg`], [`nix search nixpkgs foo`; throw-away shell: `nix shell nixpkgs#foo`; run once: `nix run nixpkgs#foo`],
  [snapshots as rollback], [every rebuild is a generation: choose an old one in the boot menu or `sudo nixos-rebuild switch --rollback`],
  [FHS], [no `/usr/bin`, no `/lib`. Foreign prebuilt binaries need `programs.nix-ld.enable = true`],
  [lockfile?], [`flake.lock` pins every input. *A flake only sees git-tracked files* (`git add` new files)],
)
]

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
{
  description = "nixbox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # no "follows" here, otherwise the Cachix binary cache cannot be used
    noctalia.url = "github:noctalia-dev/noctalia";
  };

  outputs = { nixpkgs, home-manager, mango, ... }@inputs: {
    nixosConfigurations.nixbox = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        mango.nixosModules.mango
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "bak";
            extraSpecialArgs = { inherit inputs; };
            users.m = import ./home.nix;
          };
        }
      ];
    };
  };
}
```

#file("configuration.nix")
```nix
{ lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./mango-system.nix
  ];

  system.stateVersion = "26.05";   # use the value generated above, never bump it

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };
  nix.optimise.automatic = true;               # dedupe the store
  nixpkgs.config.allowUnfree = true;           # drop if you want free software only

  # --- boot, LUKS, Btrfs, zram ---
  boot.loader.systemd-boot = { enable = true; configurationLimit = 10; };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;           # needed: passes the passphrase to the session
  boot.initrd.luks.devices.cryptroot = {       # merged with the generated entry
    allowDiscards = true;                      # TRIM through LUKS (leaks which blocks are free)
    bypassWorkqueues = true;                   # faster on NVMe
  };

  fileSystems = lib.mkMerge [
    (lib.genAttrs [ "/" "/home" "/nix" "/var/log" ]
      (_: { options = [ "compress=zstd" "noatime" ]; }))   # merged with generated subvol=
    { "/var/log".neededForBoot = true; }
  ];
  services.btrfs.autoScrub.enable = true;
  services.fstrim.enable = true;

  swapDevices = [ { device = "/swapfile"; } ];   # created in the mount step; zram (prio 5) is used first, the file is overflow
  zramSwap = { enable = true; algorithm = "zstd"; memoryPercent = 50; };
  boot.kernel.sysctl = { "vm.swappiness" = 180; "vm.page-cluster" = 0; };   # zram tuning
  # (no hibernation without disk swap)

  # --- basics: English UI, German formats ---
  networking.hostName = "nixbox";
  networking.networkmanager.enable = true;     # Noctalia's Wi-Fi widget needs it
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = lib.genAttrs [
    "LC_ADDRESS" "LC_IDENTIFICATION" "LC_MEASUREMENT" "LC_MONETARY" "LC_NAME"
    "LC_NUMERIC" "LC_PAPER" "LC_TELEPHONE" "LC_TIME"
  ] (_: "de_DE.UTF-8");
  console.keyMap = "de-latin1";

  users.users.m = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
  };
  environment.systemPackages = with pkgs; [ git vim ];

  # --- desktop ---
  programs.mango.enable = true;                # session entry, portals, polkit, Xwayland
  services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };
  security.rtkit.enable = true;
  hardware.bluetooth.enable = true;            # Noctalia: Bluetooth,
  services.power-profiles-daemon.enable = true;#   power profile,
  services.upower.enable = true;               #   battery widgets
  environment.sessionVariables.NIXOS_OZONE_WL = "1";   # Electron/Chromium on Wayland
  fonts.packages = with pkgs; [ noto-fonts noto-fonts-color-emoji nerd-fonts.jetbrains-mono ];

  # --- auto-login (no display manager) + keyring unlocked by the LUKS passphrase ---
  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = { command = "mango"; user = "m"; };
      default_session = initial_session;       # after logout/crash: straight back in
    };
  };
  systemd.services.greetd.serviceConfig = { Type = "idle"; KeyringMode = lib.mkForce "inherit"; };
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  services.gnome.gnome-keyring.enable = true;  # Secret Service (Brave, Bitwarden, Ente Auth)
  # greetd's PAM service only includes "login", so enableGnomeKeyring does nothing there:
  # add both rules to greetd's own session stack. Order matters: inject the passphrase, then unlock.
  security.pam.services.greetd.rules.session = {
    fde_boot_pw = {
      order = 12600;
      control = "optional";
      modulePath = "${pkgs.pam_fde_boot_pw}/lib/security/pam_fde_boot_pw.so";
      args = [ "inject_for=gkr" ];
    };
    gnome_keyring = {
      order = 12700;
      control = "optional";
      modulePath = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
      args = [ "auto_start" ];
    };
  };
}
```

#file("home.nix")
```nix
{ lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.mango.hmModules.mango
    inputs.noctalia.homeModules.default
    ./mango-home.nix
  ];

  home.username = "m";
  home.homeDirectory = "/home/m";
  home.stateVersion = "26.05";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  programs.firefox.enable = true;

  home.packages = with pkgs; [
    (brave.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    })

    bitwarden-desktop
    ente-auth
    github-copilot-cli
    helix
    jetbrains-mono
    liberation_ttf
    mc
    micro
    opencode
    proton-pass
    proton-authenticator
    wl-clipboard
    udisks2
    starship
    vscode
  ];

  fonts.fontconfig.enable = true;

  programs.foot = {
    enable = true;

    settings = {
      main = {
        font = "JetBrains Mono NL:size=13";
      };
      scrollback.lines = 0;
    };
  };

  programs.noctalia = {
    enable = true;

    settings = {
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };

      shell.animation.enabled = false;
      lockscreen.transition = [ ];

      bar.default = {
        background_opacity = 1.0;
        center = [ "workspaces" "Spacer_2" "media" ];
        end = [
          "tray" "Spacer_2" "notifications" "clipboard" "recorder" "Spacer_2"
          "network" "bluetooth" "volume" "brightness" "battery" "Spacer_2"
          "date" "clock" "Spacer_2" "session" "Spacer"
        ];
        margin_edge = 0;
        margin_ends = 0;
        radius_bottom_left = 0;
        radius_bottom_right = 0;
        radius_top_left = 0;
        radius_top_right = 0;
        start = [ "Spacer" "launcher" "Spacer_2" "active_window" ];
        thickness = 40;
      };

      idle.behavior_order = [ "lock" "screen-off" "lock-and-suspend" ];
      idle.behavior.lock = {
        action = "lock";
        enabled = true;
        timeout = 600.0;
      };
      idle.behavior.screen-off = {
        action = "screen-off";
        enabled = true;
        timeout = 300.0;
      };
      idle.behavior.lock-and-suspend = {
        action = "suspend";
        enabled = true;
        lock_before_suspend = false;
        timeout = 900.0;
      };

      lockscreen_widgets = {
        enabled = false;
        schema_version = 2;
        widget_order = [ ];
        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };
      };

      plugin_settings."noctalia/screen_recorder".restore_portal = false;
      plugins = {
        enabled = [ "noctalia/screen_recorder" ];
        source = [
          {
            kind = "git";
            location = "https://github.com/noctalia-dev/official-plugins";
            name = "official";
          }
          {
            kind = "git";
            location = "https://github.com/noctalia-dev/community-plugins";
            name = "community";
          }
        ];
      };

      shell.polkit_agent = true;
      shell.settings_show_advanced = true;
      theme.templates.builtin_ids = [ "gtk3" "gtk4" "kcolorscheme" "qt" ];
      widget.Spacer = { length = 10; type = "spacer"; };
      widget.Spacer_2.type = "spacer";
      widget.date.format = "{:%a %d %b -}";
      widget.launcher.scale = 1.45;
      widget.network.show_label = false;
      widget.recorder.type = "noctalia/screen_recorder:recorder";
      widget.workspaces = { anchor = true; show_labels = false; };
    };
  };

  wayland.windowManager.mango = {
    enable = true;
    autostart_sh = "noctalia &";

    settings = {
      xkb_rules_layout = "de";
      mouse_accel_profile = 1;
      mouse_accel_speed = 0.1;

      animations = 0;
      layer_animations = 0;
      animation_fade_in = 0;
      animation_fade_out = 0;
      env = [
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "SAL_USE_VCLPLUGIN,gtk3"
      ];

      gappih = 0;
      gappiv = 0;
      gappoh = 0;
      gappov = 0;
      borderpx = 1;
      border_radius = 0;
      no_radius_when_single = 1;
      focused_opacity = 1.0;
      unfocused_opacity = 1.0;
      scratchpad_width_ratio = 0.8;
      scratchpad_height_ratio = 0.9;
      rootcolor = "0x201b14ff";
      bordercolor = "0x444444ff";
      focuscolor = "0x47add6ff";
      maximizescreencolor = "0x47add6ff";
      urgentcolor = "0xad401fff";
      scratchpadcolor = "0x516c93ff";
      globalcolor = "0xb153a7ff";
      overlaycolor = "0x14a57cff";
      cursor_theme = "Breeze_Red";
      cursor_size = 32;
      blur = 0;
      blur_layer = 0;
      blur_optimized = 1;
      blur_params_num_passes = 0;
      blur_params_radius = 0;
      blur_params_noise = 0.0;
      blur_params_brightness = 1.0;
      blur_params_contrast = 1.0;
      blur_params_saturation = 1.0;
      shadows = 0;
      layer_shadows = 0;
      shadow_only_floating = 0;
      shadows_size = 0;
      shadows_blur = 0;
      shadows_position_x = 0;
      shadows_position_y = 0;
      shadowscolor = "0x00000000";
      animation_type_open = "zoom";
      animation_type_close = "zoom";
      tag_animation_direction = 0;
      zoom_initial_ratio = 1.0;
      zoom_end_ratio = 1.0;
      fadein_begin_opacity = 1.0;
      fadeout_begin_opacity = 1.0;
      animation_duration_move = 0;
      animation_duration_open = 0;
      animation_duration_tag = 0;
      animation_duration_close = 0;
      animation_duration_focus = 0;
      animation_curve_open = "0.0, 0.0, 1.0, 1.0";
      animation_curve_move = "0.0, 0.0, 1.0, 1.0";
      animation_curve_tag = "0.0, 0.0, 1.0, 1.0";
      animation_curve_close = "0.0, 0.0, 1.0, 1.0";
      animation_curve_focus = "0.0, 0.0, 1.0, 1.0";
      animation_curve_opafadeout = "0.0, 0.0, 1.0, 1.0";
      animation_curve_opafadein = "0.0, 0.0, 1.0, 1.0";
      tagrule = lib.genList (n: "id:${toString n}, layout_name:scroller") 9;
      scroller_structs = 0;
      scroller_default_proportion = 1.0;
      scroller_focus_center = 0;
      scroller_prefer_center = 0;
      scroller_prefer_overspread = 1;
      edge_scroller_pointer_focus = 1;
      scroller_ignore_proportion_single = 0;
      scroller_default_proportion_single = 1.0;
      scroller_proportion_preset = "0.5, 0.8, 1.0";
      new_is_master = 1;
      default_mfact = 0.55;
      default_nmaster = 1;
      smartgaps = 0;
      mousebind = [
        "SUPER,btn_left,moveresize,curmove"
        "NONE,btn_middle,togglemaximizescreen,0"
        "SUPER,btn_right,moveresize,curresize"
      ];
      windowrule = [ ];
      layerrule = [ "noanim:1, noblur:1, layer_name:selection" ];
      allow_tearing = 2;
      syncobj_enable = 1;
      drag_tile_to_tile = 1;

      bind = [
        "SUPER,d,spawn,noctalia msg panel-toggle launcher"
        "SUPER,s,spawn,noctalia msg panel-toggle control-center"
        "SUPER+SHIFT,s,spawn,noctalia msg settings-toggle"
        "SUPER,comma,spawn,noctalia msg settings-toggle"
        "SUPER,Return,spawn,foot"
        "SUPER,e,spawn,nautilus"
        "SUPER,w,spawn,firefox"
        "SUPER+SHIFT,Return,spawn,doublecmd"
        "SUPER,q,killclient,"
        "SUPER+CTRL,q,quit"
        "SUPER+SHIFT,w,spawn,noctalia msg panel-toggle noctalia/wallhaven:browser"
        "SUPER+SHIFT,c,spawn,noctalia msg panel-toggle clipboard"
        "SUPER+SHIFT,q,spawn,noctalia msg panel-toggle session"
        "SUPER+SHIFT,b,spawn,noctalia msg bar-toggle"
        "SUPER,p,spawn,noctalia msg screenshot-region"
        "SUPER+SHIFT,p,spawn,noctalia msg screenshot-fullscreen"
        "SUPER+ALT,p,spawn,noctalia msg screenshot-fullscreen all"
        "SUPER,r,reload_config"
        "SUPER,g,toggleglobal,"
        "ALT,Tab,toggleoverview"
        "SUPER,v,togglefloating,"
        "SUPER+SHIFT,space,togglefloating,"
        "SUPER,c,centerwin"
        "SUPER,f,togglemaximizescreen"
        "SUPER+SHIFT,f,togglefullscreen"
        "SUPER+ALT,f,togglefakefullscreen"
        "SUPER,i,minimized"
        "SUPER,o,toggleoverlay"
        "SUPER+SHIFT,I,restore_minimized"
        "SUPER,z,toggle_scratchpad"
        "SUPER+SHIFT,e,set_proportion,1.0"
        "SUPER,x,set_proportion,0.5"
        "SUPER,n,switch_layout"
        "SUPER+ALT,s,setlayout,scroller"
        "SUPER,Tab,focusstack,next"
        "SUPER,Left,focusdir,left"
        "SUPER,Right,focusdir,right"
        "SUPER,Up,focusdir,up"
        "SUPER,Down,focusdir,down"
        "SUPER+SHIFT,Left,exchange_client,left"
        "SUPER+SHIFT,Right,exchange_client,right"
        "SUPER+SHIFT,Up,exchange_client,up"
        "SUPER+SHIFT,Down,exchange_client,down"
        "NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up"
        "NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down"
        "NONE,XF86AudioMute,spawn,noctalia msg volume-mute"
        "NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up"
        "NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down"
      ] ++ lib.concatMap (n:
        let k = toString n;
        in [
          "SUPER,${k},view,${k},0"
          "SUPER+SHIFT,${k},tag,${k},0"
        ]
      ) (lib.range 1 9);
    };
  };
}
```

#file("mango-home.nix")
```nix
{ config, lib, pkgs, ... }:

let
  scriptDir = ./mango/scripts/.local/share/scripts;
  archOnlyScripts = [
    "aur_check.sh"
    "fonts_uninstall.sh"
    "gsmartcontrol-wayland-fix.sh"
    "srcinfo-update.sh"
    "srcinfo_update.sh"
    "yay-build.sh"
    "yay_build.sh"
  ];
  userScripts = lib.filterAttrs
    (name: kind: kind == "regular" && !(builtins.elem name archOnlyScripts))
    (builtins.readDir scriptDir);
in
{
  home.packages = with pkgs; [
    adw-gtk3
    adwaita-icon-theme
    adwaita-qt
    alacritty
    alsa-oss
    audacity
    blanket
    btrfs-assistant
    cava
    celluloid
    cmatrix
    doublecmd
    dvdbackup
    fzf
    flameshot
    ghostty
    gimp
    gspell
    grim
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-ugly
    handbrake
    hunspell
    hunspellDicts.de_DE
    hunspellDicts.en_US
    hyphen
    hyphenDicts.de_DE
    hyphenDicts.en_US
    ispell
    inter
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.breeze-icons
    kdePackages.kdeconnect-kde
    kdePackages.kdenlive
    kdePackages.kdenetwork-filesharing
    kdePackages.kimageformats
    kdePackages.okular
    kdePackages.partitionmanager
    gtkspell3
    kitty
    libmypaint
    libreoffice
    librewolf
    meld
    mpv
    mplayer
    mypaint
    mypaint-brushes
    nautilus
    networkmanagerapplet
    nuspell
    nwg-look
    obsidian
    pavucontrol
    qt6Packages.qt6ct
    libsForQt5.qt5ct
    rofi
    scrcpy
    openconnect
    syncthing
    udiskie
    veracrypt
    vlc
    vorta
    wezterm
    zed-editor

    aspell
    aspellDicts.de
    aspellDicts.en
    bat
    btop
    eza
    fd
    fuzzel
    github-cli
    inetutils
    iperf3
    jdk
    khal
    less
    lsof
    p7zip
    pandoc
    ripgrep
    rsync
    sshfs
    tealdeer
    udisks2
    uv
    wget
    which
    unzip
    zip
    xwayland-satellite
    yt-dlp
    zoxide

    fira-code
    noto-fonts-color-emoji
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";
  home.sessionVariables.SAL_USE_VCLPLUGIN = "gtk3";

  home.file = {
    ".bash_profile".source = ./mango/home/.bash_profile;
    ".bashrc".source = ./mango/home/.bashrc;
    ".gitconfig".source = ./mango/home/.gitconfig;
    ".gitignore".source = ./mango/home/.gitignore;
    ".local/share/icons".source = ./mango/icons/.local/share/icons;
  } // lib.mapAttrs'
    (name: _: {
      name = ".local/share/scripts/${name}";
      value = {
        source = scriptDir + "/${name}";
        executable = lib.hasSuffix ".sh" name;
      };
    })
    userScripts;

  xdg.configFile = {
    "doublecmd/doublecmd.xml".source =
      ./mango/doublecmd/.config/doublecmd/doublecmd.xml;
    "gtk-3.0/gtk.css".source = ./mango/gtk-3.0/.config/gtk-3.0/gtk.css;
    "gtk-3.0/settings.ini".source = ./mango/gtk-3.0/.config/gtk-3.0/settings.ini;
    "gtk-4.0/gtk.css" = {
      source = ./mango/gtk-4.0/.config/gtk-4.0/gtk.css;
      force = true;
    };
    "gtk-4.0/settings.ini".source = ./mango/gtk-4.0/.config/gtk-4.0/settings.ini;
    "kitty/kitty.conf".source = ./mango/kitty/.config/kitty/kitty.conf;
    "kitty/dank-tabs.conf".source = ./mango/kitty/.config/kitty/dank-tabs.conf;
    "kitty/dank-theme.conf".source = ./mango/kitty/.config/kitty/dank-theme.conf;
    "mc/ini".source = ./mango/mc/.config/mc/ini;
    "mc/panels.ini".source = ./mango/mc/.config/mc/panels.ini;
    "qt5ct/qt5ct.conf".source = ./mango/qt5ct/.config/qt5ct/qt5ct.conf;
    "qt6ct/qt6ct.conf".source = ./mango/qt6ct/.config/qt6ct/qt6ct.conf;
    "starship.toml".source = ./mango/config/.config/starship.toml;
    "user-dirs.locale".source = ./mango/config/.config/user-dirs.locale;
    "xdg-desktop-portal/mango-portals.conf".source =
      ./mango/config/.config/xdg-desktop-portal/mango-portals.conf;
  };

  xdg.userDirs = {
    desktop = "${config.home.homeDirectory}/Desktop";
    download = "${config.home.homeDirectory}/Downloads";
    templates = "${config.home.homeDirectory}/Templates";
    publicShare = "${config.home.homeDirectory}/Public";
    documents = "${config.home.homeDirectory}/Documents";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
    extraConfig.XDG_PROJECTS_DIR = "$HOME/Projects";
  };

  home.activation.createProjectsDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/Projects"
  '';
}
```

#file("mango-home.nix")
```nix
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    acpi
    alsa-firmware
    alsa-oss
    alsa-utils
    asciidoc
    asciidoctor
    bash-completion
    bind
    bluez
    bolt
    brightnessctl
    btrfs-progs
    compsize
    cups
    cups-pk-helper
    ddcutil
    dosfstools
    exfatprogs
    fail2ban
    fprintd
    fwupd
    i2c-tools
    inetutils
    intel-gpu-tools
    intel-media-driver
    jq
    man-db
    man-pages
    mesa
    nfs-utils
    nftables
    ntfs3g
    openssh
    rtkit
    smartmontools
    sof-firmware
    strace
    tpm2-tools
    traceroute
    usbutils
    vulkan-tools
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xdg-utils
    xwayland
    (runCommand "breeze-red-cursor-theme" { } ''
      mkdir -p "$out/share/icons"
      ln -s ${./mango/icons/.local/share/icons/Breeze_Red} \
        "$out/share/icons/Breeze_Red"
      ln -s ${./mango/icons/.local/share/icons/default} \
        "$out/share/icons/default"
    '')
  ];

  services.printing.enable = true;
  services.fprintd.enable = true;
  services.fwupd.enable = true;
  services.tailscale.enable = true;

  hardware.firmware = [ pkgs.sof-firmware ];

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
  };
}
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
