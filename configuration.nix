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
  environment.systemPackages = with pkgs; [ git vim vlc ffmpeg ];

  # --- desktop ---
  programs.mango.enable = true;                # session entry, portals, polkit, Xwayland
  programs.dconf.enable = true;                # GSettings backend (GTK3 on Wayland reads cursor/theme from here)
  services.pipewire = { enable = true; alsa.enable = true; pulse.enable = true; };
  security.rtkit.enable = true;
  hardware.bluetooth.enable = true;            # Noctalia: Bluetooth,
  services.power-profiles-daemon.enable = true;#   power profile,
  services.upower.enable = true;               #   battery widgets
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";   # Electron/Chromium on Wayland
    XCURSOR_THEME = "Breeze_Red";
    XCURSOR_PATH = [ "/run/current-system/sw/share/icons" ];
  };
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
