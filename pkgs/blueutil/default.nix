{ stdenv, lib, fetchurl, darwin }:

let
  pname = "blueutil";
  version = "2.6.0";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://github.com/toy/blueutil/archive/v${version}.tar.gz";
    sha256 = "5ba90cdedd886566e1304813891c0f9f6139db67aaf2829a8294973ee3d0b66c";
  };

  preConfigure = "LD=$CC";

  propagatedBuildInputs = with darwin; with apple_sdk.frameworks; [
    libobjc
    cctools
    Foundation
    IOBluetooth
  ];

  buildPhase = ''
    /usr/bin/xcodebuild SDKROOT= SYMROOT=build
  '';

  installPhase = ''
    install -D -m 0555 build/Release/blueutil $out/bin/blueutil
  '';

  sandboxProfile = ''
    (allow file-read* file-write* process-exec mach-lookup)
    ; block homebrew dependencies
    (deny file-read* file-write* process-exec mach-lookup (subpath "/usr/local") (with no-log))
  '';

  meta = with lib; {
    description = "Get/set bluetooth power and discoverable state";
    homepage = "https://github.com/toy/blueutil";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
