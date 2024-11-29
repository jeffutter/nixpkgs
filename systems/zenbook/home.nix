{
  pkgs,
  lib,
  config,
  ...
}:

let

  nixgl = import <nixgl> { enable32bits = false; };
  nixGLPkg = nixgl.nixGLCommon nixgl.nixGLMesa;
  nixGL = import ../nixGL.nix { inherit pkgs config; };
  iab =
    (builtins.getFlake "github:jeffutter/iio_ambient_brightness/v0.2.14")
    .packages.${pkgs.system}.default;
  my_zoom = pkgs.symlinkJoin {
    name = "zoom-us";
    paths = [ (nixGL pkgs.zoom-us) ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zoom --set QT_XCB_GL_INTEGRATION xcb_egl
    '';
  };
in
{
  imports = [ ../common.nix ];

  nixGLPrefix = lib.getExe' nixGLPkg "nixGL";

  home.packages = with pkgs; [
    _1password-cli
    _1password-gui
    # llvmPackages_13.bintools-unwrapped
    my_zoom
    clang
    # clang_13
    cargo-watch
    nixGLPkg
    wofi
    brightnessctl
    wlsunset
    wl-clipboard
    slurp
    wayshot
    mako
    (nixGL sway)
    blueberry
    pavucontrol
    (pkgs.wluma.overrideAttrs (old: rec {
      version = "4.4.0";

      src = old.src.overrideAttrs (_: {
        sha256 = "sha256-Ow3SjeulYiHY9foXrmTtLK3F+B3+DrtDjBUke3bJeDw=";
        rev = version;
      });

      cargoLock = null;
      cargoHash = lib.fakeHash;
    }))
    iab
  ];

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
  #   package = (nixGL pkgs.eww);
  #   enableFishIntegration = true;
  #   enableZshIntegration = true;
  # };

  programs.waybar = {
    enable = true;
    package = (nixGL pkgs.waybar);
    settings = {
      mainBar = {
        layer = "top";
        position = "bottom";
        height = 25;
        # width= 1366;
        modules-left = [
          "hyprland/workspaces"
          "sway/mode"
          "custom/spotify"
        ];
        modules-center = [
          "custom/ff"
          "custom/nemo"
          "custom/chrome"
          "custom/libre"
        ];
        modules-right = [
          "pulseaudio"
          "network"
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
          format = "{usage}%     ";
        };
        memory = {
          format = "{}%   ";
        };
        battery = {
          bat = "BAT0";
          states = {
            # // good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{capacity}%     ";
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
          format-wifi = "{essid} ({signalStrength}%)     ";
          format-ethernet = "{ifname}= {ipaddr}/{cidr} ";
          format-disconnected = "Disconnected ⚠";
        };
        pulseaudio = {
          scroll-step = 5;
          format = "    {volume}%";
          format-bluetooth = "   {volume}%";
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
        "custom/spotify" = {
          format = " {}";
          max-length = 40;
          interval = 30;
          exec = "$HOME/.config/waybar/mediaplayer.sh 2> /dev/null";
          exec-if = "pgrep spotify";
        };
        "custom/ff" = {
          format = "    {}";
          max-length = 40;
          on-click = "${pkgs.hyprland}/bin/hyprctl dispatch exec /opt/firefox/firefox";
        };
        "custom/nemo" = {
          format = "    {}";
          max-length = 40;
          on-click = "${pkgs.hyprland}/bin/hyprctl dispatch exec nemo";
        };
        "custom/chrome" = {
          format = "     {}";
          max-length = 40;
          on-click = "${pkgs.hyprland}/bin/hyprctl dispatch exec google-chrome";

        };
        "custom/libre" = {
          format = "     {}";
          max-length = 40;
          on-click = "${pkgs.hyprland}/bin/hyprctl dispatch exec libre";
        };
      };
    };
  };

  programs.hyprlock = {
    enable = true;
    # package = (nixGL pkgs.hyprlock);
    # nix hyprlock doesn't play well with ubuntu pam
    package = pkgs.runCommandLocal "empty" { } "mkdir $out";
    settings = {

      background = {
        monitor = "";
        path = "~/wallpapers/hyprlock.png";
        blur_passes = 0;
        contrast = 0.8916;
        brightness = 0.8172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };
      general = {
        no_fade_in = false;
        grace = 0;
        disable_loading_bar = false;
      };

      label = [
        {
          monitor = "";
          text = "Welcome!";
          color = "rgba(216, 222, 233, .75)";
          font_size = 55;
          font_family = "SF Pro Display Bold";
          position = "150, 320";
          halign = "left";
          valign = "center";
        }

        {
          monitor = "";
          text = "cmd[update:1000] echo \"<span>$(date +\"%I:%M\")</span>\"";
          color = "rgba(216, 222, 233, .75)";
          font_size = 40;
          font_family = "SF Pro Display Bold";
          position = "240, 240";
          halign = "left";
          valign = "center";
        }

        {
          monitor = "";
          text = "cmd[update:1000] echo -e \"$(date +\"%A, %B %d\")\"";
          color = "rgba(216, 222, 233, .75)";
          font_size = 19;
          font_family = "SF Pro Display Bold";
          position = "217, 175";
          halign = "left";
          valign = "center";
        }
        {
          monitor = "";
          text = "    $USER";
          color = "rgba(216, 222, 233, 0.80)";
          outline_thickness = 0;
          dots_size = 0.2; # Scale of input-field height, 0.2 - 0.8
          dots_spacing = 0.2; # Scale of dots' absolute size, 0.0 - 1.0;
          dots_center = true;
          font_size = 16;
          font_family = "SF Pro Display Bold";
          position = "275, -140";
          halign = "left";
          valign = "center";
        }
      ];

      # image = {
      #   monitor = "";
      #   path = "" ~/.config/hypr/vivek.png "";
      #   border_size = 2;
      #   border_color = "rgba(255, 255, 255, .75)";
      #   size = 95;
      #   rounding = -1;
      #   rotate = 0;
      #   reload_time = -1;
      #   reload_cmd = "";
      #   position = "270, 25";
      #   halign = "left";
      #   valign = "center";
      # };

      shape = {
        monitor = "";
        size = "320, 55";
        color = "rgba(255, 255, 255, .1)";
        rounding = -1;
        border_size = 0;
        border_color = "rgba(255, 255, 255, 1)";
        rotate = 0;
        xray = false; # if true, make a "hole" in the background (rectangle of specified size, no rotation)
        position = "160, -140";
        halign = "left";
        valign = "center";
      };

      input-field = {
        monitor = "";
        size = "320, 55";
        outline_thickness = 0;
        dots_size = 0.2; # Scale of input-field height, 0.2 - 0.8;
        dots_spacing = 0.2; # Scale of dots' absolute size, 0.0 - 1.0;
        dots_center = true;
        outer_color = "rgba(255, 255, 255, 0)";
        inner_color = "rgba(255, 255, 255, 0.1)";
        font_color = "rgb(200, 200, 200)";
        fade_on_empty = false;
        font_family = "SF Pro Display Bold";
        placeholder_text = "<i><span foreground=\"##ffffff99\">🔒  Enter Pass</span></i>";
        hide_input = false;
        position = "160, -220";
        halign = "left";
        valign = "center";
      };
    };
  };

  programs.swaylock = {
    enable = true;
    # nix swaylock doesn't play well with ubuntu pam
    package = pkgs.runCommandLocal "empty" { } "mkdir $out";
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
        icons = "awesome6";
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
          { block = "sound"; }
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
      package = (nixGL pkgs.hyprland);
      settings = {
        animation = [
          "workspaces,1,4,default,fade"
          "windows,1,4,default,popin"
        ];
        monitor = ",preferred,auto,auto";
        exec-once = [ "${(nixGL pkgs.waybar)}/bin/waybar" ];
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
        input = {
          kb_layout = "us";
          kb_variant = "colemak";
          kb_options = "caps:escape";
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
          no_gaps_when_only = 1;
        };
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
      package = (nixGL pkgs.sway);
      wrapperFeatures.gtk = true;
      extraConfig = ''
        set $mode_power (l)ock, (e)xit, (p)oweroff, (r)eboot
      '';
      config = {
        defaultWorkspace = "workspace number 1";
        terminal = "${pkgs.kitty}/bin/kitty";
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
        focus = {
          followMouse = false;
          wrapping = "workspace";
        };
        window.hideEdgeBorders = "smart";
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
            l = "exec loginctl lock-session, mode default";
            e = "exec i3msg exit";
            p = "exec systemctl poweroff";
            r = "exec systemctl reboot";
            Escape = "mode default";
          };
        };
        startup = [
          {
            command = "systemd-inhibit --what=handle-power-key sleep infinity";
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
        keybindings = {
          "${config.wayland.windowManager.sway.config.modifier}+Return" = "exec ${config.wayland.windowManager.sway.config.terminal}";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+q" = "kill";
          "${config.wayland.windowManager.sway.config.modifier}+d" = "exec ${config.wayland.windowManager.sway.config.menu}";

          "${config.wayland.windowManager.sway.config.modifier}+Left" = "focus left";
          "${config.wayland.windowManager.sway.config.modifier}+Down" = "focus down";
          "${config.wayland.windowManager.sway.config.modifier}+Up" = "focus up";
          "${config.wayland.windowManager.sway.config.modifier}+Right" = "focus right";

          "${config.wayland.windowManager.sway.config.modifier}+Shift+Left" = "move left";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+Down" = "move down";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+Up" = "move up";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+Right" = "move right";

          # "${config.wayland.windowManager.sway.config.modifier}+h" = "split h";
          # "${config.wayland.windowManager.sway.config.modifier}+v" = "split v";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+f" = "fullscreen toggle";

          "${config.wayland.windowManager.sway.config.modifier}+Shift+s" = "layout stacking";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+w" = "layout tabbed";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+e" = "layout toggle split";

          "${config.wayland.windowManager.sway.config.modifier}+Shift+space" = "floating toggle";
          "${config.wayland.windowManager.sway.config.modifier}+space" = "focus mode_toggle";

          # "${config.wayland.windowManager.sway.config.modifier}+a" = "focus parent";

          "${config.wayland.windowManager.sway.config.modifier}+Shift+minus" = "move scratchpad";
          "${config.wayland.windowManager.sway.config.modifier}+minus" = "scratchpad show";

          "${config.wayland.windowManager.sway.config.modifier}+1" = "workspace number 1";
          "${config.wayland.windowManager.sway.config.modifier}+2" = "workspace number 2";
          "${config.wayland.windowManager.sway.config.modifier}+3" = "workspace number 3";
          "${config.wayland.windowManager.sway.config.modifier}+4" = "workspace number 4";
          "${config.wayland.windowManager.sway.config.modifier}+5" = "workspace number 5";
          "${config.wayland.windowManager.sway.config.modifier}+6" = "workspace number 6";
          "${config.wayland.windowManager.sway.config.modifier}+7" = "workspace number 7";
          "${config.wayland.windowManager.sway.config.modifier}+8" = "workspace number 8";
          "${config.wayland.windowManager.sway.config.modifier}+9" = "workspace number 9";
          "${config.wayland.windowManager.sway.config.modifier}+0" = "workspace number 10";

          "${config.wayland.windowManager.sway.config.modifier}+Shift+1" = "move container to workspace number 1";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+2" = "move container to workspace number 2";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+3" = "move container to workspace number 3";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+4" = "move container to workspace number 4";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+5" = "move container to workspace number 5";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+6" = "move container to workspace number 6";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+7" = "move container to workspace number 7";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+8" = "move container to workspace number 8";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+9" = "move container to workspace number 9";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+0" = "move container to workspace number 10";

          "${config.wayland.windowManager.sway.config.modifier}+Shift+r" = "reload";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+x" = "restart";
          # "${config.wayland.windowManager.sway.config.modifier}+Shift+e" = "exec i3-nagbar -t warning -m 'Do you want to exit i3?' -b 'Yes' 'i3-msg exit'";

          "${config.wayland.windowManager.sway.config.modifier}+n" = "exec ${pkgs.mako}/bin/makoctl dismiss";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+n" = "exec ${pkgs.mako}/bin/makoctl dismiss -a";

          # "${config.wayland.windowManager.sway.config.modifier}+r" = "mode resize";

          # MacOS-like keybindings
          "${config.wayland.windowManager.sway.config.modifier}+x" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P x";
          "${config.wayland.windowManager.sway.config.modifier}+c" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P c";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+c" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -M shift -P c";
          "${config.wayland.windowManager.sway.config.modifier}+v" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P v";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+v" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -M shift -P v";
          "${config.wayland.windowManager.sway.config.modifier}+z" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P z";
          "${config.wayland.windowManager.sway.config.modifier}+a" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P a";
          # Search
          "${config.wayland.windowManager.sway.config.modifier}+f" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P f";
          # Print
          "${config.wayland.windowManager.sway.config.modifier}+p" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P p";
          # Save
          "${config.wayland.windowManager.sway.config.modifier}+s" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P s";
          # Chrome new tab
          "${config.wayland.windowManager.sway.config.modifier}+t" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P t";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+t" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -M shift -P t";
          # Chrome close tab
          "${config.wayland.windowManager.sway.config.modifier}+w" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P w";
          # Chrome page reload
          "${config.wayland.windowManager.sway.config.modifier}+r" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P r";
          # Chrome select url
          "${config.wayland.windowManager.sway.config.modifier}+l" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P l";
          # Chrome history
          "${config.wayland.windowManager.sway.config.modifier}+y" = "exec ${pkgs.wtype}/bin/wtype -M ctrl -P h";
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
          "XF86SelectiveScreenshot" = "exec ${pkgs.wayshot}/bin/wayshot -s \"$(${pkgs.slurp}/bin/slurp)\" --stdout | ${pkgs.wl-clipboard}/bin/wl-copy";
          "Print" = "exec ${pkgs.wayshot}/bin/wayshot --stdout | ${pkgs.wl-clipboard}/bin/wl-copy";

          "--release XF86PowerOff" = "mode \"$mode_power\"";
        };
      };
    };
  };

  services.syncthing = {
    enable = true;
    extraOptions = [
      "--gui-address=0.0.0.0:8384"
      "--no-default-folder"
      "--no-browser"
    ];
  };

  services.swayidle = {
    enable = true;
    extraArgs = [ "-d" ];
    events = [
      {
        event = "before-sleep";
        command = "/usr/bin/swaylock";
      }
      {
        event = "lock";
        command = "/usr/bin/swaylock";
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
        command = "/usr/bin/swaylock";
      }
      {
        timeout = 300;
        command = "[ \"$(cat /sys/class/power_supply/AC0/online)\" = \"0\" ] && /usr/bin/systemctl suspend";
      }
      {
        timeout = 10;
        command = "if ${pkgs.procps}/bin/pgrep -x swaylock; then ${pkgs.sway}/bin/swaymsg \"output * power off\"; fi";
        resumeCommand = "${pkgs.sway}/bin/swaymsg \"output * power on\"";
      }
    ];
  };

  fonts.fontconfig.enable = true;
  gtk = {
    enable = true;
    theme.name = "Adwaita-dark";
    font = {
      name = "MonaspiceNe Nerd Font";
      package = pkgs.nerdfonts.override { fonts = [ "Monaspace" ]; };
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

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

  home.file."bin/systemGL" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      unset LIBVA_DRIVERS_PATH LIBGL_DRIVERS_PATH LD_LIBRARY_PATH __EGL_VENDOR_LIBRARY_FILENAMES
      exec "$@"
    '';
    executable = true;
  };

  home.file."bin/brave-browser" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      exec -a "$0" ~/bin/systemGL /usr/bin/brave-browser --enable-features=VaapiVideoDecodeLinuxGL --use-gl=angle --use-angle=gl --ozone-platform=wayland "$@"
    '';
    executable = true;
  };

  home.file."bin/discord" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      exec -a "$0" ~/bin/systemGL /usr/bin/discord --enable-features=UseOzonePlatform --ozone-platform=wayland "$@"
    '';
    executable = true;
  };

  home.file."bin/obsidian" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      export OBSIDIAN_USE_WAYLAND=1
      exec -a "$0" ~/bin/systemGL /snap/bin/obsidian --ozone-platform=wayland --ozone-platform-hint=auto --enable-features=UseOzonePlatform,WaylandWindowDecorations "$@"
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
