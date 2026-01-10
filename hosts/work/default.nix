# This file was created in whole or in part by generative AI.
{ pkgs, ... }:

{
  imports = [
    ../../modules/darwin/common.nix
  ];

  homebrew.taps = [
    "menubar-apps/menubar-apps"
    "fastrepl/hyprnote"
  ];

  homebrew.casks = [
    "balenaetcher"
    "deskpad"
    "granola"
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
}
