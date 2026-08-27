{ pkgs, ... }:

{
  # Common NixOS configuration
  # Note: nixpkgs.config is set in flake.nix when using home-manager.useGlobalPkgs

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;

  # crates.io started 403-ing fixed-output derivation fetches whose
  # User-Agent looks like a generic bot (nixpkgs fetchurl's default
  # "curl/<ver> Nixpkgs/<ver>" included, and Python's default
  # "python-requests/<ver>" for fetchCargoVendor). Overriding it here
  # unblocks any crate fetched directly from crates.io (e.g. herdr's
  # vendored deps). Tracked upstream: rust-lang/crates.io#13482.
  nix.envVars.NIX_CURL_FLAGS = "-A nixpkgs-fetchurl/jeffutter-sadclown.net";

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
