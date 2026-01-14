{ pkgs, inputs, ... }:

{
  # Use native tokyonight for richer highlight groups (Stylix base16 is disabled)
  programs.nixvim.colorschemes.tokyonight = {
    enable = true;
    settings = {
      style = "moon";
      styles.comments = { italic = true; };
      on_colors = "function(colors) colors.comment = '#b4bcd0' end";
    };
  };

  stylix = {
    enable = true;
    autoEnable = true;

    # Use Tokyo Night Storm base24 scheme for better syntax highlighting (24 colors vs 16)
    base16Scheme = "${inputs.tinted-theming-schemes}/base24/tokyo-night-storm.yaml";

    polarity = "dark";

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

    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    opacity = {
      terminal = 1.0;
      applications = 1.0;
      desktop = 1.0;
      popups = 1.0;
    };

    # Disable Stylix for Neovim - use native tokyonight.nvim for richer highlighting
    targets.nixvim.enable = false;
  };
}
