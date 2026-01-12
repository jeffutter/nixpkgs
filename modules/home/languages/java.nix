{
  pkgs,
  inputs,
  ...
}:

{
  home.packages = with pkgs; [
    maven
    google-java-format
  ];

  programs.java = {
    enable = true;
    package = pkgs.jdk;
  };

  programs.nixvim = {
    lsp.servers.jdtls.enable = true;

    plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      java
    ];
  };
}
