---
id: hm-12ru
status: open
deps: []
links: []
created: 2026-02-15T01:37:28Z
type: task
priority: 3
assignee: Jeffery Utter
tags: [needs-plan]
---
# Create waylandWrapper helper for Electron app wrappers

Current home.nix (lines 737-752) has two nearly identical Electron app wrapper scripts:
- bin/discord
- bin/obsidian

Both set Ozone/Wayland flags. Create a reusable  function to reduce duplication and make it easier to add more wrapped apps.

Example pattern:


## Acceptance Criteria

- Create waylandWrapper helper function
- Refactor discord wrapper to use helper
- Refactor obsidian wrapper to use helper  
