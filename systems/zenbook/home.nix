{
  pkgs,
  lib,
  config,
  ...
}:

let

  iab =
    (builtins.getFlake "github:jeffutter/iio_ambient_brightness/v0.2.15")
    .packages.${pkgs.system}.default;

  zenbrowser =
    (builtins.getFlake "github:0xc000022070/zen-browser-flake").packages.${pkgs.system}.default;

  my_zoom = pkgs.symlinkJoin {
    name = "zoom-us";
    paths = [ pkgs.zoom-us ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zoom --set QT_XCB_GL_INTEGRATION xcb_egl
    '';
  };

  my_bemoji = pkgs.symlinkJoin {
    name = "bemoji";
    paths = [ pkgs.bemoji ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/bemoji --prefix PATH : ${
        lib.makeBinPath [
          pkgs.wtype
        ]
      }
    '';
  };

  my_todoist = pkgs.symlinkJoin {
    name = "todist-electron";
    paths = [ pkgs.todoist-electron ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/todoist-electron --add-flags '--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true'
    '';
  };
in
{
  imports = [ ../common.nix ];

  home.packages = with pkgs; [
    _1password-cli
    _1password-gui
    blueberry
    brave
    brightnessctl
    cargo-watch
    clang
    discord
    gnome-power-manager
    iab
    mako
    my_zoom
    obsidian
    pavucontrol
    slurp
    my_todoist
    wayshot
    wl-clipboard
    wlsunset
    wofi
    wluma
    zenbrowser
  ];

  programs.ghostty = {
    enable = true;
  };

  programs.git.userEmail = "jeff@jeffutter.com";

  programs.zsh.oh-my-zsh.plugins = [
    "git"
    "mosh"
    "kubectl"
    "vi-mode"
    "tmux"
    "1password"
    "debian"
  ];

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_ed25519";

  # programs.eww = {
  #   enable = true;
  #   enableFishIntegration = true;
  #   enableZshIntegration = true;
  # };

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        style = ''
          * {
            font-family: "MonaspiceNe Nerd Font", Font Awesome 6 Free Solid;
          }
        '';
        layer = "top";
        position = "bottom";
        height = 25;
        modules-left = [
          "hyprland/workspaces"
          "sway/mode"
        ];
        modules-center = [
        ];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "battery"
          "tray"
          "clock"
        ];
        "hyprland/workspaces" = {
          format = "{name}";
          format-icons = {
            active = "";
            default = "o";
            persistent = "";
          };
          on-scroll-up = "${pkgs.hyprland}/bin/hyprctl dispatch workspace r-1";
          on-scroll-down = "${pkgs.hyprland}/bin/hyprctl dispatch workspace r+1";
          all-outputs = false;
          persistent_workspaces = {
            "*" = 5;
          };
        };
        "sway/mode" = {
          "format" = "<span style=\"italic\">{}</span>";
        };
        tray = {
          # icon-size= 21;
          spacing = 10;
        };
        clock = {
          format-alt = "{=%Y-%m-%d}";
        };
        cpu = {
          format = "{icon} {usage}%";
        };
        memory = {
          format = "{icon} {}%";
        };
        battery = {
          bat = "BAT0";
          states = {
            # // good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          # format-good= "";
          # format-full= "";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
        };
        network = {
          # interface = "wlp2s0";
          format-wifi = "{icon} {essid} ({signalStrength}%)";
          format-ethernet = "{icon} {ifname}= {ipaddr}/{cidr} ";
          format-disconnected = "{icon} Disconnected ⚠";
        };
        pulseaudio = {
          scroll-step = 5;
          format = "{icon} {volume}%";
          format-bluetooth = "{icon} {volume}%";
          format-muted = "";
          format-icons = {
            headphones = "";
            handsfree = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [
              ""
              ""
            ];
          };
          on-click = "pavucontrol";
        };
      };
    };
  };

  home.file."wallpapers/hyprlock.jpg".source = ../../wallpapers/3977823.jpg;

  programs.hyprlock = {
    enable = true;
    settings = {
      background = {
        monitor = "";
        path = "~/wallpapers/hyprlock.jpg";
        blur_passes = 0;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };

      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        ignore_empty_input = false;
        no_fade_in = false;
        no_fade_out = false;
      };

      input-field = [
        {
          monitor = "";
          size = "200, 50";
          position = "0, -80";
          outline_thickness = 5;
          dots_center = true;
          outer_color = "rgb(24, 25, 38)";
          inner_color = "rgb(91, 96, 120)";
          font_color = "rgb(202, 211, 245)";
          fade_on_empty = false;
          placeholder_text = ''<span foreground="##cad3f5">Password...</span>'';
          shadow_passes = 2;
          bothlock_color = -1;
          capslock_color = "-1";
          check_color = "rgb(204, 136, 34)";
          dots_rounding = "-1";
          dots_size = "0.330000";
          dots_spacing = "0.150000";
          fade_timeout = "2000";
          fail_color = "rgb(204, 34, 34)";
          fail_text = "<i>$FAIL</i>";
          fail_transition = 300;
          halign = "center";
          hide_input = false;
          invert_numlock = false;
          numlock_color = -1;
          rounding = -1;
          shadow_boost = "1.200000";
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_size = 3;
          swap_font_color = false;
          valign = "center";
        }
      ];

      # image = [
      #   {
      #     monitor = "";
      #     size = 120;
      #     position = "0, 45";
      #     path = "/home/$USER/.face";
      #     border_color = "rgb(202, 211, 245)";
      #     border_size = 5;
      #     halign = "center";
      #     valign = "center";
      #     shadow_passes = 1;
      #     reload_cmd = "";
      #     reload_time = -1;
      #     rotate = "0.000000";
      #     rounding = "-1";
      #   }
      # ];

      label = [
        {
          monitor = "";
          text = ''<span font_weight="ultrabold">$TIME</span>'';
          color = "rgb(202, 211, 245)";
          font_size = 100;
          font_family = "MonaspiceNe Nerd Font";
          valign = "center";
          halign = "center";
          position = "0, 330";
          shadow_passes = 2;
          rotate = "0.000000";
          shadow_boost = "1.200000";
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_size = 3;
        }
        {
          monitor = "";
          text = ''<span font_weight="bold"> $USER</span>'';
          color = "rgb(202, 211, 245)";
          font_size = 25;
          font_family = "MonaspiceNe Nerd Font";
          valign = "top";
          halign = "left";
          position = "10, 0";
          rotate = "0.000000";
          shadow_boost = "1.200000";
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_size = 3;
          shadow_passes = 1;
        }
        {
          monitor = "";
          text = ''<span font_weight="ultrabold">󰌾 </span>'';
          color = "rgb(202, 211, 245)";
          font_size = 50;
          font_family = "MonaspiceNe Nerd Font";
          valign = "center";
          halign = "center";
          position = "15, -350";
          rotate = "0.000000";
          shadow_boost = "1.200000";
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_size = 3;
          shadow_passes = 1;
        }
        {
          monitor = "";
          text = ''<span font_weight="bold">Locked</span>'';
          color = "rgb(202, 211, 245)";
          font_size = 25;
          font_family = "MonaspiceNe Nerd Font";
          valign = "center";
          halign = "center";
          position = "0, -430";
          rotate = "0.000000";
          shadow_boost = "1.200000";
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_size = 3;
          shadow_passes = 1;
        }
        {
          monitor = "";
          text = "cmd[update:120000] echo \"<span font_weight='bold'>$(${pkgs.coreutils}/bin/date +'%a %d %B')</span>\"";
          color = "rgb(202, 211, 245)";
          font_size = 30;
          font_family = "MonaspiceNe Nerd Font";
          valign = "center";
          halign = "center";
          position = "0, 210";
          rotate = "0.000000";
          shadow_boost = "1.200000";
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_size = 3;
          shadow_passes = 1;
        }
        {
          monitor = "";
          text = ''<span font_weight="ultrabold"> </span>'';
          color = "rgb(202, 211, 245)";
          font_size = 25;
          font_family = "MonaspiceNe Nerd Font";
          valign = "bottom";
          halign = "right";
          position = "5, 8";
          rotate = "0.000000";
          shadow_boost = "1.200000";
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_size = 3;
          shadow_passes = 1;
        }
      ];
    };
  };

  programs.ghostty.settings.font-size = 10;

  programs.swaylock = {
    enable = true;
    # nix swaylock doesn't play well with ubuntu pam
    # package = pkgs.runCommandLocal "empty" { } "mkdir $out";
    settings = {
      color = "000000";
      daemonize = true;
      font = "MonaspiceNe Nerd Font";
      # font-size = 50;
      ignore-empty-password = true;
      indicator-caps-lock = true;
      indicator-idle-visible = true;
      indicator-radius = 200;
      indicator-thickness = 20;
      inside-color = "00000033";
      inside-clear-color = "ffffff00";
      inside-caps-lock-color = "ffffff00";
      inside-ver-color = "ffffff00";
      inside-wrong-color = "ffffff00";
      key-hl-color = "00000066";
      layout-text-color = "d8dee9ff";
      ring-color = "ffffff";
      ring-clear-color = "ffffffFF";
      ring-caps-lock-color = "ffffffFF";
      ring-ver-color = "ffffffFF";
      ring-wrong-color = "ffffffFF";
      line-color = "00000000";
      line-clear-color = "ffffffFF";
      line-caps-lock-color = "ffffffFF";
      line-ver-color = "ffffffFF";
      line-wrong-color = "ffffffFF";
      separator-color = "00000000";
      show-failed-attempts = true;
      text-color = "ffffff";
      text-clear-color = "ffffff";
      text-ver-color = "ffffff";
      text-wrong-color = "ffffff";
      bs-hl-color = "ffffff";
      caps-lock-key-hl-color = "ffffffFF";
      caps-lock-bs-hl-color = "ffffffFF";
      # disable-caps-lock-text=true;
      text-caps-lock-color = "ffffff";
    };
  };

  programs.i3status-rust = {
    enable = true;
    bars = {
      default = {
        icons = "material-nf";
        blocks = [
          {
            block = "net";
            device = "wlo1";
            format = " $icon {$signal_strength $ssid} ^icon_net_down $speed_down.eng(prefix:K) ^icon_net_up $speed_up.eng(prefix:K) ";
          }
          {
            block = "net";
            device = "tailscale0";
            format = " $icon ^icon_net_down $speed_down.eng(prefix:K) ^icon_net_up $speed_up.eng(prefix:K) ";
          }
          {
            alert = 10.0;
            block = "disk_space";
            info_type = "available";
            interval = 60;
            path = "/";
            warning = 20.0;
          }
          {
            block = "memory";
            format = " $icon $mem_used_percents ";
            format_alt = " $icon $swap_used_percents ";
          }
          {
            block = "cpu";
            interval = 1;
          }
          {
            block = "sound";
          }
          { block = "backlight"; }
          # { block = "hueshift"; }
          { block = "battery"; }
          {
            block = "time";
            format = " $timestamp.datetime(f:'%a %m/%d %I:%M %p') ";
            interval = 60;
          }
        ];
      };
    };
  };

  wayland = {
    windowManager.hyprland = {
      enable = true;
      settings = {
        animation = [
          "workspaces,1,4,default,fade"
          "windows,1,4,default,popin"
        ];
        monitor = ",preferred,auto,auto";
        exec-once = [
          "${pkgs.waybar}/bin/waybar"
          "${pkgs.systemd}/bin/systemd-inhibit --what=handle-power-key sleep infinity"
        ];
        exec = [
          "$(${pkgs.procps}/bin/pkill -u $USER iio_ambient || true) && ${iab}/bin/iio_ambient_brightness -s"
        ];
        env = [
          "XDG_CURRENT_DESKTOP,Hyprland"
          "XDG_SESSION_TYPE,wayland"
          "XDG_SESSION_DESKTOP,Hyprland"
          "QT_QPA_PLATFORM,wayland;xcb"
          "QT_QPA_PLATFORMTHEME,qt6ct"
          "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
          "QT_AUTO_SCREEN_SCALE_FACTOR,1"
          "MOZ_ENABLE_WAYLAND,1"
          "GDK_SCALE,1"
          "YDOTOOL_SOCKET,/run/ydotoold/socket"
        ];
        bind = [
          "ALT SHIFT, 1, movetoworkspacesilent, 1"
          "ALT SHIFT, 2, movetoworkspacesilent, 2"
          "ALT SHIFT, 3, movetoworkspacesilent, 3"
          "ALT SHIFT, 4, movetoworkspacesilent, 4"
          "ALT SHIFT, 5, movetoworkspacesilent, 5"
          "ALT SHIFT, 6, movetoworkspacesilent, 6"
          "ALT SHIFT, 7, movetoworkspacesilent, 7"
          "ALT SHIFT, 8, movetoworkspacesilent, 8"
          "ALT SHIFT, 9, movetoworkspacesilent, 9"
          "ALT SHIFT, 0, movetoworkspacesilent, 10"
          "ALT, 1, workspace, 1"
          "ALT, 2, workspace, 2"
          "ALT, 3, workspace, 3"
          "ALT, 4, workspace, 4"
          "ALT, 5, workspace, 5"
          "ALT, 6, workspace, 6"
          "ALT, 7, workspace, 7"
          "ALT, 8, workspace, 8"
          "ALT, 9, workspace, 9"
          "ALT, 0, workspace, 10"
          "ALT, up, movefocus, u"
          "ALT, left, movefocus, l"
          "ALT, right, movefocus, r"
          "ALT, down, movefocus, d"
          "ALT SHIFT, up, movewindow, u"
          "ALT SHIFT, left, movewindow, l"
          "ALT SHIFT, right, movewindow, r"
          "ALT SHIFT, down, movewindow, d"
          "ALT, Return, exec, ${pkgs.ghostty}/bin/ghostty"
          "ALT, D, exec, ${pkgs.wofi}/bin/wofi -D show_all=false --show run"
          ", XF86SelectiveScreenshot, exec, ${pkgs.wayshot}/bin/wayshot -s \"$(${pkgs.slurp}/bin/slurp)\" --stdout | ${pkgs.wl-clipboard}/bin/wl-copy"
          ", Print, exec, ${pkgs.wayshot}/bin/wayshot --stdout | ${pkgs.wl-clipboard}/bin/wl-copy"
        ];
        bindle = [
          ", XF86AudioRaiseVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%"
          ", XF86AudioLowerVolume, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%"
          ", XF86MonBrightnessUp, exec, ${iab}/bin/iio_ambient_brightness --increase 10"
          ", XF86MonBrightnessDown, exec, ${iab}/bin/iio_ambient_brightness --decrease 10"
          ", XF86Search, exec, launchpad"
          # MacOS-like keybindings
          # https://github.com/torvalds/linux/blob/master/include/uapi/linux/input-event-codes.h
          # "ALT, M, exec, ${pkgs.ydotool}/bin/ydotool type foo"
          "ALT, X, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 45:1 45:0 29:0"
          "ALT, C, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 46:1 46:0 29:0"
          "ALT SHIFT, C, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 42:1 46:1 46:0 42:0 29:0"
          "ALT, V, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 47:1 47:0 29:0"
          "ALT SHIFT, V, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 42:1 47:1 47:0 42:0 29:0"
          "ALT, Z, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 44:1 44:0 29:0"
          "ALT, A, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 30:1 30:0 29:0"
          # Search
          "ALT, F, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 33:1 33:0 29:0"
          # Print
          "ALT, P, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 25:1 25:0 29:0"
          # Save
          "ALT, S, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 31:1 31:0 29:0"
          # Chrome new tab
          "ALT, T, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 20:1 20:0 29:0"
          "ALT SHIFT, T, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 42:1 20:1 20:0 42:0 29:0"
          # Chrome close tab
          "ALT, W, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 17:1 17:0 29:0"
          # Chrome page reload
          "ALT, R, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 19:1 19:0 29:0"
          # Chrome select url
          "ALT, L, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 38:1 38:0 29:0"
          # Chrome history
          "ALT, Y, exec, ${pkgs.ydotool}/bin/ydotool key 29:1 21:1 21:0 29:0"
          # Chrome downloads (overlaps with window movements, disabled)
          # bindsym --to-code $mod+shift+j exec wtype -M ctrl -P j
        ];
        bindl = [
          ", XF86AudioMute, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle"
          ", XF86AudioMicMute, exec, ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SINK@ toggle"
          # ", XF86AudioPlay, exec, playerctl play-pause"
          # ", XF86AudioNext, exec, playerctl next"
          # ", XF86AudioPrev, exec, playerctl previous"
          ", switch:on:Lid Switch, exec, ${pkgs.hyprland}/bin/hyprctl dispatch dpms off"
          ", switch:off:Lid Switch, exec, ${pkgs.hyprland}/bin/hyprctl dispatch dpms on"
        ];
        # debug = {
        #   disable_logs = false;
        # };
        device = [
          {
            name = "at-translated-set-2-keyboard";
            kb_variant = "colemak";
            kb_options = "caps:escape";
          }
          {
            name = "ydotoold-virtual-device";
            kb_layout = "us";
            kb_variant = "";
            # kb_variant = "colemak";
            kb_options = "";
          }
        ];
        input = {
          kb_layout = "us";
          kb_variant = "";
          follow_mouse = 1;
          touchpad = {
            natural_scroll = false;
            middle_button_emulation = true;
            scroll_factor = ".2";
            clickfinger_behavior = true;
          };
          scroll_method = "2fg";
          accel_profile = "adaptive";
        };
        gestures = {
          workspace_swipe = true;
          workspace_swipe_fingers = 3;
        };
        dwindle = {
          pseudotile = "yes";
          preserve_split = "yes";
        };

        workspace = map (x: "${x}, gapsout:0, gapsin:0") [
          "w[t1]"
          "w[tg1]"
          "f[1]"
        ];

        windowrulev2 = lib.lists.flatten (
          map
            (x: [
              "bordersize 0, floating:0, onworkspace:${x}"
              "rounding 0, floating:0, onworkspace:${x}"
            ])
            [
              "w[t1]"
              "w[tg1]"
              "f[1]"
            ]
        );

        master = {
          new_status = "master";
        };
        misc = {
          vrr = 0;
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          force_default_wallpaper = 0;
          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;
        };
      };
    };

    windowManager.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      extraConfig = ''
        set $mode_power (l)ock, (e)xit, (p)oweroff, (r)eboot
      '';
      config = {
        defaultWorkspace = "workspace number 1";
        terminal = "${pkgs.ghostty}/bin/ghostty";
        menu = "${pkgs.wofi}/bin/wofi -D show_all=false --show run";
        input = {
          "1:1:AT_Translated_Set_2_keyboard" = {
            xkb_layout = "us";
            xkb_variant = "colemak";
            xkb_options = "caps:escape";
          };
          "1267:12939:ASUE1214:00_04F3:328B_Touchpad" = {
            middle_emulation = "enabled";
            dwt = "enabled";
            scroll_factor = ".2";
            scroll_method = "two_finger";
            accel_profile = "adaptive";
            click_method = "clickfinger";
          };
        };
        floating = {
          criteria = [
            { title = "Picture-in-Picture"; }
          ];
        };
        focus = {
          followMouse = false;
          wrapping = "workspace";
        };
        window = {
          commands = [
            {
              command = "move position 1000 630, sticky enable";
              criteria = {
                title = "Picture-in-Picture";
              };
            }
          ];
          hideEdgeBorders = "smart";
        };
        gaps = {
          inner = 5;
          outer = 2;
          smartBorders = "on";
          smartGaps = true;
        };
        colors = {
          focused = {
            border = "#9aa5ce";
            background = "#364A82";
            text = "#c0caf5";
            indicator = "#9aa5ce";
            childBorder = "#9aa5ce";
          };
          focusedInactive = {
            border = "#16161d";
            background = "#16161d";
            text = "#c0caf5";
            indicator = "#16161d";
            childBorder = "#16161d";
          };
          unfocused = {
            border = "#16161d";
            background = "#16161d";
            text = "#c0caf5";
            indicator = "#16161d";
            childBorder = "#16161d";
          };
        };
        bars = [
          {
            mode = "dock";
            hiddenState = "hide";
            position = "bottom";
            workspaceButtons = true;
            workspaceNumbers = true;
            statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs config-default";
            fonts = {
              names = [ "monospace" ];
              size = 10.0;
            };
            # trayOutput = "primary";
            colors = {
              background = "#000000";
              statusline = "#ffffff";
              separator = "#666666";
              focusedWorkspace = {
                border = "#9aa5ce";
                background = "#364A82";
                text = "#c0caf5";
              };
              activeWorkspace = {
                border = "#9aa5ce";
                background = "#364A82";
                text = "#c0caf5";
              };
              inactiveWorkspace = {
                border = "#16161d";
                background = "#16161d";
                text = "#c0caf5";
              };
              urgentWorkspace = {
                border = "#2f343a";
                background = "#900000";
                text = "#ffffff";
              };
              bindingMode = {
                border = "#2f343a";
                background = "#900000";
                text = "#ffffff";
              };
            };
          }
        ];
        modes = lib.mkOptionDefault {
          "$mode_power" = {
            l = "exec ${pkgs.systemd}/bin/loginctl lock-session, mode default";
            e = "exec ${pkgs.sway}/bin/swaymsg exit";
            p = "exec ${pkgs.systemd}/bin/systemctl poweroff";
            r = "exec ${pkgs.systemd}/systemctl reboot";
            Escape = "mode default";
          };
        };
        startup = [
          {
            command = "${pkgs.systemd}/bin/systemd-inhibit --what=handle-power-key sleep infinity";
            always = false;
          }
          {
            command = "${config.home.homeDirectory}/${config.home.file."bin/sunset".target}";
            always = false;
          }
          {
            command = "${pkgs.mako}/bin/mako";
            always = false;
          }
          {
            command = "$(${pkgs.procps}/bin/pkill -u $USER iio_ambient || true) && ${iab}/bin/iio_ambient_brightness -s";
            always = true;
          }
        ];
        keybindings = with config.wayland.windowManager.sway.config; {
          "${modifier}+Return" = "exec ${terminal}";
          "${modifier}+Shift+q" = "kill";
          "${modifier}+d" = "exec ${menu}";

          "${modifier}+Left" = "focus left";
          "${modifier}+Down" = "focus down";
          "${modifier}+Up" = "focus up";
          "${modifier}+Right" = "focus right";

          "${modifier}+Shift+Left" = "move left";
          "${modifier}+Shift+Down" = "move down";
          "${modifier}+Shift+Up" = "move up";
          "${modifier}+Shift+Right" = "move right";

          # "${modifier}+h" = "split h";
          # "${modifier}+v" = "split v";
          "${modifier}+Shift+f" = "fullscreen toggle";

          "${modifier}+Shift+s" = "layout stacking";
          "${modifier}+Shift+w" = "layout tabbed";
          "${modifier}+Shift+e" = "layout toggle split";

          "${modifier}+Shift+space" = "floating toggle";
          "${modifier}+space" = "focus mode_toggle";

          # "${modifier}+a" = "focus parent";

          "${modifier}+Shift+minus" = "move scratchpad";
          "${modifier}+minus" = "scratchpad show";

          "${modifier}+1" = "workspace number 1";
          "${modifier}+2" = "workspace number 2";
          "${modifier}+3" = "workspace number 3";
          "${modifier}+4" = "workspace number 4";
          "${modifier}+5" = "workspace number 5";
          "${modifier}+6" = "workspace number 6";
          "${modifier}+7" = "workspace number 7";
          "${modifier}+8" = "workspace number 8";
          "${modifier}+9" = "workspace number 9";
          "${modifier}+0" = "workspace number 10";

          "${modifier}+Shift+1" = "move container to workspace number 1";
          "${modifier}+Shift+2" = "move container to workspace number 2";
          "${modifier}+Shift+3" = "move container to workspace number 3";
          "${modifier}+Shift+4" = "move container to workspace number 4";
          "${modifier}+Shift+5" = "move container to workspace number 5";
          "${modifier}+Shift+6" = "move container to workspace number 6";
          "${modifier}+Shift+7" = "move container to workspace number 7";
          "${modifier}+Shift+8" = "move container to workspace number 8";
          "${modifier}+Shift+9" = "move container to workspace number 9";
          "${modifier}+Shift+0" = "move container to workspace number 10";

          "${modifier}+Shift+r" = "reload";
          "${modifier}+Shift+x" = "restart";
          "${modifier}+e" = "exec ${my_bemoji}/bin/bemoji -t";
          # "${modifier}+Shift+e" = "exec i3-nagbar -t warning -m 'Do you want to exit i3?' -b 'Yes' 'i3-msg exit'";

          "${modifier}+n" = "exec ${pkgs.mako}/bin/makoctl dismiss";
          "${modifier}+Shift+n" = "exec ${pkgs.mako}/bin/makoctl dismiss -a";

          # "${modifier}+r" = "mode resize";

          # MacOS-like keybindings
          "${modifier}+x" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P x";
          "${modifier}+c" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P c";
          "${modifier}+Shift+c" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -M shift -P c";
          "${modifier}+v" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P v";
          "${modifier}+Shift+v" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -M shift -P v";
          "${modifier}+z" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P z";
          "${modifier}+a" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P a";
          # Search
          "${modifier}+f" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P f";
          # Print
          "${modifier}+p" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P p";
          # Save
          "${modifier}+s" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P s";
          # Chrome new tab
          "${modifier}+t" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P t";
          "${modifier}+Shift+t" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -M shift -P t";
          # Chrome close tab
          "${modifier}+w" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P w";
          # Chrome page reload
          "${modifier}+r" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P r";
          # Chrome select url
          "${modifier}+l" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P l";
          # Chrome history
          "${modifier}+y" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P h";
          # Chrome downloads (overlaps with window movements, disabled)
          # bindsym --to-code $mod+shift+j exec wtype -M ctrl -P j

          # "XF86MonBrightnessDown" = "exec ${pkgs.brightnessctl}/bin/brightnessctl s 10%-";
          # "XF86MonBrightnessUp" = "exec ${pkgs.brightnessctl}/bin/brightnessctl s 10%+";
          "XF86MonBrightnessDown" = "exec ${iab}/bin/iio_ambient_brightness --decrease 10";
          "XF86MonBrightnessUp" = "exec ${iab}/bin/iio_ambient_brightness --increase 10";

          "XF86AudioMute" = "exec ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
          "XF86AudioMicMute" = "exec ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SINK@ toggle";
          "XF86AudioRaiseVolume" = "exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +5%";
          "XF86AudioLowerVolume" = "exec ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -5%";
          "XF86SelectiveScreenshot" =
            "exec ${pkgs.wayshot}/bin/wayshot -s \"$(${pkgs.slurp}/bin/slurp)\" --stdout | ${pkgs.wl-clipboard}/bin/wl-copy";
          "Print" = "exec ${pkgs.wayshot}/bin/wayshot --stdout | ${pkgs.wl-clipboard}/bin/wl-copy";

          "--release XF86PowerOff" = "mode \"$mode_power\"";
        };
      };
    };
  };

  services.swayidle = {
    enable = true;
    extraArgs = [ "-d" ];
    events = [
      {
        event = "before-sleep";
        command = "${pkgs.hyprlock}/bin/hyprlock";
      }
      {
        event = "lock";
        command = "${pkgs.hyprlock}/bin/hyprlock";
      }
    ];
    timeouts = [
      {
        timeout = 60;
        command = "${iab}/bin/iio_ambient_brightness -i";
        resumeCommand = "${iab}/bin/iio_ambient_brightness -a";
      }
      {
        timeout = 120;
        command = "${pkgs.hyprlock}/bin/hyprlock";
      }
      {
        timeout = 300;
        command = "[ \"$(${pkgs.coreutils}/bin/cat /sys/class/power_supply/AC0/online)\" = \"0\" ] && ${pkgs.systemd}/bin/systemctl suspend";
      }
      {
        timeout = 180;
        command = "if ${pkgs.procps}/bin/pgrep -x hyprlock; then ${pkgs.sway}/bin/swaymsg \"output * power off\"; fi";
        resumeCommand = "${pkgs.sway}/bin/swaymsg \"output * power on\"";
      }
    ];
  };

  fonts.fontconfig.enable = true;

  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri-dark = "file://${pkgs.nixos-artwork.wallpapers.nineish-dark-gray.src}";
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    font = {
      name = "MonaspiceNe Nerd Font";
      package =
        if (builtins.compareVersions lib.trivial.release "24.11" == 0) then
          pkgs.nerdfonts.override { fonts = [ "Monaspace" ]; }
        else
          pkgs.nerd-fonts.monaspace;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  home.pointerCursor = {
    x11.enable = true;
    gtk.enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 48;
  };
  home.file.".icons/default".source = "${pkgs.adwaita-icon-theme}/share/icons/Adwaita";

  xdg.configFile."wluma/config.toml".text = ''
    [als.iio]
    path = "/sys/bus/iio/devices"
    thresholds = { 0 = "night", 20 = "dark", 80 = "dim", 250 = "normal", 500 = "bright", 800 = "outdoors" }

    [[output.backlight]]
    name = "eDP-1"
    path = "/sys/class/backlight/intel_backlight"
    capturer = "wlroots"

    [[keyboard]]
    name = "keyboard-asus"
    path = "/sys/bus/platform/devices/asus-nb-wmi/leds/asus::kbd_backlight"
  '';

  home.file."bin/sunset" = {
    source = ../../bin/sunset;
    executable = true;
  };

  home.file."bin/discord" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      exec -a "$0" ~/bin/systemGL ${pkgs.discord}/bin/discord --enable-features=UseOzonePlatform --ozone-platform=wayland "$@"
    '';
    executable = true;
  };

  home.file."bin/obsidian" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      export OBSIDIAN_USE_WAYLAND=1
      exec -a "$0" ~/bin/systemGL ${pkgs.obsidian}/bin/obsidian --ozone-platform=wayland --ozone-platform-hint=auto --enable-features=UseOzonePlatform,WaylandWindowDecorations "$@"
    '';
    executable = true;
  };

  home.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    LIBVA_DRIVERS_PATH = "${pkgs.intel-media-driver}/lib/dri";
    VDPAU_DRIVER = "va_gl";
  };

  home.username = "jeffutter";
  home.homeDirectory = "/home/jeffutter";
}
