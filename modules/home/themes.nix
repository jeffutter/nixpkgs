{ pkgs, ... }:

{
  # Use native tokyonight for richer highlight groups (Stylix base16 is disabled)
  programs.nixvim.colorschemes.tokyonight = {
    enable = true;
    settings.style = "storm";
  };

  stylix = {
    enable = true;
    autoEnable = true;

    # Use Tokyo Night Storm base24 scheme for better syntax highlighting (24 colors vs 16)
    base16Scheme = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/tinted-theming/schemes/spec-0.11/base24/tokyo-night-storm.yaml";
      sha256 = "11wlnac2kf6sgspwmq1726j1v3ayas6drjw83x0siy0m8fi9655m";
    };

    # Dark theme
    polarity = "dark";

    # Font configuration - preserves Monaspace setup
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.monaspace;
        name = "MonaspiceNe Nerd Font";
      };
      sansSerif = {
        package = pkgs.roboto;
        name = "Roboto";
      };
      serif = {
        package = pkgs.roboto;
        name = "Roboto";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 11;
        desktop = 11;
        popups = 11;
        terminal = 9;
      };
    };

    # Cursor configuration
    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    # Opacity settings
    opacity = {
      terminal = 1.0;
      applications = 1.0;
      desktop = 1.0;
      popups = 1.0;
    };

    # targets = {
    #   nixvim = {
    #     enable = true;
    #     plugin = "base16-nvim";
    #     # plugin = "mini.base16";
    #     transparentBackground = {
    #       main = true;
    #       signColumn = true;
    #     };
    #   };
    # };

    # Disable Stylix for Neovim - use native tokyonight.nvim for richer highlighting
    targets.nixvim.enable = false;
  };
}
