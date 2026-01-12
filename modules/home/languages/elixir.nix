{
  pkgs,
  inputs,
  ...
}:

let
  expert = inputs.expert.packages.${pkgs.stdenv.hostPlatform.system}.default;
in

{
  home.packages = with pkgs; [
    beamMinimalPackages.elixir
    beamMinimalPackages.erlang
  ];

  programs.nixvim = {
    lsp.servers.expert = {
      enable = true;
      package = expert;
    };

    plugins.neotest.adapters.elixir.enable = true;

    plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      elixir
      erlang
    ];
  };
}
