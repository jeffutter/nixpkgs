{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.screenpipe;
in
{
  options.services.screenpipe = {
    enable = lib.mkEnableOption "screenpipe recording launch agent";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The screenpipe package providing the binary.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "-l"
        "english"
        "--use-system-default-audio"
      ];
      description = "Extra flags passed to `screenpipe record`.";
    };

    keepAlive = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether launchd should restart the service if it exits.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "services.screenpipe currently only supports macOS (launchd).";
      }
    ];

    launchd.agents.screenpipe = {
      enable = true;
      config = {
        ProgramArguments = [
          "${cfg.package}/bin/screenpipe"
          "record"
        ]
        ++ cfg.extraArgs;
        RunAtLoad = true;
        KeepAlive = cfg.keepAlive;
        ProcessType = "Interactive";
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/screenpipe.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/screenpipe.err.log";
      };
    };
  };
}
