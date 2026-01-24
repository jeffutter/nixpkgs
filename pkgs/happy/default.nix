{
  lib,
  buildNpmPackage,
  happy-src,
}:

buildNpmPackage {
  pname = "happy-coder";
  version = "0.14.0-0";

  src = "${happy-src}/cli";

  # Copy the vendored package-lock.json since the project uses yarn
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-IWjHgIoX9Vdsu0R77Ts+l8GNcMHNAN5iGKYst4sQmC8=";

  npmFlags = [ "--ignore-scripts" ];

  # Build phase
  npmBuildScript = "build";

  # Metadata
  meta = with lib; {
    description = "Code on the go — control AI coding agents from your mobile device";
    homepage = "https://github.com/slopus/happy";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
