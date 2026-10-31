{ linkFarm, yue2-song-skill }:

# Skills shared with Hermes (the colmena repo's hermes VM), as a single
# directory for its read-only `skills.external_dirs`. Hermes' own
# ~/.hermes/skills stays mutable; this is additive. Only skills that run
# without Claude Code specific tooling belong here.
linkFarm "hermes-skills" [
  {
    name = "voice-dna";
    path = ../../modules/home/languages/ai/skills/voice-dna;
  }
  {
    name = "yue2-song";
    path = yue2-song-skill;
  }
]
