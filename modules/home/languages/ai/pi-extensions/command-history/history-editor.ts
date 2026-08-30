import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { type TUI } from "@earendil-works/pi-tui";

/**
 * HistoryEditor extends CustomEditor to provide cross-session command history.
 * The actual history loading is done in the extension's setEditorComponent factory.
 */
export class HistoryEditor extends CustomEditor {
  constructor(tui: TUI, theme: any, keybindings: any, options?: any) {
    super(tui, theme, keybindings, options);
  }
}
