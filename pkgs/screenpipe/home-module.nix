{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.screenpipe;

  screenpipeLabel = "org.nix-community.home.screenpipe";

  watchdogScript = pkgs.writeShellScript "screenpipe-watchdog" ''
    set -u
    if ${pkgs.curl}/bin/curl -fsS --max-time ${toString cfg.watchdog.timeoutSeconds} \
        http://127.0.0.1:3030/health >/dev/null 2>&1; then
      exit 0
    fi
    ts=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "$ts /health timed out; kickstarting ${screenpipeLabel}"
    /bin/launchctl kickstart -k "gui/$(/usr/bin/id -u)/${screenpipeLabel}"
  '';
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

    watchdog = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Run a separate launchd agent that probes the screenpipe HTTP API
          and kickstarts the main service when /health stops responding.
          launchd's KeepAlive only reacts to process exit, so a wedged HTTP
          server with a live process would otherwise go undetected.
        '';
      };

      intervalSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 300;
        description = "How often the watchdog probes /health.";
      };

      timeoutSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "Max seconds to wait for /health before considering screenpipe wedged.";
      };
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

    launchd.agents.screenpipe-watchdog = lib.mkIf cfg.watchdog.enable {
      enable = true;
      config = {
        ProgramArguments = [ "${watchdogScript}" ];
        RunAtLoad = false;
        StartInterval = cfg.watchdog.intervalSeconds;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/screenpipe-watchdog.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/screenpipe-watchdog.log";
      };
    };
  };
}
