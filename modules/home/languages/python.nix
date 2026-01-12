{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    (python3Packages.python.withPackages (
      ps: with ps; [
        pandas
        pyarrow
      ]
    ))
  ];
}
