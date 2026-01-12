{
  ...
}:

{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        email = "jeff@jeffutter.com";
        name = "Jeffery Utter";
      };
      ui = {
        default-command = "log";
      };
    };
  };
}
