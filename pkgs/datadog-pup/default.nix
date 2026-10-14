{
  lib,
  stdenvNoCC,
  fetchurl,
  runCommand,
  gnutar,
  gzip,
}:

let
  version = "1.27.0";

  # Datadog does not publish pup in nixpkgs, so we repackage the upstream
  # prebuilt release binaries. macOS builds are signed by Datadog (they
  # distribute via Homebrew) and the Linux builds are static-pie ELF, so no
  # patchelf / interpreter handling is needed. `bin/update-datadog-pup`
  # refreshes the version and these hashes.
  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/DataDog/pup/releases/download/v${version}/pup_${version}_Darwin_arm64.tar.gz";
      hash = "sha256-VFuhOy1ayYFOXZCUbcOQ7X/7TCnEu5oK+0LGAT/b8Jc=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/DataDog/pup/releases/download/v${version}/pup_${version}_Darwin_x86_64.tar.gz";
      hash = "sha256-w2WbItzeMEblmWQ125Vj1+vIsCTXEG+b6bLnqgmPUn0=";
    };
    "aarch64-linux" = {
      url = "https://github.com/DataDog/pup/releases/download/v${version}/pup_${version}_Linux_arm64.tar.gz";
      hash = "sha256-5JYILZJYqEM7F5phShVQmuBfTndqkiQgH2osoxq6GAE=";
    };
    "x86_64-linux" = {
      url = "https://github.com/DataDog/pup/releases/download/v${version}/pup_${version}_Linux_x86_64.tar.gz";
      hash = "sha256-6Jhh59D+Ic5bx+THIbh7LaNPQJbLDtkIxWh1wyzwW4k=";
    };
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "datadog-pup";
  inherit version;

  src = fetchurl (
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "datadog-pup: unsupported system ${stdenvNoCC.hostPlatform.system}")
  );

  dontUnpack = true;

  nativeBuildInputs = [
    gnutar
    gzip
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    tar -xzf "$src" -C "$out/bin" pup
    chmod +x "$out/bin/pup"
    runHook postInstall
  '';

  # Capture pup's embedded Claude Code skills and domain subagents at build
  # time so home-manager can install them like any other skill. `pup skills
  # install` is fully offline here (skills/agents are compiled into the
  # binary): CLAUDE_CONFIG_DIR redirects the writes into $out, --no-agent
  # keeps output plain, and --yes skips prompts. The prebuilt binary is for
  # hostPlatform == buildPlatform, so running it during the build is safe.
  # Layout: $out/skills/<name>/SKILL.md and $out/agents/<name>.md (native
  # Claude subagent format).
  passthru.skills = runCommand "datadog-pup-skills-${version}" { } ''
    export HOME="$(mktemp -d)"
    export CLAUDE_CONFIG_DIR="$out"
    ${lib.getExe finalAttrs.finalPackage} --no-agent skills install claude --type skill --yes
    ${lib.getExe finalAttrs.finalPackage} --no-agent skills install claude --type agent --yes
  '';

  meta = {
    description = "Datadog Pup CLI: AI-agent-ready command-line wrapper for the Datadog APIs";
    homepage = "https://github.com/DataDog/pup";
    license = lib.licenses.asl20;
    mainProgram = "pup";
    platforms = lib.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
