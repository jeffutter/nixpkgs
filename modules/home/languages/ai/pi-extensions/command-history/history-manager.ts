import { readFileSync, writeFileSync, existsSync, readdirSync } from "fs";
import { join } from "path";

const HISTORY_FILE = join(process.env.HOME || "", ".pi", "agent", "command-history.json");
const MAX_ENTRIES = 1000;

interface HistoryEntry {
  timestamp: number;
  text: string;
  cwd: string;
}

export class HistoryManager {
  private entries: HistoryEntry[] = [];

  constructor() {
    this.load();
  }

  /** Load history from disk */
  private load(): void {
    try {
      if (existsSync(HISTORY_FILE)) {
        const data = readFileSync(HISTORY_FILE, "utf8");
        this.entries = JSON.parse(data);
        // Keep only the most recent MAX_ENTRIES
        if (this.entries.length > MAX_ENTRIES) {
          this.entries = this.entries.slice(-MAX_ENTRIES);
        }
      }
    } catch (err) {
      console.error("Failed to load command history:", err);
      this.entries = [];
    }
  }

  /** Save history to disk */
  private save(): void {
    try {
      const dir = join(process.env.HOME || "", ".pi", "agent");
      writeFileSync(HISTORY_FILE, JSON.stringify(this.entries, null, 2));
    } catch (err) {
      console.error("Failed to save command history:", err);
    }
  }

  /** Add a new entry */
  add(text: string, cwd: string): void {
    if (!text.trim()) return;
    
    // Don't add duplicates of the last entry
    if (this.entries.length > 0 && this.entries[this.entries.length - 1]!.text === text) {
      return;
    }

    this.entries.push({
      timestamp: Date.now(),
      text,
      cwd,
    });

    // Keep only MAX_ENTRIES
    if (this.entries.length > MAX_ENTRIES) {
      this.entries = this.entries.slice(-MAX_ENTRIES);
    }

    this.save();
  }

  /** Get all entries in reverse chronological order (newest first) */
  getAll(): HistoryEntry[] {
    return [...this.entries].reverse();
  }

  /** Get all entries in chronological order (oldest first) */
  getAllChronological(): HistoryEntry[] {
    return [...this.entries];
  }

  /** Search entries by text (case-insensitive) */
  search(query: string): HistoryEntry[] {
    const lower = query.toLowerCase();
    return this.entries
      .filter((e) => e.text.toLowerCase().includes(lower))
      .reverse();
  }

  /** Get entries for a specific cwd */
  getByCwd(cwd: string): HistoryEntry[] {
    return this.entries
      .filter((e) => e.cwd === cwd)
      .reverse();
  }
}
