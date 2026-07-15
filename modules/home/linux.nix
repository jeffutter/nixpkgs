{
  pkgs,
  ...
}:

let
  moshi-hook = pkgs.callPackage ../../pkgs/moshi-hook { };
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
}
