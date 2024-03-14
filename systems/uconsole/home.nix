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
    # binutils
    llvmPackages_13.bintools-unwrapped
    clang_13
    cargo-watch
    nixGLPkg
    brightnessctl
    gnome.gnome-power-manager
    linuxKernel.packages.linux_5_10.cpupower

    # Games
    (nixGL fallout-ce)
    (nixGL fallout2-ce)
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
        blocks = [
          {
            block = "net";
            format = " $icon {$signal_strength $ssid|Wired connection} ^icon_net_down $speed_down.eng(prefix:K) ^icon_net_up $speed_up.eng(prefix:K) ";
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
            block = "load";
            format = " $icon $1m ";
            interval = 1;
          }
          { block = "sound"; }
          { block = "battery"; }
          {
            block = "time";
            format = " $timestamp.datetime(f:'%a %m/%d %R') ";
            interval = 60;
          }
        ];
      };
    };
  };

  xsession = {
    enable = true;
    windowManager.i3 = {
      enable = true;
      extraConfig = ''
        set $mode_power (l)ock, (e)xit, (p)oweroff, (r)eboot
      '';
      config = {
        defaultWorkspace = "workspace number 1";
        terminal = "alacritty";
        focus.followMouse = false;
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
            notification = false;
          }
          {
            command = "xscreensaver -no-splash";
            always = false;
            notification = false;
          }
        ];
        keybindings = {
          "${config.xsession.windowManager.i3.config.modifier}+Return" = "exec ${config.xsession.windowManager.i3.config.terminal}";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+q" = "kill";
          "${config.xsession.windowManager.i3.config.modifier}+d" = "exec ${config.xsession.windowManager.i3.config.menu}";

          "${config.xsession.windowManager.i3.config.modifier}+Left" = "focus left";
          "${config.xsession.windowManager.i3.config.modifier}+Down" = "focus down";
          "${config.xsession.windowManager.i3.config.modifier}+Up" = "focus up";
          "${config.xsession.windowManager.i3.config.modifier}+Right" = "focus right";

          "${config.xsession.windowManager.i3.config.modifier}+Shift+Left" = "move left";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+Down" = "move down";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+Up" = "move up";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+Right" = "move right";

          "${config.xsession.windowManager.i3.config.modifier}+h" = "split h";
          "${config.xsession.windowManager.i3.config.modifier}+v" = "split v";
          "${config.xsession.windowManager.i3.config.modifier}+f" = "fullscreen toggle";

          "${config.xsession.windowManager.i3.config.modifier}+s" = "layout stacking";
          "${config.xsession.windowManager.i3.config.modifier}+w" = "layout tabbed";
          "${config.xsession.windowManager.i3.config.modifier}+e" = "layout toggle split";

          "${config.xsession.windowManager.i3.config.modifier}+Shift+space" = "floating toggle";
          "${config.xsession.windowManager.i3.config.modifier}+space" = "focus mode_toggle";

          "${config.xsession.windowManager.i3.config.modifier}+a" = "focus parent";

          "${config.xsession.windowManager.i3.config.modifier}+Shift+minus" = "move scratchpad";
          "${config.xsession.windowManager.i3.config.modifier}+minus" = "scratchpad show";

          "${config.xsession.windowManager.i3.config.modifier}+1" = "workspace number 1";
          "${config.xsession.windowManager.i3.config.modifier}+2" = "workspace number 2";
          "${config.xsession.windowManager.i3.config.modifier}+3" = "workspace number 3";
          "${config.xsession.windowManager.i3.config.modifier}+4" = "workspace number 4";
          "${config.xsession.windowManager.i3.config.modifier}+5" = "workspace number 5";
          "${config.xsession.windowManager.i3.config.modifier}+6" = "workspace number 6";
          "${config.xsession.windowManager.i3.config.modifier}+7" = "workspace number 7";
          "${config.xsession.windowManager.i3.config.modifier}+8" = "workspace number 8";
          "${config.xsession.windowManager.i3.config.modifier}+9" = "workspace number 9";
          "${config.xsession.windowManager.i3.config.modifier}+0" = "workspace number 10";

          "${config.xsession.windowManager.i3.config.modifier}+Shift+1" = "move container to workspace number 1";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+2" = "move container to workspace number 2";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+3" = "move container to workspace number 3";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+4" = "move container to workspace number 4";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+5" = "move container to workspace number 5";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+6" = "move container to workspace number 6";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+7" = "move container to workspace number 7";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+8" = "move container to workspace number 8";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+9" = "move container to workspace number 9";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+0" = "move container to workspace number 10";

          "${config.xsession.windowManager.i3.config.modifier}+Shift+c" = "reload";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+r" = "restart";
          "${config.xsession.windowManager.i3.config.modifier}+Shift+e" = "exec i3-nagbar -t warning -m 'Do you want to exit i3?' -b 'Yes' 'i3-msg exit'";

          "${config.xsession.windowManager.i3.config.modifier}+r" = "mode resize";

          "XF86MonBrightnessDown" = "exec brightnessctl s 5%-";
          "XF86MonBrightnessUp" = "exec brightnessctl s +5%";

          "--release XF86PowerOff" = "mode \"$mode_power\"";
        };
      };
    };
  };

  home.username = "jeffutter";
  home.homeDirectory = "/home/jeffutter";
}
