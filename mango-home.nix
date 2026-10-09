{ config, lib, pkgs, ... }:

let
  doublecmdQt5 = pkgs.doublecmd.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postFixup = (oldAttrs.postFixup or "") + ''
      wrapProgram $out/bin/doublecmd \
        --set QT_QPA_PLATFORMTHEME qt5ct
    '';
  });
  scriptDir = ./dotfiles/scripts/.local/share/scripts;
  userScripts = lib.filterAttrs
    (name: kind: kind == "regular")
    (builtins.readDir scriptDir);
in
{
  home.packages = with pkgs; [
    adw-gtk3
    adwaita-icon-theme
    adwaita-qt
    alacritty
    alsa-oss
    aspell
    aspellDicts.de
    aspellDicts.en
    audacity
    bat
    blanket
    btop
    btrfs-assistant
    cava
    celluloid
    cmatrix
    doublecmd
    dvdbackup
    eza
    fd
    fira-code
    flameshot
    fzf
    ghostty
    gimp
    github-cli
    grim
    gspell
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-ugly
    gtkspell3
    handbrake
    hunspell
    hunspellDicts.de_DE
    hunspellDicts.en_GB-large
    hunspellDicts.en_US
    hyphen
    hyphenDicts.de_DE
    hyphenDicts.en_GB
    hyphenDicts.en_US
    inetutils
    inter
    iperf3
    ispell
    jdk
    kdePackages.breeze-icons
    kdePackages.dolphin
    kdePackages.dolphin-plugins
    kdePackages.kdeconnect-kde
    kdePackages.kdenetwork-filesharing
    kdePackages.kdenlive
    kdePackages.kimageformats
    kdePackages.okular
    kdePackages.partitionmanager
    khal
    kitty
    less
    libmypaint
    libreoffice
    librewolf
    libsForQt5.qt5ct
    lsof
    meld
    mplayer
    mpv
    mypaint
    mypaint-brushes
    nautilus
    networkmanagerapplet
    noto-fonts-color-emoji
    nuspell
    nwg-look
    obsidian
    openconnect
    p7zip
    pandoc
    pavucontrol
    python3
    qt6Packages.qt6ct
    ripgrep
    rofi
    rsync
    scrcpy
    sshfs
    starship
    syncthing
    tealdeer
    udiskie
    udisks2
    unzip
    uv
    veracrypt
    vlc
    vorta
    wezterm
    wget
    which
    xwayland-satellite
    yt-dlp
    zed-editor
    zip
    zoxide
  ];

  fonts.fontconfig.enable = true;

  home.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";
  home.sessionVariables.XCURSOR_THEME = "Breeze_Red";
  home.sessionVariables.SAL_USE_VCLPLUGIN = "gtk3";
  home.sessionVariables.GTK_THEME = "adw-gtk3-dark";

  home.file = {
    ".bash_profile".source = ./dotfiles/home/.bash_profile;
    ".bashrc".source = ./dotfiles/home/.bashrc;
    ".gitconfig".source = ./dotfiles/home/.gitconfig;
    ".gitignore".source = ./dotfiles/home/.gitignore;
    ".local/share/icons".source = ./dotfiles/icons/.local/share/icons;
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
      ./dotfiles/doublecmd/.config/doublecmd/doublecmd.xml;
    "gtk-3.0/gtk.css".source = ./dotfiles/gtk-3.0/.config/gtk-3.0/gtk.css;
    "gtk-3.0/settings.ini".source = ./dotfiles/gtk-3.0/.config/gtk-3.0/settings.ini;
    "gtk-4.0/gtk.css" = {
      source = ./dotfiles/gtk-4.0/.config/gtk-4.0/gtk.css;
      force = true;
    };
    "gtk-4.0/settings.ini".source = ./dotfiles/gtk-4.0/.config/gtk-4.0/settings.ini;
    "kitty/kitty.conf".source = ./dotfiles/kitty/.config/kitty/kitty.conf;
    "kitty/dank-tabs.conf".source = ./dotfiles/kitty/.config/kitty/dank-tabs.conf;
    "kitty/dank-theme.conf".source = ./dotfiles/kitty/.config/kitty/dank-theme.conf;
    "mc/ini".source = ./dotfiles/mc/.config/mc/ini;
    "mc/panels.ini".source = ./dotfiles/mc/.config/mc/panels.ini;
    "qt5ct/qt5ct.conf".source = ./dotfiles/qt5ct/.config/qt5ct/qt5ct.conf;
    "qt5ct/colors/noctalia.conf".source =
      ./dotfiles/qt5ct/.config/qt5ct/colors/noctalia.conf;
    "qt6ct/qt6ct.conf".source = ./dotfiles/qt6ct/.config/qt6ct/qt6ct.conf;
    "starship.toml".source = ./dotfiles/config/.config/starship.toml;
    "user-dirs.locale".source = ./dotfiles/config/.config/user-dirs.locale;
    "xdg-desktop-portal/mango-portals.conf".source =
      ./dotfiles/config/.config/xdg-desktop-portal/mango-portals.conf;
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
