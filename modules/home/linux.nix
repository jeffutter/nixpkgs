{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    inotify-tools
  ];
}
