{ pkgs, ... }:

{
  imports = [
    ../../modules/darwin/common.nix
    ../../modules/common/cachix.nix
  ];

  homebrew.taps = [
    "atlassian/homebrew-acli"
    "menubar-apps/menubar-apps"
    "fastrepl/hyprnote"
  ];

  homebrew.brews = [
    "acli"
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
