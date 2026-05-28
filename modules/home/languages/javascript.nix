{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    bun
    nodejs
    prettier
    prettierd
    yarn
  ];

  programs.nixvim = {
    lsp.servers = {
      vtsls.enable = true;
      eslint.enable = true;
    };

    plugins.conform-nvim.settings.formatters_by_ft = {
      javascript = [
        "prettierd"
        "prettier"
      ];
      javascriptreact = [
        "prettierd"
        "prettier"
      ];
      typescript = [
        "prettierd"
        "prettier"
      ];
      typescriptreact = [
        "prettierd"
        "prettier"
      ];
    };

    plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      javascript
      jsdoc
      tsx
      typescript
    ];
  };
}
