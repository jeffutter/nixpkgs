{
  pkgs,
  inputs,
  config,
  ...
}:

let
  c = config.lib.stylix.colors.withHashtag;
  hunkConfig = (pkgs.formats.toml { }).generate "hunk-config.toml" {
    theme = "stylix";
    # Diff tints stay on the tokyo-night base; the Stylix palette has no tint slots.
    themes.stylix = {
      base = "tokyo-night";
      background = c.base00;
      contextBg = c.base00;
      contextContentBg = c.base00;
      panel = c.base10;
      panelAlt = c.base11;
      border = c.base03;
      accent = c.base0D;
      accentMuted = c.base02;
      text = c.base05;
      muted = c.base04;
      addedSignColor = c.base0B;
      removedSignColor = c.base0F;
      badgeAdded = c.base0B;
      badgeRemoved = c.base0F;
      badgeNeutral = c.base0A;
      fileNew = c.base0B;
      fileDeleted = c.base0F;
      fileRenamed = c.base0E;
      fileModified = c.base0D;
      fileUntracked = c.base0C;
      lineNumberBg = c.base00;
      lineNumberFg = c.base03;
      selectedHunk = c.base0A;
      noteBorder = c.base0D;
      noteBackground = c.base10;
      noteTitleBackground = c.base02;
      noteTitleText = c.base05;
    };
  };
in
{
  xdg.configFile."hunk/config.toml".source = hunkConfig;

  # Use native tokyonight for richer highlight groups (Stylix base16 is disabled)
  programs.nixvim.colorschemes.tokyonight = {
    enable = true;
    settings = {
      style = "moon";
      styles.comments = {
        italic = true;
      };
      on_colors = "function(colors) colors.comment = '#b4bcd0' end";
    };
  };

  stylix = {
    enable = true;
    autoEnable = true;

    # We track stylix master against nixpkgs-unstable; the versions report
    # 26.11 vs 26.05 respectively, which is expected. Skip the release check.
    enableReleaseChecks = false;

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

  # Stylix sets home.pointerCursor.package/name/size but not .enable, and only
  # does so on Linux. home.pointerCursor itself is a Linux-only module, so gate
  # .enable to Linux to keep the Darwin build from demanding an unset .name.
  home.pointerCursor.enable = pkgs.stdenv.hostPlatform.isLinux;
}
