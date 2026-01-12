{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    claude-code
    (llm.withPlugins {
      llm-cmd = true;
      llm-jq = true;
    })
    ollama
    shell-gpt
  ];
}
