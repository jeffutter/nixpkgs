{
  pkgs,
  config,
  inputs,
  ...
}:

let
  m8c = pkgs.callPackage ../../pkgs/m8c { };
in
{
  imports = [
    ../../modules/home/languages/elixir.nix
    ../../modules/home/languages/rust.nix
    ../../modules/home/languages/python.nix
    ../../modules/home/languages/javascript.nix
    ../../modules/home/languages/ai.nix
  ];

  home.packages = with pkgs; [
    # m8c
    llvmPackages.bintools
  ];

  home.file.".ssh/allowed_signers".text = ''
    jeff@jeffutter.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdcZzshajKcShGRcADGbH2V3Dzjv+C65imbg2/B6gkh
  '';

  programs.git.settings = {
    user.email = "jeff@jeffutter.com";
    gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
  };

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_rsa";

  programs.claude-code.settings.model = "sonnet";
}
