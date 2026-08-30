import { readdirSync, readFileSync, existsSync } from "fs";
import { join } from "path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { HistoryManager } from "./history-manager";
import { HistoryEditor } from "./history-editor";

let historyLoaded = false;

export default function (pi: ExtensionAPI) {
  const historyManager = new HistoryManager();

  // Scan existing sessions to populate history on startup
  pi.on("session_start", async (event, ctx) => {
    if (event.reason === "startup" && !historyLoaded) {
      await scanExistingSessions();
      historyLoaded = true;
    }
  });

  // Capture user messages as they're submitted
  pi.on("input", async (event, ctx) => {
    if (event.source === "interactive" && event.text) {
      historyManager.add(event.text, ctx.sessionManager.getCwd() || "");
    }
  });

  // Set up the custom editor that loads cross-session history
  // The factory captures historyManager in its closure
  pi.on("session_start", (event, ctx) => {
    const editorComponent = (tui: any, theme: any, keybindings: any) => {
      const editor = new HistoryEditor(tui, theme, keybindings, {
        history: historyManager,
      });
      
      // Load history into the editor on startup.
      // We want the editor's history[0] to be the most recent entry,
      // so that pressing 'up' starts from the latest command.
      // addToHistory uses unshift (prepend), so we must iterate
      // oldest-first: the last iterated entry (newest) ends up at index 0.
      if (historyLoaded) {
        // getAllChronological() returns [oldest, ..., newest]
        // slice(-100) gives us the 100 most recent entries
        const entries = historyManager.getAllChronological().slice(-100);
        for (const entry of entries) {
          editor.addToHistory(entry.text);
        }
      }
      
      return editor;
    };
    
    ctx.ui.setEditorComponent(editorComponent);
  });

  // Periodically save history (in case of crash). unref'd so this never
  // keeps a one-shot `pi -p` invocation alive on its own -- it still fires
  // normally for as long as an interactive session is running for other
  // reasons.
  setInterval(() => {
    historyManager.save();
  }, 30000).unref();
}

/** Scan all existing sessions and extract user messages */
async function scanExistingSessions(): Promise<void> {
  try {
    const sessionDir = join(process.env.HOME || "", ".pi", "agent", "sessions");
    if (!existsSync(sessionDir)) return;

    // Read all project directories
    const dirs = readdirSync(sessionDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => join(sessionDir, d.name));

    for (const dir of dirs) {
      try {
        // Read all session files in the directory
        const files = readdirSync(dir)
          .filter((f) => f.endsWith(".jsonl"))
          .map((f) => join(dir, f));

        for (const file of files) {
          try {
            const lines = readFileSync(file, "utf8").trim().split("\n");
            let cwd = "";

            for (const line of lines) {
              const entry = JSON.parse(line);

              if (entry.type === "session") {
                cwd = entry.cwd || "";
              } else if (entry.type === "message" && entry.message?.role === "user") {
                const content = extractUserContent(entry.message.content);
                if (content) {
                  historyManager.add(content, cwd);
                }
              }
            }
          } catch (err) {
            // Skip malformed session files
          }
        }
      } catch (err) {
        // Skip unreadable directories
      }
    }
  } catch (err) {
    console.error("Failed to scan sessions:", err);
  }
}

/** Extract text content from user message */
function extractUserContent(content: any): string {
  if (typeof content === "string") {
    return content;
  }

  if (Array.isArray(content)) {
    return content
      .filter((block) => block.type === "text")
      .map((block) => block.text)
      .join("\n");
  }

  return "";
}
