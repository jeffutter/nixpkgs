{ pkgs, ... }:

{
  imports = [
    ../../modules/darwin/common.nix
    ../../modules/common/cachix.nix
    ../../modules/common/i18n.nix
  ];

  homebrew.taps = [
    "menubar-apps/menubar-apps"
    "fastrepl/hyprnote"
  ];

  homebrew.casks = [
    "balenaetcher"
    "deskpad"
    "intellij-idea-ce"
    "jetbrains-toolbox"
    "pullbar"
    "rode-central"
    "shottr"
    "hyprnote@nightly"
  ];

  homebrew.masApps = {
    "Jira" = 1475897096;
    "Slack" = 803453959;
    "Xcode" = 497799835;
  };

  users.users."jeffery.utter" = {
    name = "jeffery.utter";
    home = "/Users/Jeffery.Utter";
  };

  system.primaryUser = "jeffery.utter";
  nix.settings.trusted-users = [ "jeffery.utter" ];
}
