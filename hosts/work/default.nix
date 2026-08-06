{ config, ... }:

let
  homeDir = config.users.users.${config.system.primaryUser}.home;
in
{
  imports = [
    ../../modules/darwin/common.nix
    ../../modules/common/cachix.nix
  ];

  homebrew.casks = [
    "balenaetcher"
    "beekeeper-studio"
    "deskpad"
    "insta360-link-controller"
    "intellij-idea-ce"
    "jetbrains-toolbox"
    "rode-central"
    "shottr"
  ];

  homebrew.masApps = {
    # "Jira" = 6572290663;
    "Slack" = 803453959;
    "Xcode" = 497799835;
    "pull-bar-pro" = 6462591649;
  };

  # Dock contents. nix-darwin owns this list, so rearranging the Dock by hand
  # gets reverted on the next rebuild — edit here instead.
  system.defaults.dock = {
    persistent-apps = [
      { app = "/System/Applications/Apps.app"; }
      { app = "${homeDir}/Applications/Zen.app"; }
      { app = "${homeDir}/Applications/Ghostty.app"; }
      { app = "/System/Applications/Messages.app"; }
      { app = "/System/Applications/Mail.app"; }
      { app = "/Applications/Slack.app"; }
      { app = "/System/Applications/Calendar.app"; }
      { app = "/System/Applications/Music.app"; }
      { app = "/System/Applications/System Settings.app"; }
    ];

    persistent-others = [
      {
        folder = {
          path = "${homeDir}/Downloads";
          arrangement = "date-added";
          displayas = "stack";
          showas = "fan";
        };
      }
    ];
  };

  users.users."jeffery.utter" = {
    name = "jeffery.utter";
    home = "/Users/Jeffery.Utter";
  };

  system.primaryUser = "jeffery.utter";
  nix.settings.trusted-users = [ "jeffery.utter" ];

  # Match existing Nix installation's GID
  ids.gids.nixbld = 350;
}
