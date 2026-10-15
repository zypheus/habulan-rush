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

- Animation Batches A and B are authored, published, and wired with project-owner approval. No mechanic code was added.
- The live animation tool is data-driven, contains all 21 requested production names, and authors the 11 Batch A and B clips. The other 10 entries remain empty pose placeholders.
- `Config.Animations` contains 11 published Batch A and B IDs plus 10 explicit `REPLACE_ME_HRush_*` IDs. The old Sprint, Dash, and combined slide fallbacks are removed.
- Current runtime playback uses the published Sprint, Dash, and SlideLoop clips. The other eight published clips remain metadata until their movement-state owners are approved and implemented.
- Fresh-build Studio loaded and played all 11 IDs. Ten match the authored duration, loop, and priority metadata. The project owner confirmed the Fall ID is correct despite its 0.25-second, Action, non-looping published metadata differing from the 0.60-second authored source.
- The map audit found that Kalsada supports roll testing and 3.5-stud crate vault testing now. Climb, swing, and zipline need new authored map pieces. Binaha has no implemented geometry.
- Movement upgrade Step 1 remains implemented. Its live two-player validation is still pending.

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
- Audited Kalsada and Binaha against roll, vault, climb, swing, and zipline requirements.
- Rebuilt `tools/AnimationDev/HRush_AnimDev.lua` around one animation data table with verified R15 hierarchy, mirror and easing helpers, validation, and current local preview registration.
- Added the command-bar preview entry point and publishing workflow.
- Expanded `Config.Animations` to all 21 original movement clips and made runtime loading reject empty or placeholder IDs before preload and `LoadAnimation`.
- Verified the Batch 0 self-test in Studio at normal speed, 0.25 speed, and a scrubbed pose.
- Authored the six original Batch A R15 clips, preserved the requested markers and durations, fixed scrub preview weighting, and validated every clip in Studio at normal speed, 0.25 speed, and a scrubbed pose.
- Authored the five original Batch B R15 clips with shared slide transition poses and a sprint-compatible dash recovery. All five passed Studio validation, build, normal-speed, 0.25-speed, and scrub checks.
- Wired all 11 project-owner-supplied Batch A and B IDs into `Config.Animations`, removed their matching legacy fallbacks, moved current single-state slide playback to `SlideLoop`, and logged the original assets.

## Next

- Check Sprint, Dash, and SlideLoop playback locally and remotely with two players.
- Define and approve the client state owner before wiring Walk, JumpStart, Fall, Land, LandHard, SlideEnter, SlideExit, or SlideJump into live transitions.
- Batch C remains blocked until separate project-owner approval for both the Roll mechanic proposal and original Roll animation.
- Keep mechanic code blocked until the matching Batch C, D, E, or F proposal is approved.
- Complete the separate Step 1 two-player Studio checklist before using its telemetry as authority evidence.

## Blockers

- Manual 2-player Studio validation is still required for gameplay work.
- Published Batch A and B animations are logged as original project-owned assets. Unrelated audio and run-style catalog IDs still need their own release eligibility review.
- Movement Step 1 live two-player validation is pending.
- `TagService` is still a stub, so authoritative slide profile and pounce interaction remain unimplemented.
- Binaha remains in the map vote by decision, although its map and loading path are not implemented.
- Eleven Batch A and B animation IDs are published and wired. The other 10 production IDs and pose lists remain placeholders.
- Kalsada has no `Climbable`, `SwingBar`, or `Zipline` authored pieces or tags.

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
14. Every movement state receives a newly authored original R15 animation. Earlier reuse and light-tweak recommendations are superseded.
15. Old sprint, slide, and dash IDs may remain only as temporary fallbacks until each replacement is published.
16. Animation Batch 0 is approved.
17. Animation Batch A is approved and implemented.
18. Animation Batch B is approved and implemented. Batch C and its Roll mechanic require the next project-owner approval.
19. Published Batch A and B IDs supplied by the project owner are wired. Sprint, Dash, and combined slide fallbacks are removed. The existing single-state slide uses `SlideLoop` until a separate movement state-machine change is approved.
20. The project owner confirmed `rbxassetid://106234834891508` is the correct Fall ID. Preserve the measured published metadata difference as future transition-test evidence, not an ID blocker.

