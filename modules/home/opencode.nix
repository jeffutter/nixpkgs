{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.opencode = {
    enable = true;
    settings = {
      provider = {
        "llama.cpp" = {
          npm = "@ai-sdk/openai-compatible";
          name = "llama.cpp";
          options = {
            baseURL = "https://llama.home.jeffutter.com/v1";
          };
          models = {
            "qwen3-coder" = {
              name = "qwen3-coder";
              limit = {
                "context" = 65536;
                "output" = 65536;
              };
            };
            "glm-4.7-flash" = {
              name = "glm-4.7-flash";
              limit = {
                "context" = 65536;
                "output" = 65536;
              };
            };
          };
        };
      };
    };
  };
}
