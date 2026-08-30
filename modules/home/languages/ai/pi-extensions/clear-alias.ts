/**
 * Aliases /clear to /new (start a fresh session).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function clearAlias(pi: ExtensionAPI) {
  pi.registerCommand("clear", {
    description: "Start a new session (alias for /new)",
    handler: async (_args, ctx) => {
      await ctx.newSession();
    },
  });
}
