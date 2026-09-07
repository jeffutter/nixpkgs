{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-agent-acp";
  version = "0.74.0";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "claude-agent-acp";
    tag = "v${version}";
    hash = "sha256-AxGUN8J+Qb7IyT3gzhSOU5FxiStpO5nfb1AFT9/jM3M=";
  };

  npmDepsHash = "sha256-omA6quRuzTwBC9lxvHYRv/HPc8NPUrPlUl/2/ymGKZU=";

  # ACP adapter that runs the Claude Agent SDK (spawns/talks to the SDK
  # in-process) and bridges it over ACP JSON-RPC on stdio — the Claude
  # counterpart to pi-acp, which does the same for the `pi` coding agent.
  meta = {
    description = "ACP-compatible coding agent powered by the Claude Agent SDK";
    homepage = "https://github.com/agentclientprotocol/claude-agent-acp";
    license = lib.licenses.asl20;
    mainProgram = "claude-agent-acp";
  };
}
