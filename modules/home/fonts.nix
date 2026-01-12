{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    font-awesome
    input-fonts
    nerd-fonts.commit-mono
    nerd-fonts.fantasque-sans-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.hasklug
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    nerd-fonts.monaspace
    nerd-fonts.monoid
    nerd-fonts.sauce-code-pro
    roboto
    roboto-mono
  ];

  _module.args.fonts = {
    # Primary font family (Monaspace Neon for regular, Radon for italic)
    name = "Monaspace";

    # Stylistic features to enable
    features = [
      "ss01"
      "ss02"
      "ss03"
      "ss04"
      "ss05"
      "ss06"
      "ss07"
      "ss08"
      "ss09"
      "calt"
      "liga"
    ];

    # Kitty-specific font names
    kitty = {
      regular = "MonaspiceNe Nerd Font Mono";
      bold = "MonaspiceNe Nerd Font Mono Bold";
      italic = "MonaspiceRn Nerd Font Mono Regular";
      boldItalic = "MonaspiceRn Nerd Font Mono Bold";
      # Font feature config for kitty's extraConfig
      featureConfig = ''
        font_features MonoLisaNerdFont-Italic +ss02
        font_features MonoLisaNerdFont-Bold-Italic +ss02
        font_features MonaspiceRnNFM-Italic +ss02
        font_features MonaspiceRnNFM-BoldItalic +ss02
      '';
    };

    # Ghostty-specific font names
    ghostty = {
      regular = "MonaspiceNe NFM";
      bold = "MonaspiceNe NFM Bold";
      italic = "MonaspiceRn NFM Italic";
      boldItalic = "MonaspiceRn NFM Bold Italic";
    };

    # Default size
    size = 11;
  };
}
