{
  theme,
  fonts,
  ...
}:

{
  programs.kitty = {
    enable = true;
    extraConfig = fonts.kitty.featureConfig + builtins.readFile theme.kitty;
    settings = {
      font_family = fonts.kitty.regular;
      bold_font = fonts.kitty.bold;
      bold_italic_font = fonts.kitty.boldItalic;
      italic_font = fonts.kitty.italic;

      macos_titlebar_color = "background";
      tab_bar_style = "powerline";
      macos_colorspace = "default";
      draw_minimal_borders = "yes";
      hide_window_decorations = "titlebar-and-corners";

      dynamic_background_opacity = "yes";
      background_blur = "33";
    };
  };
}
