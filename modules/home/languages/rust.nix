{
  pkgs,
  inputs,
  ...
}:

{
  home.packages = with pkgs; [
    cargo
    cargo-bloat
    cargo-criterion
    cargo-cross
    cargo-expand
    cargo-flamegraph
    cargo-generate
    cargo-llvm-lines
    cargo-outdated
    cargo-watch
    cargo-workspaces
    cargo-udeps
    clippy
    rust-analyzer
    rustc
    rustfmt
    sqlx-cli
  ];

  programs.nixvim = {
    lsp.servers.rust_analyzer.enable = true;

    lsp.keymaps = [
      {
        mode = "n";
        key = "<leader>Rr";
        action = "<cmd>RustLsp runnables<CR>";
        options.desc = "Rust Runnables";
      }
      {
        mode = "n";
        key = "<leader>dR";
        action = "<cmd>RustLsp debuggables<CR>";
        options.desc = "Rust Debuggables";
      }
      {
        mode = "n";
        key = "<leader>Ra";
        action = "<cmd>RustLsp codeAction<CR>";
        options.desc = "Code Action (Rust)";
      }
      {
        mode = "n";
        key = "<leader>Rh";
        action = "<cmd>RustLsp hover actions<CR>";
        options.desc = "Hover Actions (Rust)";
      }
      {
        mode = "n";
        key = "<leader>Rm";
        action = "<cmd>RustLsp expandMacro<CR>";
        options.desc = "Expand Macro";
      }
      {
        mode = "n";
        key = "<leader>RM";
        action = "<cmd>RustLsp rebuildProcMacros<CR>";
        options.desc = "Rebuild Proc Macros";
      }
      {
        mode = "n";
        key = "<leader>Rd";
        action = "<cmd>RustLsp openDocs<CR>";
        options.desc = "Open Docs";
      }
      {
        mode = "n";
        key = "<leader>Rc";
        action = "<cmd>RustLsp openCargo<CR>";
        options.desc = "Open Cargo.toml";
      }
      {
        mode = "n";
        key = "<leader>Rg";
        action = "<cmd>RustLsp crateGraph<CR>";
        options.desc = "Crate Graph";
      }
    ];

    plugins.rustaceanvim.enable = true;
    plugins.neotest.adapters.rust.enable = true;

    plugins.treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      rust
      toml
    ];
  };
}
