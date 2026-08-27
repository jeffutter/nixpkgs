{ ... }:

let
  # Boxes on the home LAN. These get reinstalled often enough that their host
  # keys churn, so host-key checking is relaxed for them — specifically, and
  # deliberately not globally: a global `StrictHostKeyChecking no` also covers
  # GitHub and work hosts, where it removes the only defence against a MITM.
  lanHosts = {
    homelab = {
      hostName = "192.168.10.4";
      user = "root";
    };
    workstation = {
      hostName = "192.168.10.5";
      user = "jeffutter";
    };
    work = {
      hostName = "192.168.10.6";
      user = "Jeffery.Utter";
    };
    laptop = {
      hostName = "192.168.10.9";
      user = "jeffutter";
    };
    ns1 = {
      hostName = "192.168.10.11";
      user = "root";
    };
    zenbook = {
      hostName = "192.168.10.12";
      user = "jeffutter";
    };
    spark = {
      hostName = "192.168.10.14";
      user = "jeffutter";
    };
    mbp16 = {
      hostName = "192.168.10.16";
      user = "jeffutter";
    };
    llm = {
      hostName = "192.168.10.17";
      user = "root";
    };
  };

  mkLanHost =
    _name:
    { hostName, user }:
    {
      HostName = hostName;
      User = user;
      ForwardAgent = true;
      RequestTTY = "yes";
      # Scoped host-key relaxation; see the lanHosts comment above.
      StrictHostKeyChecking = "no";
      UserKnownHostsFile = "/dev/null";
      # Without this the two settings above print a warning banner on every
      # connection.
      LogLevel = "ERROR";
    };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraOptionOverrides = {
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes";
      AddKeysToAgent = "yes";
    };
    settings = builtins.mapAttrs mkLanHost lanHosts // {
      "* !github.com-penn-interactive" = {
        IdentityFile = "~/.ssh/id_ed25519";
      };
    };
  };
}
