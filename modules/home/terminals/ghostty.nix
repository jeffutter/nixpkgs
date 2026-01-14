{ ... }:

{
  programs.ghostty = {
    settings = {
      shell-integration-features = "no-cursor";
      # Stylix handles: font-family (Neon), font-size, theme/colors
      # Use Radon for italic variants
      font-family-italic = "MonaspiceRn Nerd Font";
      font-family-bold-italic = "MonaspiceRn Nerd Font";
      font-thicken = false;
      font-feature = [
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
      window-decoration = false;
      macos-titlebar-style = "hidden";
      cursor-style-blink = false;
    };
  };
}
