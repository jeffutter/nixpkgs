{
  stdenv,
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

let
  pname = "wakeonlan";
  version = "0.1.0";
in

rustPlatform.buildRustPackage rec {
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "jeffutter";
    repo = "wakeonlan-rust";
    rev = "v0.1.0";
    sha256 = "sha256-Ne4ZABsVNunAKoDoLflla5Tp0mMUmP1XHf1ijWRzjGs=";
  };

  cargoHash = "sha256-TMsaxniSES47Y/+/+3Apcw0QWG1diVqjInt3V1DZwN8=";

  meta = with lib; {
    description = "Simple wake-on-lan program written in Rust";
    homepage = "https://github.com/jeffutter/wakeonlan-rust";
    license = licenses.asl20;
    platforms = platforms.unix;
    hydraPlatforms = [ ];
  };
}
