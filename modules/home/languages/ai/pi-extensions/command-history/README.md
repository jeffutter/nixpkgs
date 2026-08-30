# Command History Extension

This extension adds cross-session command history to pi, similar to Claude Code's behavior where pressing 'up' in a new session shows commands from previous sessions.

## Features

- **Cross-session history**: Commands from all previous sessions are available
- **Native navigation**: Uses pi's built-in up/down arrow navigation in the editor
- **Persistent storage**: History is saved to `~/.pi/agent/command-history.json`
- **Automatic capture**: New commands are automatically added to history
- **Session scanning**: On startup, all existing sessions are scanned to populate history

## How It Works

1. On startup, the extension scans all session files in `~/.pi/agent/sessions/` and extracts user messages
2. These messages are stored in `~/.pi/agent/command-history.json`
3. The history is loaded into pi's editor internal history buffer
4. When you press 'up' in the editor, you can navigate through your command history
5. New commands are automatically added to the history file

## File Structure

```
~/.pi/agent/extensions/command-history/
├── index.ts              # Extension entry point
├── history-manager.ts    # History storage and retrieval
├── history-editor.ts     # Custom editor component
└── README.md             # This file
```

## Configuration

No configuration needed - the extension works out of the box.

## Limitations

- Only captures text-based user messages (not bash commands or tool calls)
- History is limited to the most recent 1000 entries
- Image content in messages is not captured (only text blocks)

## Troubleshooting

If the extension doesn't work:

1. Check that pi auto-discovers extensions: `pi --no-extensions -e ~/.pi/agent/extensions/command-history`
2. Check for errors in the pi startup output
3. Verify the history file exists: `ls -la ~/.pi/agent/command-history.json`
4. Clear the history file to start fresh: `rm ~/.pi/agent/command-history.json`

## Future Enhancements

- Search/filter history with typing
- Per-cwd history filtering
- Configurable history size limit
- Export/import history
- Bash command history (from `!` and `!!` commands)
