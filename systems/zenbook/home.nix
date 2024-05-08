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
in
{
  imports = [ ../common.nix ];

  nixGLPrefix = lib.getExe' nixGLPkg "nixGL";

  home.packages = with pkgs; [
    _1password
    llvmPackages_13.bintools-unwrapped
    clang_13
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
        menu = "${pkgs.wofi}/bin/wofi --show run";
        input = {
          "1:1:AT_Translated_Set_2_keyboard" = {
            xkb_layout = "us";
            xkb_variant = "colemak";
            xkb_options = "caps:escape";
          };
          "type:touchpad" = {
            "middle_emulation" = "enabled";
          };
        };
        focus = {
          followMouse = false;
          wrapping = "workspace";
        };
        window.hideEdgeBorders = "smart";
        gaps = {
          inner = 10;
          outer = 5;
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
            command = "${config.home.file."bin/sunset".target}";
            always = false;
          }
          {
            command = "${pkgs.mako}/bin/mako";
            always = false;
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

          "${config.wayland.windowManager.sway.config.modifier}+h" = "split h";
          "${config.wayland.windowManager.sway.config.modifier}+v" = "split v";
          "${config.wayland.windowManager.sway.config.modifier}+f" = "fullscreen toggle";

          "${config.wayland.windowManager.sway.config.modifier}+s" = "layout stacking";
          "${config.wayland.windowManager.sway.config.modifier}+w" = "layout tabbed";
          "${config.wayland.windowManager.sway.config.modifier}+e" = "layout toggle split";

          "${config.wayland.windowManager.sway.config.modifier}+Shift+space" = "floating toggle";
          "${config.wayland.windowManager.sway.config.modifier}+space" = "focus mode_toggle";

          "${config.wayland.windowManager.sway.config.modifier}+a" = "focus parent";

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

          "${config.wayland.windowManager.sway.config.modifier}+Shift+c" = "reload";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+r" = "restart";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+e" = "exec i3-nagbar -t warning -m 'Do you want to exit i3?' -b 'Yes' 'i3-msg exit'";

          "${config.wayland.windowManager.sway.config.modifier}+n" = "exec makoctl dismiss";
          "${config.wayland.windowManager.sway.config.modifier}+Shift+n" = "exec makoctl dismiss -a";

          "${config.wayland.windowManager.sway.config.modifier}+r" = "mode resize";

          "XF86MonBrightnessDown" = "exec ${pkgs.brightnessctl}/bin/brightnessctl s 10%-";
          "XF86MonBrightnessUp" = "exec ${pkgs.brightnessctl}/bin/brightnessctl s 10%+";

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

  home.file."bin/sunset" = {
    source = ../../bin/sunset;
    executable = true;
  };

  home.file.".config/gtk-4.0/settings.ini" = {
    text = ''
      [Settings]
      gtk-application-prefer-dark-theme = true
    '';
  };

  home.file.".config/gtk-3.0/settings.ini" = {
    text = ''
      [Settings]
      gtk-application-prefer-dark-theme = true
    '';
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
      exec -a "$0" ${config.home.file."bin/systemGL".target} /usr/bin/brave-browser "$@"
    '';
    executable = true;
  };

  home.file."bin/discord" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      exec -a "$0" ${
        config.home.file."bin/systemGL".target
      } /usr/bin/discord --enable-features=UseOzonePlatform --ozone-platform=wayland "$@"
    '';
    executable = true;
  };

  home.file."bin/obsidian" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      export OBSIDIAN_USE_WAYLAND=1
      exec -a "$0" ${
        config.home.file."bin/systemGL".target
      } /snap/bin/obsidian --ozone-platform=wayland --ozone-platform-hint=auto --enable-features=UseOzonePlatform,WaylandWindowDecorations "$@"
    '';
    executable = true;
  };

  home.file."bin/bluemail" = {
    text = ''
      #!${pkgs.bash}/bin/bash
      exec -a "$0" ${config.home.file."bin/systemGL".target} /snap/bin/bluemail "$@"
    '';
    executable = true;
  };

  home.username = "jeffutter";
  home.homeDirectory = "/home/jeffutter";
}
