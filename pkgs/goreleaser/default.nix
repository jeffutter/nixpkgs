{ stdenv, lib, fetchurl }:

let
  pname = "goreleaser";
  version = "0.155.0";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://github.com/goreleaser/goreleaser/releases/download/v${version}/goreleaser_Darwin_x86_64.tar.gz";
    sha256 = "0wqhmy59jbx217lp4fpxjx6hapgwv29xys896vjbwp8ixjcimrmc";
  };

  unpackPhase = ''
    mkdir -p $out/bin
    tar -xf $src -C $out/bin goreleaser
  '';

  dontInstall = true;

  meta = with lib; {
    description = "Deliver Go binaries as fast and easily as possible";
    homepage = "https://github.com/goreleaser/goreleaser";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
