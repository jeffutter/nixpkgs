{ ... }:

let
in
{
  targets.darwin.defaults."com.apple.dock" = {
    size-immutable = true;
    tilesize = 48;
  };

  programs.ghostty = {
    enable = true;
  };

  programs.aerospace = {
    enable = true;
    userSettings = {
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;
      accordion-padding = 30;
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
      on-focus-changed = [ "move-mouse window-lazy-center" ];
      on-window-detected = [
        {
          "if" = {
            app-id = "com.mitchellh.ghostty";
          };
          run = "move-node-to-workspace 1";
        }
        {
          "if" = {
            app-id = "app.zen-browser.zen";
          };
          run = "move-node-to-workspace 1";
        }
        {
          "if" = {
            app-id = "com.tinyspeck.slackmacgap";
          };
          run = "move-node-to-workspace 2";
        }
        {
          "if" = {
            app-id = "com.apple.MobileSMS";
          };
          run = "move-node-to-workspace 2";
        }
        {
          "if" = {
            app-id = "com.hnc.Discord";
          };
          run = "move-node-to-workspace 2";
        }
        {
          "if" = {
            app-id = "com.apple.mail";
          };
          run = "move-node-to-workspace 3";
        }
        {
          "if" = {
            app-id = "com.fastmail.mac.Fastmail";
          };
          run = "move-node-to-workspace 3";
        }
        {
          "if" = {
            app-id = "com.microsoft.Outlook";
          };
          run = "move-node-to-workspace 3";
        }
        {
          "if" = {
            app-id = "com.apple.iCal";
          };
          run = "move-node-to-workspace 4";
        }
      ];
      after-startup-command = [
        "exec-and-forget borders active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0"
      ];
      key-mapping = {
        key-notation-to-key-code = {
          q = "q";
          w = "w";
          f = "e";
          p = "r";
          g = "t";
          j = "y";
          l = "u";
          u = "i";
          y = "o";
          semicolon = "p";
          leftSquareBracket = "leftSquareBracket";
          rightSquareBracket = "rightSquareBracket";
          backslash = "backslash";
          a = "a";
          r = "s";
          s = "d";
          t = "f";
          d = "g";
          h = "h";
          n = "j";
          e = "k";
          i = "l";
          o = "semicolon";
          quote = "quote";
          z = "z";
          x = "x";
          c = "c";
          v = "v";
          b = "b";
          k = "n";
          m = "m";
          comma = "comma";
          period = "period";
          slash = "slash";
        };
      };
      mode = {
        main = {
          binding = {
            cmd-h = [ ];
            cmd-alt-h = [ ];
            alt-enter = "exec-and-forget open -n ~/Applications/Ghostty.app";
            alt-left = "focus left";
            alt-down = "focus down";
            alt-up = "focus up";
            alt-right = "focus right";
            alt-shift-left = "move left";
            alt-shift-down = "move down";
            alt-shift-up = "move up";
            alt-shift-right = "move right";
            alt-shift-cmd-left = "join-with left";
            alt-shift-cmd-down = "join-with down";
            alt-shift-cmd-up = "join-with up";
            alt-shift-cmd-right = "join-with right";
            alt-z = "flatten-workspace-tree";
            alt-f = "fullscreen";
            alt-s = "layout v_accordion";
            alt-w = "layout h_accordion";
            alt-e = "layout tiles horizontal vertical";
            alt-shift-space = "layout floating tiling";
            alt-1 = "workspace 1";
            alt-2 = "workspace 2";
            alt-3 = "workspace 3";
            alt-4 = "workspace 4";
            alt-5 = "workspace 5";
            alt-6 = "workspace 6";
            alt-7 = "workspace 7";
            alt-8 = "workspace 8";
            alt-9 = "workspace 9";
            alt-0 = "workspace 10";
            alt-shift-1 = "move-node-to-workspace 1";
            alt-shift-2 = "move-node-to-workspace 2";
            alt-shift-3 = "move-node-to-workspace 3";
            alt-shift-4 = "move-node-to-workspace 4";
            alt-shift-5 = "move-node-to-workspace 5";
            alt-shift-6 = "move-node-to-workspace 6";
            alt-shift-7 = "move-node-to-workspace 7";
            alt-shift-8 = "move-node-to-workspace 8";
            alt-shift-9 = "move-node-to-workspace 9";
            alt-shift-0 = "move-node-to-workspace 10";
            alt-shift-r = "reload-config";
            alt-r = "mode resize";
          };
        };
        resize = {
          binding = {
            left = "resize width -100";
            up = "resize height +100";
            down = "resize height -100";
            right = "resize width +100";
            equal = "balance-sizes";
            enter = "mode main";
            esc = "mode main";
          };
        };
      };
      gaps = {
        inner = {
          horizontal = 10;
          vertical = 10;
        };
        outer = {
          left = 0;
          bottom = 0;
          top = 0;
          right = 0;
        };
      };
    };
  };
}
