{ pkgs, inputs, ... }:
let
  iab = inputs.iio-ambient-brightness.packages.${pkgs.stdenv.hostPlatform.system}.default;

  screenshotRegion = pkgs.writeShellScript "niri-screenshot-region" ''
    ${pkgs.wayshot}/bin/wayshot -s "$(${pkgs.slurp}/bin/slurp)" --stdout | ${pkgs.wl-clipboard}/bin/wl-copy
  '';

  screenshotFull = pkgs.writeShellScript "niri-screenshot-full" ''
    ${pkgs.wayshot}/bin/wayshot --stdout | ${pkgs.wl-clipboard}/bin/wl-copy
  '';
in
{
  home.file.".config/niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us"
                variant "colemak"
                options "caps:escape"
            }
            repeat-delay 600
            repeat-rate 25
        }
        touchpad {
            tap
            dwt
            scroll-factor 0.2
            click-method "clickfinger"
            accel-profile "adaptive"
        }
        mouse {
            accel-profile "adaptive"
        }
    }

    output "eDP-1" {
        scale 2.0
    }

    layout {
        gaps 8
        center-focused-column "never"
        default-column-width { proportion 0.5; }
        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        focus-ring {
            width 2
            active-color "#7aa2f7"
            inactive-color "#1a1b26"
        }
        border {
            off
        }
    }

    animations {
        workspace-switch {
            spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
        }
        window-open {
            duration-ms 150
            curve "ease-out-expo"
        }
        window-close {
            duration-ms 150
            curve "ease-out-cubic"
        }
        window-movement {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }
        window-resize {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }
    }

    cursor {
        hide-when-typing
        hide-after-inactive-ms 2000
    }

    environment {
        XDG_CURRENT_DESKTOP "niri"
        XDG_SESSION_TYPE "wayland"
        XDG_SESSION_DESKTOP "niri"
        QT_QPA_PLATFORM "wayland;xcb"
        QT_QPA_PLATFORMTHEME "qt6ct"
        QT_WAYLAND_DISABLE_WINDOWDECORATION "1"
        QT_AUTO_SCREEN_SCALE_FACTOR "1"
        MOZ_ENABLE_WAYLAND "1"
        GDK_SCALE "1"
    }

    prefer-no-csd

    hotkey-overlay {
        skip-at-startup
    }

    spawn-at-startup "${pkgs.waybar}/bin/waybar"
    spawn-at-startup "${pkgs.systemd}/bin/systemd-inhibit" "--what=handle-power-key" "sleep" "infinity"
    spawn-at-startup "${pkgs.bash}/bin/bash" "-c" "pkill -u $USER iio_ambient 2>/dev/null; ${iab}/bin/iio_ambient_brightness -s"

    binds {
        Alt+1 { focus-workspace 1; }
        Alt+2 { focus-workspace 2; }
        Alt+3 { focus-workspace 3; }
        Alt+4 { focus-workspace 4; }
        Alt+5 { focus-workspace 5; }
        Alt+6 { focus-workspace 6; }
        Alt+7 { focus-workspace 7; }
        Alt+8 { focus-workspace 8; }
        Alt+9 { focus-workspace 9; }

        Alt+Shift+1 { move-column-to-workspace 1; }
        Alt+Shift+2 { move-column-to-workspace 2; }
        Alt+Shift+3 { move-column-to-workspace 3; }
        Alt+Shift+4 { move-column-to-workspace 4; }
        Alt+Shift+5 { move-column-to-workspace 5; }
        Alt+Shift+6 { move-column-to-workspace 6; }
        Alt+Shift+7 { move-column-to-workspace 7; }
        Alt+Shift+8 { move-column-to-workspace 8; }
        Alt+Shift+9 { move-column-to-workspace 9; }

        Alt+Left  { focus-column-left; }
        Alt+Right { focus-column-right; }
        Alt+Up    { focus-window-up; }
        Alt+Down  { focus-window-down; }

        Alt+Shift+Left  { move-column-left; }
        Alt+Shift+Right { move-column-right; }
        Alt+Shift+Up    { move-window-up; }
        Alt+Shift+Down  { move-window-down; }

        Alt+Q { close-window; }
        Alt+Shift+F { fullscreen-window; }
        Alt+M { maximize-column; }
        // Alt+W and Alt+C are consumed by keyd (remapped to Ctrl+W/Ctrl+C system-wide)
        Alt+B { switch-preset-column-width; }
        Alt+G { center-column; }

        Alt+Minus { set-column-width "-10%"; }
        Alt+Equal { set-column-width "+10%"; }
        Alt+Shift+Minus { set-window-height "-10%"; }
        Alt+Shift+Equal { set-window-height "+10%"; }

        Alt+Comma  { consume-window-into-column; }
        Alt+Period { expel-window-from-column; }

        Alt+Tab { toggle-overview; }

        Ctrl+Alt+F1 { spawn "/run/wrappers/bin/chvt" "1"; }
        Ctrl+Alt+F2 { spawn "/run/wrappers/bin/chvt" "2"; }
        Ctrl+Alt+F3 { spawn "/run/wrappers/bin/chvt" "3"; }
        Ctrl+Alt+F4 { spawn "/run/wrappers/bin/chvt" "4"; }
        Ctrl+Alt+F5 { spawn "/run/wrappers/bin/chvt" "5"; }
        Ctrl+Alt+F6 { spawn "/run/wrappers/bin/chvt" "6"; }
        Ctrl+Alt+F7 { spawn "/run/wrappers/bin/chvt" "7"; }

        Alt+Return  { spawn "${pkgs.ghostty}/bin/ghostty"; }
        Alt+D       { spawn "${pkgs.walker}/bin/walker"; }
        Alt+Shift+E { spawn "${pkgs.wlogout}/bin/wlogout"; }
        Alt+N      { spawn "${pkgs.mako}/bin/makoctl" "dismiss"; }
        Alt+Shift+N { spawn "${pkgs.mako}/bin/makoctl" "dismiss" "-a"; }

        XF86AudioRaiseVolume allow-when-locked=true {
            spawn "${pkgs.pulseaudio}/bin/pactl" "set-sink-volume" "@DEFAULT_SINK@" "+5%";
        }
        XF86AudioLowerVolume allow-when-locked=true {
            spawn "${pkgs.pulseaudio}/bin/pactl" "set-sink-volume" "@DEFAULT_SINK@" "-5%";
        }
        XF86AudioMute allow-when-locked=true {
            spawn "${pkgs.pulseaudio}/bin/pactl" "set-sink-mute" "@DEFAULT_SINK@" "toggle";
        }
        XF86AudioMicMute allow-when-locked=true {
            spawn "${pkgs.pulseaudio}/bin/pactl" "set-source-mute" "@DEFAULT_SOURCE@" "toggle";
        }
        XF86MonBrightnessUp allow-when-locked=true {
            spawn "${iab}/bin/iio_ambient_brightness" "--increase" "10";
        }
        XF86MonBrightnessDown allow-when-locked=true {
            spawn "${iab}/bin/iio_ambient_brightness" "--decrease" "10";
        }

        XF86SelectiveScreenshot { spawn "${screenshotRegion}"; }
        Print                   { spawn "${screenshotFull}"; }
    }

    window-rule {
        match app-id="pavucontrol"
        open-floating true
        default-column-width { fixed 700; }
    }

    window-rule {
        match app-id="org.gnome.Calculator"
        open-floating true
    }

    window-rule {
        match app-id="nm-connection-editor"
        open-floating true
    }

    window-rule {
        match app-id="blueberry.py"
        open-floating true
    }

  '';

  # Waybar styled to match the eww bar's Tokyo Night Storm OLED theme
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "niri/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
          "network"
          "disk"
          "memory"
          "cpu"
          "pulseaudio"
          "backlight"
          "battery"
          "custom/power"
        ];
        "niri/workspaces" = {
          format = "{index}";
        };
        clock = {
          format = "{:%a %m/%d %I:%M %p}";
          interval = 10;
        };
        cpu = {
          format = "󰻠 {usage}%";
          interval = 2;
        };
        memory = {
          format = "󰍛 {percentage}%";
          interval = 5;
        };
        disk = {
          format = "󰋊 {percentage_used}%";
          interval = 60;
          path = "/";
        };
        network = {
          interface = "wlo1";
          format-wifi = "󰤨 {essid}";
          format-disconnected = "󰤭 N/A";
          tooltip-format-wifi = "↓{bandwidthDownBits} ↑{bandwidthUpBits}  {signalStrength}%";
          interval = 5;
        };
        pulseaudio = {
          format = "󰕾 {volume}%";
          format-muted = "󰖁 {volume}%";
          on-click = "${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
          on-click-right = "${pkgs.pavucontrol}/bin/pavucontrol";
          scroll-step = 5;
        };
        backlight = {
          format = "󰛨 {percent}%";
          device = "intel_backlight";
          interval = 2;
        };
        battery = {
          bat = "BAT0";
          format = "{icon} {capacity}%";
          format-charging = "󰂄 {capacity}%";
          format-icons = [
            "󰂃"
            "󰁺"
            "󰁼"
            "󰁾"
            "󰂀"
            "󰁹"
          ];
          states = {
            warning = 20;
            critical = 10;
          };
          interval = 30;
        };
        tray = {
          icon-size = 16;
          spacing = 4;
        };
        "custom/power" = {
          format = "⏻";
          on-click = "${pkgs.wlogout}/bin/wlogout";
          tooltip = false;
        };
      };
    };
    style = ''
      /* Tokyo Night Storm OLED */
      @define-color bg      #000000;
      @define-color surface #0d0e14;
      @define-color border  #1a1b26;
      @define-color fg      #c0caf5;
      @define-color dim     #565f89;
      @define-color blue    #7aa2f7;
      @define-color cyan    #7dcfff;
      @define-color green   #9ece6a;
      @define-color yellow  #e0af68;
      @define-color orange  #ff9e64;
      @define-color red     #f7768e;
      @define-color purple  #bb9af7;

      * {
        font-family: "MonaspiceNe Nerd Font", "Font Awesome 6 Free Solid";
        font-size: 11px;
        color: @fg;
        border: none;
        border-radius: 0;
        padding: 0;
        margin: 0;
      }

      window#waybar {
        background-color: @bg;
        border-bottom: 1px solid @border;
      }

      .modules-left,
      .modules-right { padding: 2px 4px; }
      .modules-center { padding: 2px; }

      #workspaces button {
        background-color: transparent;
        color: @dim;
        padding: 2px 8px;
        border-radius: 8px;
        min-width: 22px;
      }
      #workspaces button:hover {
        background-color: @border;
        color: @fg;
      }
      #workspaces button.focused,
      #workspaces button.active {
        background-color: @blue;
        color: @bg;
      }

      #clock,
      #cpu,
      #memory,
      #disk,
      #network,
      #pulseaudio,
      #backlight,
      #battery,
      #tray {
        background-color: @surface;
        border-radius: 8px;
        padding: 2px 8px;
        margin: 2px 3px;
        min-height: 22px;
      }

      #cpu        { color: @purple; }
      #memory     { color: @blue;   }
      #disk       { color: @cyan;   }
      #network    { color: @green;  }
      #pulseaudio { color: @yellow; }
      #pulseaudio.muted { color: @dim; }
      #backlight  { color: @orange; }
      #battery.warning  { color: @yellow; }
      #battery.critical { color: @red;    }
      #battery.charging { color: @green;  }

      #custom-power {
        background-color: transparent;
        color: @red;
        padding: 2px 8px;
        border-radius: 8px;
        margin: 2px 3px;
        min-height: 22px;
      }
      #custom-power:hover {
        background-color: @red;
        color: @bg;
      }
    '';
  };
}
