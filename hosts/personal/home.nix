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

  programs.git.settings.user.email = "jeff@jeffutter.com";

  programs.ssh.extraOptionOverrides.identityFile = "~/.ssh/id_rsa";

  programs.claude-code.settings.model = "sonnet";
}
