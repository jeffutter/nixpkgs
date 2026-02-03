{
  stdenvNoCC,
  inputs,
}:

stdenvNoCC.mkDerivation {
  pname = "ticket";
  version = "unstable";
  src = inputs.ticket;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/bin
    cp ticket $out/bin/ticket
    chmod +x $out/bin/ticket
    ln -s $out/bin/ticket $out/bin/tk
  '';
}
