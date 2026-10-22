---
title: studio mcp rule
type: rule
status: approved
owner: team
task: none
updated: 2026-10-22
source: AGENTS.md
related:
  - ./00-index.md
  - ./rebuild-and-test-rule.md
---

The project owner performs all testing in Roblox Studio. Agents must not run automated tests, playtests, or test fixtures in Studio.

## Rules

- Agents must never invoke `start_stop_play`, `execute_luau`, or `StudioTestService`.
- Agents must never inject temporary test scripts into Studio.
- Studio MCP is limited to read-only metadata inspection when explicitly requested.
- Each code change concludes with syntax checks, a Rojo build, and a manual test checklist for the project owner.
