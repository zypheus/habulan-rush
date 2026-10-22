---
title: Agawan ng Panyo phase 1 handoff
type: handoff
status: pending-owner-test
owner: project-owner
task: agawan-ng-panyo-phase-1
updated: 2026-10-23
source: src/ServerScriptService/MatchService.server.lua
related:
  - ../current-task.md
  - ../../MODULE_OWNERSHIP.md
---

# Agawan ng Panyo Phase 1 handoff

## Source change

- `Config.ModeVote` lists Classic Tag as enabled and Agawan ng Panyo as disabled until its round rules exist. The server automatically chooses Classic while it is the only enabled mode, so the current match sequence has no extra vote delay.
- `MatchService` owns the selected mode, publishes `HRushGameMode` and the mode in `StateChanged`, and has a validated, server-timed mode ballot for the point when a second mode is enabled. A vote tie or empty ballot chooses Classic Tag. Departed players' votes do not count.
- `ModeVoteUI` receives server ballot events and supports button activation through mouse, touch, and gamepad focus. It stays hidden while only Classic is enabled.
- `ModeVoteEvent` and `ModeVoteUI` are mapped in `default.project.json` and recorded in `MODULE_OWNERSHIP.md`.

## Validation

- Repository syntax, notes, diff whitespace, and Rojo build passed on 2026-10-23.
- No Roblox Studio instance was connected. No Studio playtest or device test was run by the agent.
- The multiple-choice ballot cannot be playtested until Phase 2 enables Panyo. Its server rules and UI are source-checked only in this phase.

## Project-owner Studio checklist

1. Open the freshly built place and queue one player. Confirm search completion still enters the existing Classic map vote without an extra mode screen.
2. Complete all three Classic rounds. Confirm MS_RPS, countdown, tag, score recap, podium, and return to lobby behave as before.
3. With two players, confirm both receive `HRushGameMode = "ClassicTag"` during the match and lose the player attribute on lobby return or when outside the match.
4. On PC, mobile, and gamepad, confirm the new hidden mode UI does not block the map vote or existing controls.

## Next

Wait for owner feedback. Phase 2 needs explicit approval before enabling Agawan ng Panyo or adding pickup and steal rules. At that point, test split and unanimous mode ballots, late votes, vote spam, and disconnects with two available choices.
