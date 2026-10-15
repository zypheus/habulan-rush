---
title: current task
type: task
status: active
owner: project-owner
task: movement-upgrade-step-1
updated: 2026-10-15
source: docs/MOVEMENT_AUDIT.md
related:
  - ../AGENTS.md
  - ../docs/MOVEMENT_AUDIT.md
  - ../docs/UPGRADE_REPORT.md
  - ../.gemini/TASK.md
  - ../MODULE_OWNERSHIP.md
---

This is the live resume page for Codex and Obsidian. Keep it concise and update it after every approved item.

## Current

- Movement upgrade Step 1 is implemented with project-owner approval.
- `Config.Movement` now contains the staged movement tuning and server observation limits. Existing movement feel remains unchanged.
- `Config.Animations` owns the three active movement IDs and empty metadata placeholders for unpublished original movement clips.
- `MovementAuthority` owns the server movement ledger, request validation, cooldowns, rate limits, and passive speed/displacement observation. Correction is disabled.

## Completed

- Audited the agent setup and game state in [UPGRADE_REPORT](../docs/UPGRADE_REPORT.md).
- Made this note the live resume state.
- Kept `.gemini/TASK.md` as the historical production backlog.
- Reduced `AGENTS.md` to current rules, commands, source map, and Definition of Done.
- Recorded the project owner's decisions from the upgrade audit.
- Compared nine mapped/unmapped source pairs: four were byte-identical and five mapped files were newer supersets.
- Removed nine unmapped duplicates after confirming no production references or unique required behavior.
- Rebuilt `MODULE_OWNERSHIP.md` around the sole project owner and every canonical Rojo-mapped source.
- Audited effective movement values, sprint and slide behavior, normal jump and landing gaps, camera writers, keyboard/gamepad/touch input, server authority, exploit risks, animation playback, and `HRush_AnimDev` authoring.
- Recorded the adapted movement build sequence, proposed Step 1 scaffold, Studio reproduction checklist, and known blockers in `docs/MOVEMENT_AUDIT.md`.
- Applied the approved `SpeedScale = 1.2` balance item, audited every canonical consumer, and passed syntax, notes, and Rojo build checks.
- Implemented movement Step 1 with a dedicated server authority module and thin bootstrap. Syntax and Rojo build checks passed.

## Next

- Open the newly generated `HabulanRush.rbxlx` and complete the Step 1 two-player Studio checklist.
- Confirm server attributes and warnings for valid sprint, slide, dash, cooldown, airborne slide, and displacement cases.
- Stop after Step 1 and wait for project-owner approval before Step 2.

## Blockers

- Live two-player Studio validation is pending. The connected Studio session had the older place loaded and reported `SpeedScale = 1.5`, so it was not used as evidence for the new build.

- Manual 2-player Studio validation is still required for gameplay work.
- Asset eligibility was affirmed by the project owner, but exact source/license evidence still needs to be written into `ASSET_LOG.md` before release approval.
- Active sprint, slide, and dash animation IDs have no `ASSET_LOG.md` entries. The exact active sprint revision needs provenance.
- Movement Step 1 live two-player validation is pending.
- `TagService` is still a stub, so authoritative slide profile and pounce interaction remain unimplemented.
- Binaha remains in the map vote by decision, although its map and loading path are not implemented.

## Approved decisions

1. Applied `Config.Movement.SpeedScale = 1.2` as a separate balance item. Live two-player validation remains pending.
2. Winner rule: lowest cumulative Taya time is primary. Round points are the first tie-breaker. Exact ties share rank; UserId may order equal UI rows without changing rank.
3. Keep Binaha in the vote unchanged for now. Treat the missing map as a known blocker, not completed content.
4. The project owner confirms asset eligibility. Improve the original sprint, slide, dash, and ability animation timing later. Add exact provenance and approval evidence before release.
5. Keep Coins, Gems, and Shop presentation unchanged for now. Do not add purchases or Robux transactions.
6. The project has one human maintainer. Duplicate source removal is approved after diff review and canonical ownership assignment.
7. Codex is the primary coding agent. Keep live state in this Obsidian-visible note; use other agents only when explicitly approved.
8. Roblox Studio MCP may support all features, inspection, automation, and tests. Repository source remains canonical.
9. Slide grants no invulnerability. It lowers the vertical collision and target profile for low gaps. Touch tag remains valid, and pounce uses the reduced slide profile when authoritative hit validation is implemented.
10. Persist settings later in a dedicated versioned server DataStore with clamped values, `UpdateAsync`, retry/backoff, session caching, leave saves, and shutdown saves. Do this after core authority work.
11. Movement upgrade Steps 0 and 1 are approved. Step 2 is not approved yet.
12. Keep the approved `SpeedScale` 1.2 balance item separate from the movement upgrade so validation ceilings use a tested baseline.
13. Dedicated `MovementAuthority` owns server movement validation. `TagService` keeps tag and pounce authority.

## Validation

- `scripts/check-syntax.ps1`: passed on 2026-10-15.
- `scripts/check-notes.ps1`: passed on 2026-10-15 after the final current-task update.
- Rojo build to `HabulanRush.rbxlx`: passed on 2026-10-15.
- Read-only Studio probe: connected place was stale at `SpeedScale = 1.5`; new build not live-tested yet.
- Movement Step 1 Luau syntax check: passed on 2026-10-15.
- Movement Step 1 notes check: passed on 2026-10-15.
- Movement Step 1 Rojo build: passed on 2026-10-15.
- Generated place contains `MovementAuthority`, its bootstrap, and `RequestMovementState`.
- Movement Step 1 live two-player Studio validation: pending.

## End-of-item routine

1. Update Current, Completed, Next, Blockers, and Validation here.
2. Append one row to `AI_LOG.md`.
3. Update `ASSET_LOG.md` only when an asset is added, removed, replaced, or approved.
4. Add a playtest note for test evidence and a handoff note only when work remains mid-item.
5. Stop and report before starting the next approved item.
