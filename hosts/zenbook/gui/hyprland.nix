{ pkgs, lib, inputs, ... }:
let
  iab = inputs.iio-ambient-brightness.packages.${pkgs.stdenv.hostPlatform.system}.default;
  singleWindowWorkspaces = [
    "w[t1]"
    "w[tg1]"
    "f[1]"
  ];
in
{
  wayland.windowManager.hyprland = {
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
      ];
      bindl = [
        ", XF86AudioMute, exec, ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle"
        ", XF86AudioMicMute, exec, ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SINK@ toggle"
        ", switch:on:Lid Switch, exec, ${pkgs.hyprland}/bin/hyprctl dispatch dpms off"
        ", switch:off:Lid Switch, exec, ${pkgs.hyprland}/bin/hyprctl dispatch dpms on"
      ];
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

      workspace = map (x: "${x}, gapsout:0, gapsin:0") singleWindowWorkspaces;

      windowrulev2 = lib.concatMap
        (x: [
          "bordersize 0, floating:0, onworkspace:${x}"
          "rounding 0, floating:0, onworkspace:${x}"
        ])
        singleWindowWorkspaces;

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
}
