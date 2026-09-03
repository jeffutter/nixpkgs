{
  lib,
  buildNpmPackage,
  nodejs_22,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "zvec-grep";
  version = "0.2.1";

  src = ./.;

  nodejs = nodejs_22;

  npmDepsHash = "sha256-8HRU+PMNFyrA3GEJ9KTrW2A91rbMvLobYXeKo3cFsjk=";

  dontNpmBuild = true;

  # Several transitive deps (onnxruntime-node, sharp's build fallback,
  # node-llama-cpp) ship install/postinstall scripts that probe for or
  # fetch platform binaries over the network; onnxruntime-node and sharp
  # already vendor prebuilt binaries picked up via normal npm dependency
  # resolution, so skipping lifecycle scripts entirely still leaves those
  # working. node-llama-cpp (an optional dep, used for local-LLM features)
  # won't have its binary fetched, so that feature is unavailable.
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/zvec-grep
    cp -rL node_modules $out/lib/zvec-grep/
    makeWrapper ${nodejs_22}/bin/node $out/bin/zg \
      --add-flags "$out/lib/zvec-grep/node_modules/@zvec/zvec-grep/dist/cli/index.js"
    runHook postInstall
  '';

  meta = {
    description = "Agent-friendly hybrid workspace search across code and non-code content";
    homepage = "https://github.com/zvec-ai/zvec-grep";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
    mainProgram = "zg";
  };
}
