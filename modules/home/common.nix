{
  ...
}:

{
  imports = [
    ./theme.nix
    ./fonts.nix
    ./packages.nix
    ./files.nix
    ./email.nix
    ./environment.nix
    ./shells
    ./terminals
    ./editors
    ./vcs
    ./tools
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
