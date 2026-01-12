{
  theme,
  fonts,
  ...
}:

{
  programs.ghostty = {
    settings = {
      shell-integration-features = "no-cursor";
      font-family = fonts.ghostty.regular;
      font-family-bold = fonts.ghostty.bold;
      font-family-italic = fonts.ghostty.italic;
      font-family-bold-italic = fonts.ghostty.boldItalic;
      font-thicken = false;
      font-size = fonts.size;
      font-feature = fonts.features;
      window-decoration = false;
      macos-titlebar-style = "hidden";

      cursor-style-blink = false;

      theme = theme.ghostty;
    };
  };
}
