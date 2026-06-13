{
  lib,
  ...
}:

{
  imports = [
    ./themes.nix
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

  # We deliberately track nixpkgs-unstable alongside the master branches of
  # home-manager/nixvim/stylix. nixos-unstable's lib.version currently still
  # reports the just-released number (26.05) while the others report 26.11,
  # so the release-mismatch checks fire on every build. Silence them.
  home.enableNixpkgsReleaseCheck = false;

  # Stylix's home module registers nixpkgs.overlays (nixos-icons, gtksourceview).
  # Under home-manager.useGlobalPkgs (all our hosts) these are ignored — the
  # overlays are applied at the system level instead — but home-manager still
  # warns that setting them "will soon not be possible". Force them null here to
  # drop the dead definitions and silence the warning.
  nixpkgs.config = lib.mkForce null;
  nixpkgs.overlays = lib.mkForce null;
}
