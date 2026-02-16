{ pkgs, inputs, ... }:
let
  iab = inputs.iio-ambient-brightness.packages.${pkgs.stdenv.hostPlatform.system}.default;

  zenbrowser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;

  my_zoom = pkgs.symlinkJoin {
    name = "zoom-us";
    paths = [ pkgs.zoom-us ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zoom --set QT_XCB_GL_INTEGRATION xcb_egl
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

  waylandWrapper =
    {
      pkg,
      bin ? null,
      extraFlags ? "",
      extraEnv ? "",
    }:
    let
      binName = if bin != null then bin else pkg.pname or pkg.name;
    in
    {
      text = ''
        #!${pkgs.bash}/bin/bash
        ${extraEnv}
        exec -a "$0" ~/bin/systemGL ${pkg}/bin/${binName} --ozone-platform=wayland --ozone-platform-hint=auto --enable-features=UseOzonePlatform,WaylandWindowDecorations ${extraFlags} "$@"
      '';
      executable = true;
    };
in
{
  home.packages = with pkgs; [
    _1password-cli
    _1password-gui
    blueberry
    brightnessctl
    clang
    discord
    gnome-power-manager
    iab
    mako
    my_todoist
    my_zoom
    obsidian
    pavucontrol
    slurp
    telegram-desktop
    wayshot
    wl-clipboard
    wlsunset
    wluma
    zenbrowser
    # claude-desktop
  ];

  home.file."wallpapers/hyprlock.jpg".source = ../../../wallpapers/3977823.jpg;

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

      # Stylix handles input-field and label colors
    };
  };

  programs.fuzzel.enable = true;

  programs.ghostty.settings.font-size = 10;

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
    # Stylix handles theme and font
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # Stylix handles pointerCursor

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
    source = ../../../bin/sunset;
    executable = true;
  };

  home.file."bin/discord" = waylandWrapper { pkg = pkgs.discord; };

  home.file."bin/obsidian" = waylandWrapper {
    pkg = pkgs.obsidian;
    extraEnv = "export OBSIDIAN_USE_WAYLAND=1";
  };

  home.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    LIBVA_DRIVERS_PATH = "${pkgs.intel-media-driver}/lib/dri";
    VDPAU_DRIVER = "va_gl";
  };
}
