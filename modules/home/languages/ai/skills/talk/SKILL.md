---
name: talk
description: Turn spoken-reply voice mode on or off for this session. Replies are read aloud and written to be heard.
disable-model-invocation: true
argument-hint: "[on [kokoro|breeze|higgs|say] | off | status]"
---

Run this one command and nothing else:

`@voice-mode@ set ${CLAUDE_SESSION_ID} $ARGUMENTS`

If the arguments are empty, the command defaults to `on` with the kokoro engine.

Report its one-line output to the user. Do not add anything else to this reply.
