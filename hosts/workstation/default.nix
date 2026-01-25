{
  config,
  modulesPath,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # home-manager is configured via flake.nix
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../modules/nixos/common.nix
    ../../modules/common/cachix.nix
    ../../modules/common/i18n.nix
  ];
  networking.hostName = "workstation";
  nix.settings = {
    sandbox = false;
  };
  proxmoxLXC = {
    manageNetwork = false;
    privileged = true;
  };
  security.pam.services.sshd.allowNullPassword = true;
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PermitEmptyPasswords = "yes";
    };
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      8000
      8001
      8002
      8003
      8080
      1234
      1235
    ];
    allowedUDPPortRanges = [
    ];
  };
  users.users.jeffutter = {
    isNormalUser = true;
    description = "Jeffery Utter";
    extraGroups = [
      "wheel"
    ];
    shell = pkgs.fish;
    packages = with pkgs; [ ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGRSPQqrbR3xi5akobXm7C1D0Nh/O4CFF8FBzefHJ2ia jeff@jeffutter.com" # Zenbook
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdcZzshajKcShGRcADGbH2V3Dzjv+C65imbg2/B6gkh jeffery.utter" # Work
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFkj8dAsJdep7a3LWx2mETXV5OXzoPVXcPU3e3zCoUhCqmMhB8hdCwMJjLXYfbinujAe7idPwWB0BPywrVHjaQBxSSRtLVdzCMBKBCrblAig/KXF9y96crtAH/Z4lk8Xmh1hEMDFTIHrAfNgXNKQccNUB9z77jFUjJEypSksUc/2A3a0aWJWkBvALsYiYQ5vBDyGPHr6WGr3+fVNZMtWcjx3rRJHF00c48NXLOLTsqRcHYYJt4q2xzFnPCjr+r+iaUqodu30edu9KlJlO4kQZszlQCHz42o7NWSs1qglTr5FbsCZdQnUPGSLXCFsNQ1KGLxGFoMdshTEsaS8iMUSYT jeffutter" # Workstation
    ];
  };

  # home-manager.users.jeffutter is configured via flake.nix

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    file
    ripgrep
  ];
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
  system.stateVersion = "25.05";
}
