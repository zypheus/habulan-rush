---
title: speed scale experiment
type: decision
status: approved
owner: project-owner
task: T09
updated: 2026-10-15
source: src/ReplicatedStorage/Config.lua:10
related:
  - ./00-index.md
  - ./pending-doc-updates.md
  - ../.gemini/TASK.md
---

SpeedScale 1.2 is approved and implemented in Config. A live 2-player playtest is still required before gameplay validation is complete.

## Decision

Use `SpeedScale = 1.2`. Keep the locked walk, sprint, and Taya base values unchanged.

## Context

Locked walk, sprint, and Taya bases (16, 21, 18) stay untouched. One multiplier routes every movement speed and speed-derived distance. Effective speeds are walk 19.2, sprint 25.2, and Taya 21.6.

The same multiplier produces a 14.4-stud dash, a 21.6-stud RS_01 horizontal target, Runner slide entry values of 24 from walk and 31.5 from sprint, and a Taya slide entry value of 27 before existing velocity rules.

## Values changed

| File | Key | Old | New |
|------|-----|-----|-----|
| `src/ReplicatedStorage/Config.lua:10` | SpeedScale | 1.5 [SD] | 1.2 [SD] |

## Approved by

Project owner, 2026-10-15. Live 2-player validation remains pending.

## Design doc lines to update

The canonical design documents retain the locked base values. Runtime effective values and the multiplier decision are recorded here and in the live task note.

## Status

Approved and implemented. Studio validation pending.
