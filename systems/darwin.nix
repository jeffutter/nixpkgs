{ ... }:

let
in
{
  targets.darwin.defaults."com.apple.dock" = {
    size-immutable = true;
    tilesize = 48;
  };
}
