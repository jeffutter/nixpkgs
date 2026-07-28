{ pkgs, ... }:

{
  # Common NixOS configuration
  # Note: nixpkgs.config is set in flake.nix when using home-manager.useGlobalPkgs

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  environment.systemPackages = with pkgs; [
    bash
    killall
  ];

  # Create /bin/bash symlink for scripts that expect it
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
  ];
}
