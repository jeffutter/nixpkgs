{ stdenv, lib, fetchurl }:

let
  pname = "k9s";
  version = "0.24.1";
in

stdenv.mkDerivation {
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://github.com/derailed/k9s/releases/download/v${version}/k9s_Darwin_x86_64.tar.gz";
    sha256 = "1p8zzrbi8565664jcjyihgzvgx46whil2ljml38crz79riv8px55";
  };

  unpackPhase = ''
    mkdir -p $out/bin
    tar -xf $src -C $out/bin k9s 
  '';

  dontInstall = true;

  meta = with lib; {
    description = "Kubernetes CLI To Manage Your Clusters In Style!";
    homepage = "https://github.com/derailed/k9s";
    license = licenses.mit;
    platforms = platforms.darwin;
    hydraPlatforms = [];
  };
}
