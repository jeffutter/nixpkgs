{
  pkgs,
  inputs,
  ...
}:

let
  fabric = inputs.fabric.packages.${pkgs.stdenv.hostPlatform.system}.default;
in

{
  home.packages = with pkgs; [
    fabric
    claude-code
    (llm.withPlugins {
      llm-cmd = true;
      llm-jq = true;
    })
    ollama
    shell-gpt
  ];
}
