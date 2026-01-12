{
  lib,
  ...
}:

{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      kubernetes.context_aliases = {
        "gke_[\\\\w]+-prod[\\\\w-]+_scorebet-(?P<cluster>[\\\\w-]+)" = "PROD $cluster PROD";
        "gke_s[\\\\w]+-[\\\\w-]+_scorebet-(?P<cluster>[\\\\w-]+)" = "$cluster";
      };
      format = lib.strings.replaceStrings [ "\n" ] [ "" ] ''
        $username
        $hostname
        $shlvl
        $kubernetes
        $directory
        $git_branch
        $git_commit
        $git_state
        $git_status
        $hg_branch
        $docker_context
        $buf
        $c
        $cmake
        $elixir
        $erlang
        $golang
        $helm
        $java
        $kotlin
        $nim
        $nodejs
        $ocaml
        $ruby
        $rust
        $terraform
        $zig
        $nix_shell
        $conda
        $memory_usage
        $env_var
        $cmd_duration
        $custom
        $line_break
        $lua
        $jobs
        $battery
        $time
        $status
        $character
      '';
      aws.symbol = " ";
      battery.full_symbol = "";
      battery.charging_symbol = "";
      battery.discharging_symbol = "";
      conda.symbol = " ";
      dart.symbol = " ";
      docker_context.symbol = " ";
      elixir.symbol = " ";
      elm.symbol = " ";
      git_branch.symbol = " ";
      golang.symbol = " ";
      # haskell.symbol = " ";
      hg_branch.symbol = " ";
      kubernetes.disabled = false;
      java.symbol = " ";
      julia.symbol = " ";
      memory_usage.symbol = " ";
      nim.symbol = " ";
      nix_shell.symbol = " ";
      nodejs.symbol = " ";
      package.symbol = " ";
      perl.symbol = " ";
      php.symbol = " ";
      python.symbol = " ";
      ruby.symbol = " ";
      rust.symbol = " ";
      swift.symbol = "ﯣ ";
    };
  };
}
