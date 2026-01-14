{ ... }:

{
  programs.ghostty = {
    settings = {
      shell-integration-features = "no-cursor";
      # Stylix handles: font-family, font-size, theme/colors
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
