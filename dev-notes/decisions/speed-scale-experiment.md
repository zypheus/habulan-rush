---
title: speed scale experiment
type: decision
status: draft
owner: team
task: T09
updated: 2026-10-14
source: src/ReplicatedStorage/Config.lua:10
related:
  - ./00-index.md
  - ./pending-doc-updates.md
  - ../.gemini/TASK.md
---

SpeedScale 1.5 test is live in Config and awaits team sign-off plus a 2-player playtest.

## Decision

Undecided. Keep `SpeedScale = 1.5` as a test value until sign-off.

## Context

Locked walk, sprint, and Taya bases (16, 21, 18) stay untouched. One multiplier routes every movement speed and speed-derived distance. Live speeds are walk 24, sprint 31.5, Taya 27.

## Values changed

| File | Key | Old | New |
|------|-----|-----|-----|
| `src/ReplicatedStorage/Config.lua:10` | SpeedScale | 1.0 implied | 1.5 [SD] |

## Approved by

Nobody yet. `.gemini/TASK.md` line 55 records team sign-off plus 2-player playtest as pending.

## Design doc lines to update

None until sign-off. If approved, the movement speed lines in the System Specification and GDD need a scale note. Do not edit those docs from here.

## Status

draft.
