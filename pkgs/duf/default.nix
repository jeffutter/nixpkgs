{ stdenv, lib, fetchurl }:

let
  pname = "duf";
  version = "0.6.0";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://github.com/muesli/duf/releases/download/v${version}/duf_${version}_Darwin_x86_64.tar.gz";
    sha256 = "1b2vf98a5i3dgyrqsdaf75la6zfdl049fc6wj2ybxzgm4w9ib10a";
  };

  unpackPhase = ''
    mkdir -p $out/bin
    tar -xf $src -C $out/bin duf
  '';

  dontInstall = true;

  meta = with lib; {
    description = "Disk Usage/Free Utility (Linux, BSD & macOS)";
    homepage = "https://github.com/muesli/duf";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
