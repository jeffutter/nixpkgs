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
    
  cargoSha256 = "079c7vqacfid4aq50iz3wiagdj7jyxb31whcaszg09w8xrapl8kb";

  meta = with lib; {
    description = "Simple wake-on-lan program written in Rust";
    homepage = "https://github.com/jeffutter/wakeonlan-rust";
    license = licenses.asl20;
    platforms = platforms.unix;
    hydraPlatforms = [];
  };
}
