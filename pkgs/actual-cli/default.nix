{
  lib,
  buildNpmPackage,
  nodejs_22,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "actual-cli";
  version = "26.4.0";

  src = ./.;

  nodejs = nodejs_22;

  npmDepsHash = "sha256-ZAMB36jaQqihd9UWXh/FTp5UKG8qeHcjAapnj2hDc9I=";

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/actual-cli
    cp -rL node_modules $out/lib/actual-cli/
    makeWrapper ${nodejs_22}/bin/node $out/bin/actual \
      --add-flags "$out/lib/actual-cli/node_modules/@actual-app/cli/dist/cli.js"
    ln -s $out/bin/actual $out/bin/actual-cli
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI for Actual Budget";
    homepage = "https://actualbudget.org/docs/api/cli/";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "actual";
  };
}
