{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraOptionOverrides = {
      StrictHostKeyChecking = "no";
      userKnownHostsFile = "/dev/null";
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes";
      AddKeysToAgent = "yes";
    };
    settings = {
      "homelab" = {
        HostName = "192.168.10.4";
        User = "root";
        ForwardAgent = true;
        RequestTTY = "yes";
      };
      "workstation" = {
        HostName = "192.168.10.5";
        User = "jeffutter";
        ForwardAgent = true;
        RequestTTY = "yes";
      };
      "work" = {
        HostName = "192.168.10.6";
        User = "Jeffery.Utter";
        ForwardAgent = true;
        RequestTTY = "yes";
      };
      "old-laptop" = {
        HostName = "192.168.10.7";
        User = "jeffutter";
        ForwardAgent = true;
        RequestTTY = "yes";
      };
      "borg" = {
        HostName = "192.168.10.8";
        User = "borg-backup";
        Ciphers = "3des-cbc";
      };
      "laptop" = {
        HostName = "192.168.10.9";
        User = "jeffutter";
        ForwardAgent = true;
        RequestTTY = "yes";
      };
      "ns1" = {
        HostName = "192.168.10.11";
        User = "root";
        ForwardAgent = true;
        RequestTTY = "yes";
      };
      "zenbook" = {
        HostName = "192.168.10.12";
        User = "jeffutter";
        ForwardAgent = true;
        RequestTTY = "yes";
      };
      "llm" = {
        HostName = "192.168.10.17";
        User = "root";
        ForwardAgent = true;
        RequestTTY = "yes";
      };
      "* !github.com-penn-interactive" = {
        IdentityFile = "~/.ssh/id_ed25519";
      };
    };
  };
}
