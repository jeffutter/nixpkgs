{
  ...
}:

{
  accounts.email.accounts = {
    sadclown = {
      primary = true;
      realName = "Jeffery Utter";
      address = "jeffutter@sadclown.net";
      aliases = "jeff@jeffutter.com";
      flavor = "fastmail.com";
      himalaya = {
        enable = true;
      };
      imap = {
        port = 993;
        host = "imap.fastmail.com";
        tls.enable = true;
      };
      smtp = {
        port = 587;
        host = "smtp.fastmail.com";
        tls.enable = true;
        tls.useStartTls = true;
      };
      userName = "jeffutter@sadclown.net";
      passwordCommand = [
        "op"
        "item"
        "get"
        "--account"
        "my.1password.com"
        "'Fastmail (Himalaya)'"
        "--fields"
        "password"
      ];
    };
  };
}
