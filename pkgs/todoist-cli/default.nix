{
  lib,
  buildNpmPackage,
  nodejs_22,
  makeWrapper,
  autoPatchelfHook,
  libsecret,
  stdenv,
  src,
}:

let
  packageJson = builtins.fromJSON (builtins.readFile (src + "/package.json"));
in
buildNpmPackage {
  pname = "todoist-cli";
  version = packageJson.version;

  inherit src;

  nodejs = nodejs_22;

  npmDepsHash = "sha256-9TtjDsdEYNuzfnh+NEktFVgLqkpzyK/r0kfnPm/f3ZM=";

  # Use --ignore-scripts to block lifecycle hooks (postinstall syncs skills to
  # ~/.claude, which won't work in the Nix sandbox). Run tsc directly instead
  # of via `npm run build` so this flag doesn't suppress the build script.
  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [ libsecret ];

  buildPhase = ''
    runHook preBuild
    ./node_modules/.bin/tsc -p tsconfig.build.json
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    npm prune --omit=dev
    mkdir -p $out/bin $out/lib/todoist-cli $out/share/todoist-cli
    cp -rL node_modules $out/lib/todoist-cli/
    cp -r dist $out/lib/todoist-cli/
    cp package.json $out/lib/todoist-cli/
    makeWrapper ${nodejs_22}/bin/node $out/bin/td \
      --add-flags "$out/lib/todoist-cli/dist/index.js"
    cp -r skills/todoist-cli $out/share/todoist-cli/skill
    runHook postInstall
  '';

  meta = with lib; {
    description = packageJson.description;
    homepage = "https://github.com/Doist/todoist-cli";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "td";
  };
}
