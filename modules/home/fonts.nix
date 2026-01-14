{ pkgs, ... }:

{
  # Font packages for availability - Stylix handles font configuration
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
}
