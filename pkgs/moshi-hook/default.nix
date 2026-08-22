{
  lib,
  stdenvNoCC,
  fetchurl,
  gnutar,
  gzip,
  runCommand,
  jq,
}:

let
  version = "0.3.0";

  # Moshi does not publish moshi-hook in nixpkgs, so we repackage the upstream
  # prebuilt release binaries (same artifacts the rjyo/homebrew-moshi tap
  # installs). Both Linux and Darwin builds are statically linked Go binaries,
  # so no patchelf / interpreter handling is needed.
  # `bin/update-moshi-hook` refreshes the version and these hashes.
  sources = {
    "aarch64-darwin" = {
      url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Darwin_arm64.tar.gz";
      hash = "sha256-eN1xZLN6u5TdvMwUf0xa8S1HKIr1yPTDhBrLe1jC0l4=";
    };
    "x86_64-darwin" = {
      url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Darwin_x86_64.tar.gz";
      hash = "sha256-q538d78VJbH5Nm4Gx0VVc40+W7CKhdRlffhYYIFb8Q8=";
    };
    "aarch64-linux" = {
      url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Linux_arm64.tar.gz";
      hash = "sha256-hX8oPY4ntqpH8HEgpTSXr26lkCW4yBmin8Aj+tfQIYA=";
    };
    "x86_64-linux" = {
      url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Linux_x86_64.tar.gz";
      hash = "sha256-nKP/WN+CuQkhkeUYVa7TQ1pPbV8yBi0fDuWmaJMEaZA=";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "moshi-hook";
  inherit version;

  src = fetchurl (
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "moshi-hook: unsupported system ${stdenvNoCC.hostPlatform.system}")
  );

  dontUnpack = true;

  nativeBuildInputs = [
    gnutar
    gzip
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    tar -xzf "$src" -C "$out/bin" moshi-hook
    chmod +x "$out/bin/moshi-hook"
    ln -s moshi-hook "$out/bin/moshi"
    runHook postInstall
  '';

  # `moshi-hook install` renders the Claude Code hook JSON, the pi extension
  # script, and the hermes-agent plugin from templates that embed its own
  # store path. Capture that output at build time (fully offline, runs
  # against the binary this derivation just produced) instead of
  # hand-transcribing generated code, so it stays byte-for-byte in sync with
  # whatever version is pinned above. Consumed by
  # modules/home/languages/ai.nix (claude/pi) and by the hermes-agent
  # microvm in the colmena repo (hermes-plugin) -- neither can run
  # `moshi-hook install` itself at activation time since both own their
  # respective config files as read-only/regenerated-on-start artifacts.
  passthru.agentConfigs =
    runCommand "moshi-hook-agent-configs-${version}"
      {
        nativeBuildInputs = [ jq ];
      }
      ''
        export HOME=$(mktemp -d)
        ${finalAttrs.finalPackage}/bin/moshi-hook install --target claude,pi,hermes
        mkdir -p $out
        cp "$HOME/.pi/agent/extensions/moshi-hooks.ts" $out/pi-extension.ts
        jq '.hooks' "$HOME/.claude/settings.json" > $out/claude-hooks.json
        mkdir -p $out/hermes-plugin
        cp "$HOME/.hermes/plugins/moshi-hooks/__init__.py" $out/hermes-plugin/__init__.py
        cp "$HOME/.hermes/plugins/moshi-hooks/plugin.yaml" $out/hermes-plugin/plugin.yaml
      '';

  meta = {
    description = "Portable daemon + CLI that bridges AI coding agents to the Moshi mobile app";
    homepage = "https://getmoshi.app";
    license = lib.licenses.unfree;
    mainProgram = "moshi-hook";
    platforms = lib.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
