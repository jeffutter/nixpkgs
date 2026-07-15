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
  version = "0.2.44";

  # Moshi does not publish moshi-hook in nixpkgs, so we repackage the upstream
  # prebuilt release binaries (same artifacts the rjyo/homebrew-moshi tap
  # installs). Both Linux and Darwin builds are statically linked Go binaries,
  # so no patchelf / interpreter handling is needed.
  # `bin/update-moshi-hook` refreshes the version and these hashes.
  sources = {
    "aarch64-darwin" = {
      url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Darwin_arm64.tar.gz";
      hash = "sha256-XmL6wMW2rH6bCJNpBNU5VJKUbQJvxnSUZeegbikdqCY=";
    };
    "x86_64-darwin" = {
      url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Darwin_x86_64.tar.gz";
      hash = "sha256-aa4iDdTKN7r8idHzA8bsf81/IU9EG3jo45JTX0AxsYA=";
    };
    "aarch64-linux" = {
      url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Linux_arm64.tar.gz";
      hash = "sha256-M539UDHmL0NdzyU/c8YpIgYE1rVscPUN6cW87wInTPs=";
    };
    "x86_64-linux" = {
      url = "https://cdn.getmoshi.app/hook/v${version}/moshi-hook_Linux_x86_64.tar.gz";
      hash = "sha256-4WEmjK4K9j6/SKdL/OwT+Id8reX0xAXLpuQ2/OGIs6k=";
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

  # `moshi-hook install` renders the Claude Code hook JSON and the pi
  # extension script from templates that embed its own store path. Capture
  # that output at build time (fully offline, runs against the binary this
  # derivation just produced) instead of hand-transcribing generated code, so
  # it stays byte-for-byte in sync with whatever version is pinned above.
  # Consumed by modules/home/languages/ai.nix, which can't run `moshi-hook
  # install` itself at activation time since programs.claude-code owns
  # ~/.claude/settings.json as a read-only Nix store symlink.
  passthru.agentConfigs =
    runCommand "moshi-hook-agent-configs-${version}"
      {
        nativeBuildInputs = [ jq ];
      }
      ''
        export HOME=$(mktemp -d)
        ${finalAttrs.finalPackage}/bin/moshi-hook install --target claude,pi
        mkdir -p $out
        cp "$HOME/.pi/agent/extensions/moshi-hooks.ts" $out/pi-extension.ts
        jq '.hooks' "$HOME/.claude/settings.json" > $out/claude-hooks.json
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
