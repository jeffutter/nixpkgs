/**
 * Ralph worker heartbeat — tiny companion to ralph's index.ts, loaded into each
 * long-running headless worker via `-e` (see RALPH_WORKER_HEARTBEAT_EXTENSION
 * there). Deployed next to index.ts by ai.nix.
 *
 * Why this exists: ralph's phase timeouts kill a step on wall clock alone. A
 * live worker that is merely slow (feature-sized ticket) dies even though it is
 * actively working. The intercom progress pings workers are already instructed
 * to send (`intercomStatusGuidance`) are exactly the liveness signal we want —
 * but they flow through the pi-intercom broker into the ORCHESTRATOR session,
 * and nothing in the orchestrator process fires an event when a ping lands
 * (pi-intercom injects them as custom transcript entries; with inboundTrigger
 * "replies" they don't even trigger a turn). So instead of sniffing the receive
 * side, we record at the send side: whenever this worker calls the intercom
 * tool, touch a heartbeat file in ralph's per-project state dir, which the
 * orchestrator polls while its step subprocess runs and resets the step
 * deadline on change (see execCapture in index.ts).
 *
 * Nonce-scoped path: before launching each step the orchestrator writes
 * { nonce } to <stateDir>/current-step.json. We read that nonce and write
 * <stateDir>/heartbeat-<nonce>.json, so an orphaned process from a previously
 * killed step (known to survive timeout kills — see execCapture's comments in
 * index.ts) can only ever touch a stale-nonce file nobody watches.
 *
 * Everything here is fire-and-forget: any failure (no control file because the
 * worker isn't running under ralph, disk hiccup) degrades silently to "no
 * heartbeat" — the step then simply times out exactly as it would without this
 * extension. This handler must never block or throw: a broken heartbeat must
 * not break the worker's own tool call.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Same convention as index.ts's stateDirFor — duplicated on purpose: this file
// loads standalone inside the worker process and cannot import index.ts (that
// would register the entire loop, widget, and commands in the worker too).
const RALPH_STATE_ROOT = join(homedir(), ".pi", "agent", "ralph");

export default function (pi: ExtensionAPI): void {
  pi.on("tool_call", async (event) => {
    if (event.toolName !== "intercom") return;
    const action = (event.input as { action?: unknown } | undefined)?.action;
    // Only outbound messages count as liveness evidence — `list`/`status`
    // housekeeping does not prove the worker is progressing.
    if (action !== "send" && action !== "ask") return;
    try {
      const stateDir = join(
        RALPH_STATE_ROOT,
        resolve(process.cwd()).replace(/[\\/]/g, "-"),
      );
      const control = JSON.parse(
        readFileSync(join(stateDir, "current-step.json"), "utf8"),
      ) as { nonce?: unknown };
      if (typeof control.nonce !== "string" || !control.nonce) return;
      writeFileSync(
        join(stateDir, `heartbeat-${control.nonce}.json`),
        `${JSON.stringify({ at: new Date().toISOString() })}\n`,
        "utf8",
      );
    } catch {
      // No control file / unreadable / write failed: skip this heartbeat.
    }
  });
}
