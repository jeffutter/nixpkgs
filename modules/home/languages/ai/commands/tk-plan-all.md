---
description: Plan all unplanned tickets
---

For every ticket that doesn't have the `planned` tag (`tk query '.status == "open" and ((.tags // []) | any(. == "planned") | not)' | jq -r .id`):
- Launch a foreground tk-planner subagent, passing one ticket id as an argument to the agent
