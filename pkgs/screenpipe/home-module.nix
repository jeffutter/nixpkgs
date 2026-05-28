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
    body=$(${pkgs.curl}/bin/curl -fsS --max-time ${toString cfg.watchdog.timeoutSeconds} \
        http://127.0.0.1:3030/health 2>/dev/null) || body=""

    ts=$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)

    if [ -z "$body" ]; then
      echo "$ts /health unreachable; kickstarting ${screenpipeLabel}"
      /bin/launchctl kickstart -k "gui/$(/usr/bin/id -u)/${screenpipeLabel}"
      exit 0
    fi

    status=$(printf '%s' "$body" | ${pkgs.jq}/bin/jq -r '.status // "unknown"')
    audio=$(printf '%s' "$body"  | ${pkgs.jq}/bin/jq -r '.audio_status // "unknown"')
    frame=$(printf '%s' "$body"  | ${pkgs.jq}/bin/jq -r '.frame_status // "unknown"')

    # Overall .status flips to "degraded" for non-fatal reasons like a
    # transcription backlog — restarting in that case wipes the in-memory
    # queue and makes catch-up impossible. Kick only when a specific
    # subsystem reports unhealthy.
    if [ "$audio" = "ok" ] && [ "$frame" = "ok" ]; then
      exit 0
    fi

    echo "$ts unhealthy (status=$status audio=$audio frame=$frame); kickstarting ${screenpipeLabel}"
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
          and kickstarts the main service when it stops being healthy. The
          probe parses /health's JSON body and kicks when either the overall
          status or audio_status is not ok — launchd's KeepAlive only reacts
          to process exit, so a wedged HTTP server or stalled audio thread
          with a live process would otherwise go undetected.
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
