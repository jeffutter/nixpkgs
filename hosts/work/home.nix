{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  my_google-cloud-sdk = pkgs.google-cloud-sdk.withExtraComponents [
    pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
  ];
  thaw = pkgs.callPackage ../../pkgs/thaw { };
  screenpipe = pkgs.callPackage ../../pkgs/screenpipe { src = inputs.screenpipe-src; };
  pup = pkgs.callPackage ../../pkgs/datadog-pup { };

  # pup captures its embedded Datadog skills (skills/<name>/SKILL.md) and domain
  # subagents (agents/<name>.md) into pup.skills at build time. Enumerate them so
  # every entry is wired without hardcoding the ~60 names. Skills are symlinked
  # by store path (the claude-code module treats path-like strings as skill
  # directories); agents are inlined as text since that option only symlinks
  # true Nix paths, not store-path strings.
  pupSkills = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = "${pup.skills}/skills/${name}";
    }) (builtins.attrNames (builtins.readDir "${pup.skills}/skills"))
  );
  pupAgents = builtins.listToAttrs (
    map (file: {
      name = lib.removeSuffix ".md" file;
      value = builtins.readFile "${pup.skills}/agents/${file}";
    }) (builtins.attrNames (builtins.readDir "${pup.skills}/agents"))
  );
in
{
  imports = [
    ../../modules/home/languages/elixir.nix
    ../../modules/home/languages/rust.nix
    ../../modules/home/languages/go.nix
    ../../modules/home/languages/python.nix
    ../../modules/home/languages/javascript.nix
    ../../modules/home/languages/java.nix
    ../../modules/home/languages/ai.nix
    # ../../pkgs/screenpipe/home-module.nix
  ];

  home.packages = with pkgs; [
    # argocd
    colima
    grpcurl
    llvmPackages.bintools
    my_google-cloud-sdk
    pup
    # screenpipe
    thaw
  ];

  home.file.".ssh/allowed_signers".text = ''
    jeffery.utter@pennentertainment.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPoH8Rk7wSl/PdXDU0s/8F/e0z0/Brl1OdDDuJB7iLYO
  '';

  programs.git =
    let
      mkWorkConfig = dir: {
        condition = "gitdir:${dir}";
        contents = {
          user.email = "jeffery.utter@pennentertainment.com";
          user.signingKey = "~/.ssh/id_ed25519-penn-interactive";
          gpg.format = "ssh";
          gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
          commit.gpgSign = true;
          tag.gpgSign = true;
        };
      };
    in
    {
      includes = [
        (mkWorkConfig "~/theScore/**")
        (mkWorkConfig "~/.claude/plugins/marketplaces/penn-interactive-claude-code")
      ];
      ignores = [
        ".classpath"
        ".factorypath"
        ".project"
        ".settings"
      ];
      settings = {
        url."git@github.com-penn-interactive:penn-interactive/" = {
          insteadOf = "git@github.com:penn-interactive/";
        };
        url."ssh://git@github.com-penn-interactive/penn-interactive/" = {
          insteadOf = "ssh://git@github.com/penn-interactive/";
        };
        url."git@github.com-penn-interactive:Jeffery-Utter_pennent/" = {
          insteadOf = "git@github.com:Jeffery-Utter_pennent/";
        };
        url."ssh://git@github.com-penn-interactive/Jeffery-Utter_pennent/" = {
          insteadOf = "ssh://git@github.com/Jeffery-Utter_pennent/";
        };
      };
    };

  programs.ssh = {
    settings = {
      "github.com-penn-interactive" = {
        HostName = "github.com";
        User = "git";
        AddKeysToAgent = "yes";
        IdentitiesOnly = true;
        IdentityFile = "~/.ssh/id_ed25519-penn-interactive";
      };
    };
  };

  programs.keychain.keys = [ "id_ed25519" ];

  # services.screenpipe = {
  #   enable = true;
  #   package = screenpipe;
  #   extraArgs = [
  #     "-l"
  #     "english"
  #     "--use-system-default-audio"
  #     "-i"
  #     "System Audio (output)"
  #     "--experimental-coreaudio-system-audio"
  #     "--filter-music"
  #   ];
  # };

  programs.claude-code.settings.model = "opus";

  programs.claude-code.skills = {
    screenpipe-api = "${screenpipe.skills}/screenpipe-api";
    screenpipe-cli = "${screenpipe.skills}/screenpipe-cli";
  }
  // pupSkills;

  programs.claude-code.agents = pupAgents;

  jeff.kamiSkillBrand = ./kami/brand.md;

  jeff.enableRtkHooks = false;

  jeff.enableClaudeVoice = true;
}
