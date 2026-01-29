{
  lib,
  ...
}:

{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      kubernetes.context_aliases = {
        "gke_[\\\\w]+-prod[\\\\w-]+_scorebet-(?P<cluster>[\\\\w-]+)" = "PROD $cluster PROD";
        "gke_s[\\\\w]+-[\\\\w-]+_scorebet-(?P<cluster>[\\\\w-]+)" = "$cluster";
      };
      format = lib.strings.replaceStrings [ "\n" ] [ "" ] ''
        ''${custom.hostname_info}
        $shlvl
        ''${custom.kube_info}
        $directory
        ''${custom.git_info}
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
        $conda
        $memory_usage
        $env_var
        $cmd_duration
        $lua
        $jobs
        $battery
        $time
        $status
        $character
      '';
      aws.symbol = " ";
      battery.full_symbol = "";
      battery.charging_symbol = "";
      battery.discharging_symbol = "";
      conda.symbol = " ";
      dart.symbol = " ";
      docker_context.symbol = " ";
      elixir.symbol = " ";
      elixir.format = "[$symbol($version \\(OTP $otp_version\\))]($style) ";
      elm.symbol = " ";
      custom.git_info = {
        command = ''
          branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
          if [ -n "$branch" ]; then
            ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
            behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)
            staged=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
            dirty=$(git status --porcelain 2>/dev/null | grep -c "^.[MD]" || echo 0)

            output=" $branch"
            [ "$ahead" -gt 0 ] && output="$output ↑$ahead"
            [ "$behind" -gt 0 ] && output="$output ↓$behind"
            [ "$staged" -gt 0 ] && output="$output ●$staged"
            echo "$output"
          fi
        '';
        when = "test -z \"$TMUX\" && git rev-parse --git-dir > /dev/null 2>&1";
        format = "[$output]($style) ";
        style = "bold purple";
      };
      git_branch.disabled = true;
      git_commit.disabled = true;
      git_state.disabled = true;
      git_status.disabled = true;
      golang.symbol = " ";
      golang.format = "[$symbol($version )]($style) ";
      # haskell.symbol = " ";
      hg_branch.symbol = " ";
      kubernetes.disabled = true;
      custom.kube_info = {
        command = ''
          context=$(kubectl config current-context 2>/dev/null)
          if [[ -z "$context" ]]; then exit 0; fi

          # Apply aliases (matching original starship patterns)
          if [[ "$context" =~ ^gke_[a-zA-Z0-9_]+-prod[a-zA-Z0-9_-]+_scorebet-(.+)$ ]]; then
            display="PROD ''${BASH_REMATCH[1]} PROD"
          elif [[ "$context" =~ ^gke_s[a-zA-Z0-9_]+-[a-zA-Z0-9_-]+_scorebet-(.+)$ ]]; then
            display="''${BASH_REMATCH[1]}"
          else
            display="$context"
          fi

          # Add namespace if set
          ns=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
          if [[ -n "$ns" && "$ns" != "default" ]]; then
            display="$display ($ns)"
          fi

          echo "☸ $display"
        '';
        when = "test -z \"$TMUX\" && command -v kubectl > /dev/null && kubectl config current-context > /dev/null 2>&1";
        format = "[$output]($style) ";
        style = "bold cyan";
      };
      java.symbol = " ";
      java.format = "[$symbol($version )]($style) ";
      julia.symbol = " ";
      julia.format = "[$symbol($version )]($style) ";
      memory_usage.symbol = " ";
      nim.symbol = " ";
      nix_shell.disabled = true;
      hostname.disabled = true;
      custom.hostname_info = {
        command = "hostname -s";
        when = "test -z \"$TMUX\"";
        format = "[$output]($style) ";
        style = "bold yellow";
      };
      nodejs.symbol = " ";
      nodejs.format = "[$symbol($version )]($style) ";
      package.symbol = " ";
      perl.symbol = " ";
      perl.format = "[$symbol($version )]($style) ";
      php.symbol = " ";
      php.format = "[$symbol($version )]($style) ";
      python.symbol = " ";
      python.format = "[$symbol($version )]($style) ";
      ruby.symbol = " ";
      ruby.format = "[$symbol($version )]($style) ";
      rust.symbol = " ";
      rust.format = "[$symbol($version )]($style) ";
      swift.symbol = " ";
      swift.format = "[$symbol($version )]($style) ";
      erlang.symbol = " ";
      erlang.format = "[$symbol($version )]($style) ";
      kotlin.symbol = " ";
      kotlin.format = "[$symbol($version )]($style) ";
      nim.format = "[$symbol($version )]($style) ";
      terraform.symbol = " ";
      terraform.format = "[$symbol$workspace]($style) ";
      docker_context.format = "[$symbol$context]($style) ";
      helm.symbol = "⎈ ";
      helm.format = "[$symbol($version )]($style) ";
      cmake.symbol = " ";
      cmake.format = "[$symbol($version )]($style) ";
      buf.symbol = " ";
      buf.format = "[$symbol($version )]($style) ";
      c.symbol = " ";
      c.format = "[$symbol($version )]($style) ";
      username.disabled = true;
    };
  };
}
