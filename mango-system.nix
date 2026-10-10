{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    acpi
    alsa-firmware
    alsa-oss
    alsa-utils
    asciidoc
    asciidoctor
    adw-gtk3
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
    (runCommand "custom-cursor-themes" { } ''
      mkdir -p "$out/share/icons"
      for theme in Breeze_Red default; do
        ln -s ${./dotfiles/icons/.local/share/icons}/"$theme" \
          "$out/share/icons/$theme"
      done
    '')
  ];

  services.printing.enable = true;
  services.fprintd.enable = true;
  services.fwupd.enable = true;
  services.hardware.bolt.enable = true;
  services.udisks2.enable = true;
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
