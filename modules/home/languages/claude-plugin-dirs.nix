# Local plugin folders for Claude Code: each is linked at ~/.claude/<name> and
# listed in CLAUDE_CODE_PLUGIN_DIRS.
#
# Not programs.claude-code.plugins: that links each entry of a plugin
# separately, and Claude Code rejects a hooks module that resolves outside its
# plugin folder.
{ config, lib, ... }:

let
  dirs = config.jeff.claudePluginDirs;
in
{
  options.jeff.claudePluginDirs = lib.mkOption {
    type = lib.types.attrsOf lib.types.path;
    default = { };
    description = "Claude Code plugin folders, keyed by the name to link them under in ~/.claude.";
  };

  config = lib.mkIf (dirs != { }) {
    home.file = lib.mapAttrs' (
      name: source: lib.nameValuePair ".claude/${name}" { inherit source; }
    ) dirs;

    programs.claude-code.settings.env.CLAUDE_CODE_PLUGIN_DIRS = lib.concatMapStringsSep ":" (
      name: "${config.home.homeDirectory}/.claude/${name}"
    ) (lib.attrNames dirs);
  };
}
