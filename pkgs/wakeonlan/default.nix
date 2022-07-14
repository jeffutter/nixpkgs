{ stdenv, lib, fetchFromGitHub, rustPlatform }:

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
    sha256 = "sha256-+MneuHxLWOgf0MnRh5YH3aeV3UJ+GI+02BnczZdmYbU=";
  };
    
  cargoSha256 = "sha256-mI7BlT96mxRT21G3MyJbxu4z7t0/acSzLv/TPbD40y8=";

  meta = with lib; {
    description = "Simple wake-on-lan program written in Rust";
    homepage = "https://github.com/jeffutter/wakeonlan-rust";
    license = licenses.asl20;
    platforms = platforms.unix;
    hydraPlatforms = [];
  };
}
