---
title: studio mcp rule
type: seed
status: unverified
owner: team
task: none
updated: 2026-10-14
source: unverified (no written rule found in the repo)
related:
  - ./00-index.md
  - ./rebuild-and-test-rule.md
---

No written Studio MCP rule exists in the repo. This note records the related evidence only.

## Related evidence

- AGENTS.md:58-59 forbids editing scripts inside Studio and requires edit, rebuild, and retest from `src/`.
- `.agents/skills/roblox-tooling/references/full.md:35` warns that MCP-driven Studio edits fight a running Rojo serve and that the winning side must be explicit.
- The claimed rule (read plus Play tests only, no edits through MCP) is unverified. Confirm it with the team before treating it as policy.
