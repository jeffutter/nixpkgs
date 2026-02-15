{ pkgs, lib, config, inputs, ... }:
let
  iab = inputs.iio-ambient-brightness.packages.${pkgs.stdenv.hostPlatform.system}.default;

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
in
{
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

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraConfig = ''
      set $mode_power (l)ock, (e)xit, (p)oweroff, (r)eboot
      default_border pixel 1
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
      # Stylix handles window colors
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
          # Stylix handles bar colors
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

        "${modifier}+Shift+f" = "fullscreen toggle";

        "${modifier}+Shift+s" = "layout stacking";
        "${modifier}+Shift+w" = "layout tabbed";
        "${modifier}+Shift+e" = "layout toggle split";

        "${modifier}+Shift+space" = "floating toggle";
        "${modifier}+space" = "focus mode_toggle";

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

        "${modifier}+n" = "exec ${pkgs.mako}/bin/makoctl dismiss";
        "${modifier}+Shift+n" = "exec ${pkgs.mako}/bin/makoctl dismiss -a";

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
}
