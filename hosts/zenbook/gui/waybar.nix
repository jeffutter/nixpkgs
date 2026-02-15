{ pkgs, ... }:
{
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
            active = "";
            default = "o";
            persistent = "";
          };
          on-scroll-up = "${pkgs.hyprland}/bin/hyprctl dispatch workspace r-1";
          on-scroll-down = "${pkgs.hyprland}/bin/hyprctl dispatch workspace r+1";
          all-outputs = false;
          persistent_workspaces = {
            "*" = 5;
          };
        };
        tray = {
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
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
        };
        network = {
          format-wifi = "{icon} {essid} ({signalStrength}%)";
          format-ethernet = "{icon} {ifname}= {ipaddr}/{cidr} ";
          format-disconnected = "{icon} Disconnected";
        };
        pulseaudio = {
          scroll-step = 5;
          format = "{icon} {volume}%";
          format-bluetooth = "{icon} {volume}%";
          format-muted = "";
          format-icons = {
            headphones = "";
            handsfree = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [
              ""
              ""
            ];
          };
          on-click = "pavucontrol";
        };
      };
    };
  };
}