## Validation

- `scripts/check-syntax.ps1`: passed on 2026-10-15.
- `scripts/check-notes.ps1`: passed on 2026-10-15 after the final current-task update.
- Rojo build to `HabulanRush.rbxlx`: passed on 2026-10-15.
- Earlier read-only Studio probe: the connected place was stale at `SpeedScale = 1.5` and was not used as evidence. The fresh-build probe is recorded below.
- Movement Step 1 Luau syntax check: passed on 2026-10-15.
- Movement Step 1 notes check: passed on 2026-10-15.
- Movement Step 1 Rojo build: passed on 2026-10-15.
- Generated place contains `MovementAuthority`, its bootstrap, and `RequestMovementState`.
- Movement Step 1 live two-player Studio validation: pending.
- Animation Batch 0 source syntax check: passed on 2026-10-15.
- Animation Batch 0 Rojo build: passed on 2026-10-15.
- R15 hierarchy probe: passed against a generated rig using the standard 15 named AnimationConstraint joints.
- Pipeline self-test: passed with 3 keyframes, `PipelineMidpoint`, full hand and foot nesting, and placeholder rejection.
- Validator branch test: passed for loop mismatch, rotation jump, marker bounds, restored valid data, and stale output cleanup.
- Studio Play preview: normal 0.150 s, quarter-speed 0.033 s, scrub 0.250 s.
- No animation asset was published in Batch 0, so `ASSET_LOG.md` was not changed.
- Animation Batch A source syntax check: passed on 2026-10-15.
- Animation Batch A Studio validation: six sequences built; all six passed normal-speed, 0.25-speed, and midpoint scrub playback with full preview weight.
- Batch A marker validation: `FootstepL` at 0.000, `FootstepR` at 0.225, `LandImpact` at 0.080, and hard `LandImpact` at 0.100.
- Batch A visual review sampled the Sprint airborne silhouette at 0.115 and the LandHard planted-hand impact hold at 0.160.
- The Batch A authoring pass did not publish assets. The later publication wiring records the six supplied IDs in `Config.Animations` and `ASSET_LOG.md`.
- Animation Batch B source syntax check: passed on 2026-10-15.
- Animation Batch B Studio validation: five new sequences built within 11 completed production sequences; all five passed normal-speed, 0.25-speed, and midpoint scrub playback with full preview weight.
- Batch B visual review sampled the SlideLoop hold from the gameplay rear angle and side angle. The side view confirmed the reclined torso, extended lead leg, tucked trailing leg, and braced arms.
- The Batch B authoring pass did not publish assets. The later publication wiring records the five supplied IDs in `Config.Animations` and `ASSET_LOG.md`.
- Batch A and B publication wiring validation is recorded below.
- Batch A and B publication wiring syntax check, notes check, and Rojo build: passed on 2026-10-15.
- Fresh-build Config probe: all 11 supplied IDs present; Sprint and Dash have no `FallbackId`; `SlideLegacy` is absent.
- Fresh-build asset probe: all 11 IDs loaded and played. Ten clips matched their authored duration, loop flag, priority, and keyframe count.
- Fall publication probe: `rbxassetid://106234834891508` repeatedly reported 0.25 seconds, Action priority, non-looping, and five keyframes. The authored source is 0.60 seconds, Movement priority, looping, and five keyframes. The project owner confirmed the supplied ID is correct.

## End-of-item routine

1. Update Current, Completed, Next, Blockers, and Validation here.
2. Append one row to `AI_LOG.md`.
3. Update `ASSET_LOG.md` only when an asset is added, removed, replaced, or approved.
4. Add a playtest note for test evidence and a handoff note only when work remains mid-item.
5. Stop and report before starting the next approved item.
