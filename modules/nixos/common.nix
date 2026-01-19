{ pkgs, ... }:

{
  # Common NixOS configuration
  # Note: nixpkgs.config is set in flake.nix when using home-manager.useGlobalPkgs

  environment.systemPackages = with pkgs; [
    bash
  ];

  # Create /bin/bash symlink for scripts that expect it
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
  ];
}
