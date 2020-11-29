{ stdenv, lib, fetchFromGitHub, rustPlatform }:

let
  pname = "wakeonlan";
  version = "0.0.1"; 
in

rustPlatform.buildRustPackage rec {
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "jeffutter";
    repo = "wakeonlan-rust";
    rev = "f24c357619e958a2fdc5deae289ff532ba1f4551";
    sha256 = "17kikqjysd752dxray8pxmvcw18m1045y4ajl5npmip77wz58fzr";
  };
    
  cargoSha256 = "1n0scdjdgn9npivyi8x5cv8idxshmk3n0qra7za6a7g3v4n1yhhn";

  meta = with lib; {
    description = "Simple wake-on-lan program written in Rust";
    homepage = "https://github.com/jeffutter/wakeonlan-rust";
    license = licenses.asl20;
    platforms = platforms.unix;
    hydraPlatforms = [];
  };
}
