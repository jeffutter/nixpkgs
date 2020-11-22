{ stdenv, lib, fetchurl }:

let
  pname = "goreleaser";
  version = "0.143.0";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://github.com/goreleaser/goreleaser/releases/download/v${version}/goreleaser_Darwin_x86_64.tar.gz";
    sha256 = "0s75pkpxcvmh4ssfqfcvgkfc48qzp1p9x28il8w15qn0l8kkhw8b";
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
