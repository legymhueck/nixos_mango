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
    inputs.hylki.packages.${pkgs.stdenv.hostPlatform.system}.default
    helix
    jetbrains-mono
    liberation_ttf
    micro
    opencode
    proton-pass
    proton-authenticator
    typst
    tinymist
    wl-clipboard
    vscode
  ];

  xdg.mimeApps.defaultApplications."x-scheme-handler/mailto" = [
    "co.hyprlab.Hylki.desktop"
  ];

  fonts.fontconfig.enable = true;

  # GTK3 on Wayland (LibreOffice gtk3 plugin) takes these from GSettings, not settings.ini
  dconf.settings."org/gnome/desktop/interface" = {
    cursor-theme = "Breeze_Red";
    cursor-size = 32;
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "breeze-dark";
    color-scheme = "prefer-dark";
  };

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

    settings = {
      exec_once = "noctalia";
      xkb_rules_layout = "de";
      mouse_accel_profile = 1;
      mouse_accel_speed = 0.1;

      animations = 0;
      layer_animations = 0;
      animation_fade_in = 0;
      animation_fade_out = 0;
      env = [
        "GTK_THEME,adw-gtk3-dark"
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "XCURSOR_THEME,Breeze_Red"
        "SAL_USE_VCLPLUGIN,gtk3"
      ];

      gap_inner_horizontal = 0;
      gap_inner_vertical = 0;
      gap_outer_horizontal = 0;
      gap_outer_vertical = 0;
      border_px = 1;
      border_radius = 0;
      no_radius_when_single = 1;
      focused_opacity = 1.0;
      unfocused_opacity = 1.0;
      scratchpad_width_ratio = 0.8;
      scratchpad_height_ratio = 0.9;
      root_color = "0x201b14ff";
      border_color = "0x444444ff";
      focus_color = "0x47add6ff";
      maximized_screen_color = "0x47add6ff";
      urgent_color = "0xad401fff";
      scratchpad_color = "0x516c93ff";
      global_color = "0xb153a7ff";
      overlay_color = "0x14a57cff";
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
      shadows_color = "0x00000000";
      animation_type_open = "zoom";
      animation_type_close = "zoom";
      tag_animation_direction = 0;
      zoom_initial_ratio = 1.0;
      zoom_end_ratio = 1.0;
      fade_in_begin_opacity = 1.0;
      fade_out_begin_opacity = 1.0;
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
      animation_curve_opacity_fade_out = "0.0, 0.0, 1.0, 1.0";
      animation_curve_opacity_fade_in = "0.0, 0.0, 1.0, 1.0";
      tag_rule = lib.genList (n: "id:${toString n}, layout_name:scroller") 9;
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
      default_master_factor = 0.55;
      default_master_count = 1;
      smart_gaps = 0;
      mousebind = [
        "SUPER,btn_left,moveresize,curmove"
        "NONE,btn_middle,togglemaximizescreen,0"
        "SUPER,btn_right,moveresize,curresize"
      ];
      windowrule = [ ];
      layer_rule = [ "no_animation:1, no_blur:1, layer_name:selection" ];
      allow_tearing = 2;
      sync_obj_enable = 1;
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
