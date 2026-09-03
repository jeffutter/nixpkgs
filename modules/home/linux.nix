{
  config,
  lib,
  pkgs,
  ...
}:

let
  moshi-hook = pkgs.callPackage ../../pkgs/moshi-hook { };
  zvec-grep = pkgs.callPackage ../../pkgs/zvec-grep { };
in
{
  home.packages = with pkgs; [
    inotify-tools
  ];

  # Bridges Claude Code/Codex/etc. sessions to the Moshi mobile app over
  # SSH/Mosh. Pair once with `moshi-hook pair --token $MOSHI_PAIRING_TOKEN`;
  # the service just keeps the daemon running.
  systemd.user.services.moshi-hook = {
    Unit = {
      Description = "Moshi Hook daemon (bridges AI coding agents to the Moshi mobile app)";
    };
    Service = {
      ExecStart = "${moshi-hook}/bin/moshi-hook serve";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Keeps the zvec-grep MCP daemon (`zg server run`) running so agents can
  # reach it at http://127.0.0.1:7999/mcp (registered in ai.nix's
  # programs.mcp.servers). `zg server run` is the foreground form meant for
  # process supervisors, as opposed to `zg server on`, which self-daemonizes.
  systemd.user.services.zvec-grep = lib.mkIf config.jeff.enableZvecGrep {
    Unit = {
      Description = "zvec-grep MCP server (agent-friendly hybrid workspace search)";
    };
    Service = {
      ExecStart = "${zvec-grep}/bin/zg server run";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
