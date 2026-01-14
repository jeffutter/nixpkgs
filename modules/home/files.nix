{
  ...
}:

{
  home.file."bin/upgrade" = {
    source = ../../bin/upgrade;
    executable = true;
  };

  home.file.".config/warpd/config" = {
    text = ''
      up:f
      down:s
      left:r
      right:t

      grid_activation_key:A-M-g
      activation_key:A-M-c
      hint_activation_key:A-M-x
      grid:b

      grid_up:f
      grid_down:s
      grid_left:r
      grid_right:t

      grid_keys:g j d h

      scroll_up:p
      scroll_down:v

      start:^
      end:$

      cursor_size:10

      exit:z

      indicator: bottomleft
      #indicator: Specifies an optional visual indicator to be displayed while normal mode is active, must be one of: topright, topleft, bottomright, bottomleft, none (default: none).
      #indicator_color: The color of the visual indicator color. (default: #00ff00).
      #indicator_size: The size of the visual indicator in pixels. (default: 12).


      #speed: Pointer speed in pixels/second. (default: 220).
      #speed: 500
      #acceleration: Pointer acceleration in pixels/second^2. (default: 700).
      #acceleration:900

      buttons: m , .
      #buttons: k m .
    '';
  };
}
