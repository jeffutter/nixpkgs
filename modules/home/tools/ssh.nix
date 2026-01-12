{
  lib,
  ...
}:

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
    matchBlocks = {
      "homelab" = {
        host = "homelab";
        hostname = "192.168.10.4";
        user = "root";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "workstation" = {
        host = "workstation";
        hostname = "192.168.10.5";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "work" = {
        host = "work";
        hostname = "192.168.10.6";
        user = "Jeffery.Utter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "old-laptop" = {
        host = "old-laptop";
        hostname = "192.168.10.7";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "borg" = {
        host = "borg";
        hostname = "192.168.10.8";
        user = "borg-backup";
        extraOptions = {
          Ciphers = "3des-cbc";
        };
      };
      "laptop" = {
        host = "laptop";
        hostname = "192.168.10.9";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "ns1" = {
        host = "ns1";
        hostname = "192.168.10.11";
        user = "root";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "zenbook" = {
        host = "zenbook";
        hostname = "192.168.10.12";
        user = "jeffutter";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "llm" = {
        host = "llm";
        hostname = "192.168.10.17";
        user = "root";
        forwardAgent = true;
        extraOptions = {
          RequestTTY = "yes";
        };
      };
      "* !github.com-penn-interactive" = {
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  }
  // lib.optionalAttrs (builtins.compareVersions lib.trivial.release "25.05" <= 0) {
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        forwardAgent = false;
        compression = true;
        addKeysToAgent = "no";
        hashKnownHosts = true;
        userKnownHostsFile = "~/.ssh/known_hosts";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };
}
