---
name: dlp-session-repair
description: Repair a Claude Code session that the DLP scanner killed. Masks the long opaque runs in its log without printing them, gives the user the command to install the clean copy, and writes a prompt that stops the resumed session from repeating the leak. Use when the user says a session "hit a DLP violation", "got killed by the scanner", or asks to strip offending messages from a session.
---

# DLP session repair

The DLP scanner ends a session when a tool result holds a run of about 40 or more
opaque characters. The killed session's log still holds that run, so resuming
it triggers the scanner again. This skill masks every such run in the log and
keeps every record, so the conversation chain and thinking signatures stay valid.

## Rules

- Never read, cat, or grep the session log. Its content is what killed the other
  session. The script prints only line numbers, record types, run counts and the
  masked tool call that produced each run.
- Do not copy the clean file into `~/.claude/projects` yourself. The sandbox and
  the auto-mode classifier block writes there. The user runs the install command.

## Steps

1. Get the session ID from the user. Run:

   ```
   python3 -I ~/.claude/skills/dlp-session-repair/scripts/dlp_repair.py <session-id>
   ```

   It writes `/tmp/claude-502/<session-id>-clean.jsonl` and prints an `install:`
   command that backs up the original and copies the clean file over it.

2. Check the output. `opaque runs left` must be `0`. If not, stop and report it.
   If `changed records` is `0`, the trigger is not a 40-character run. Tell the
   user; do not guess another pattern.

3. Read the `from line N <tool>:` lines. They name the commands whose output held
   the runs. The last one before the session ended is the probable trigger. Mark
   it as probable, not confirmed.

4. Write a prompt for the resumed session. Name each leaking command and the kind
   of field it returned (IDs, hashes, long resource names, titles). Give rules that
   fit those tools:
   - Select only the needed fields. Never print whole records or raw responses.
   - Do not select ID, hash or token fields.
   - For `pup`, `gh` or other tools with `--jq`, end the filter with
     `| walk(if type == "string" then gsub("[A-Za-z0-9+/=_-]{40,}"; "<ID>") else . end)`.
     Do not pipe a sandbox-excluded command into `sed`; the pipe puts it in the
     sandbox and the call fails.
   - Compare long values in code and print only pass or fail.
   - Put these rules in any subagent brief that runs those tools.
   - Before you rerun the probable trigger, add the mask.
   End with "Continue where you stopped."

5. Report to the user, in this order:
   - Which records were masked, and which commands produced them.
   - "Close session `<id>` first", then the `install:` command prefixed with `! `.
   - `claude --resume <id>`, then the prompt in a fenced block.
   - State that you have not verified the resume.
