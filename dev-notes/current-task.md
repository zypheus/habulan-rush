---
title: current task
type: task
status: active
owner: project-owner
task: pounce-tag-ability
updated: 2026-10-17
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

- Latest owner request: reduced pounce cooldowns to 0.8 seconds on hit and 1.05 seconds on miss. Fixed midair eligibility to read horizontal momentum instead of MoveDirection, which AirMovement intentionally clears. The accepted direction is captured before windup and reused at launch.
- No tests requested or run for this fix. Owner should check moving jump ascent/apex/descent activation, direction after releasing movement midair, and the shorter cooldowns.

- 2026-10-17 revision: moving walking/sprinting/jumping pounce is implemented; stationary activation stays disabled. Player and bot touch tags are removed. Players can pounce-tag bots, and bot Tayas use the authoritative pounce lifecycle.
- Owner requested no agent testing. Follow the [latest manual checklist](playtests/2026-10-17-pounce-only-tags.md). Earlier gameplay results do not validate this revision.

- Pounce / Tag implementation is built in `HabulanRush.rbxlx` and handed to the project owner for testing on 2026-10-17. The owner explicitly requested no further agent testing.
- Approved Taya sprint is 21 base, 25.2 effective studs/s. Pounce uses the four exact supplied animation IDs and the approved 0.07-second windup, now 0.8/1.05-second hit/miss cooldowns.
- Known unresolved result: earlier multiplayer runs confirmed hits, but the last asserted run received Denied for an expected hit. Do not mark gameplay validation complete. See [pounce handoff](playtests/2026-10-16-pounce-tag.md).

- Movement upgrade Part 1 is approved after project-owner Studio testing. `FallGravityMult` remains 1.6.
- Movement upgrade Part 2 is implemented and waiting for project-owner feedback. Parts 3 and 4 have not started.
- `LandingController.lua` is the one client owner for fall-height tracking, Soft or Hard classification, Land and LandHard playback, the local landing event, the LandImpact event, and the 0.10-second hard-landing penalty.
- `HardLandHeight = 12` separates the measured 9.61-stud building-height drop as Soft from the measured 13.75 to 14.29-stud boundary-wall-height drop as Hard. Hard landings apply `HardLandSpeedMult = 0.85` and Vault, Roll, or Slide cancels the active penalty.
- `AirControlPct = 0.0` now commits normal jumps to their takeoff vector. The Studio override remains available. A full-speed fixture preserved 25.20 studs/s through landing and reached 11.85 studs.
- Vault measures its 3.00-stud standing feet offset from root half-height plus HipHeight. It probes from current feet, applies the 7.0-stud absolute ground cap, requires a 1.5-stud far-side drop, and rejects platforms for the future mantle owner.
- Ground and air Vault require 80 percent of effective sprint speed, retain 95 percent on exit, use a 0.25-second cooldown, cap obstacle depth at 5 studs, and tag `SpeedVault`, `StepVault`, `LowHop`, or `AirVault` while using the existing Vault animation.
- Vault arcs use a blockcast before each scripted movement step and print interruptions caused by collision, stun, tag or role change, round end, character loss, or death.
- `MovementAuthority` mirrors landing, current-feet height, absolute cap, distance, speed, drop, depth, state, and cooldown checks. It logs only and `ServerCorrectionEnabled` remains false.
- No remote was added. Vault continues through `RequestMovementState`; landing and impact use client-only BindableEvents for future camera and presentation consumers.
- Solo fresh-build fixtures passed the requested eight-case Vault matrix. The required real two-player server acceptance and remote animation check remain pending.

## Completed

- Implemented the approved movement upgrade Part 2 without starting the new Vault animation batch or camera work.
- Added the single landing owner, live Land and LandHard playback, landing and impact events, Soft and Hard behavior, cancellable hard-landing speed penalty, and server observation.
- Reworked Vault around current feet height, the absolute ground cap, knee, waist and chest probes, top and landing rays, the mantle boundary, four variant tags, collision-safe motion, interruption cleanup, and mirrored server validation.
- Changed normal air steering to a committed takeoff vector at `AirControlPct = 0.0` while retaining the Studio comparison override and permanent air-speed cap.
- Measured the landing threshold and all requested Vault fixture cases in a fresh generated place.
- Implemented the approved movement upgrade Part 1 jump and air slice without starting later parts during that approved pass.
- Preserved JumpPower 50 and the 6.4-stud apex while applying total falling gravity only to the local character through a center-of-mass VectorForce.
- Added live coyote time, jump buffering with one-shot consumption, takeoff momentum preservation, slide-jump retention, air control override, and a permanent horizontal air-speed cap.
- Extended the server ledger with log-only vertical checks and a replication observation window. A fresh honest jump completed with zero authority violations and correction disabled.
- Scanned Kalsada and Binaha for 11 to 14 stud gaps and 5.5 to 6.4 stud ledges. Neither map has a jump-required route in those bands.
- Completed the approved movement upgrade Part 0 audit for jump and air physics, Batch D Vault, and all camera readers and writers.
- Printed measured jump, vault configuration, gravity, zoom, camera type, FOV, and render-priority values to Studio Output from the generated place.
- Verified current Humanoid, Workspace gravity, Camera, CameraType, RunService, and RenderPriority behavior against current Roblox Creator documentation.
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
- Authored the original seven-keyframe `HRush_Roll` clip with `RollImpact` at 0.14 seconds and a direct Sprint recovery. Studio validation, normal speed, 0.25 speed, and scrub checks passed.
- Implemented Batch C Roll prediction, state cleanup, animation loading, shared keyboard/gamepad/touch input, and server authority without adding a remote or a mobile button.
- Fixed the client and server landing-order races found during fresh-build testing. The client consumes a still-live buffer once grounded, and the server briefly holds a request until it independently observes the landing.
- Wired project-owner-supplied Roll ID `rbxassetid://97323662606589`, verified its published metadata, and logged the original asset.
- Authored the original seven-keyframe `HRush_Vault` clip with a planted-hand swing, tucked clearance, Sprint recovery, and the two approved markers.
- Implemented Batch D automatic Vault prediction and cleanup without a new remote or mobile button. Extended `MovementAuthority` with server-observed speed, direction, geometry, landing, cooldown, and travel validation.
- Fixed the client controller's Luau 200-register runtime failure by grouping Vault state and helpers in one table.
- Fixed exact 3.5-stud crate rejection caused by avatar HipHeight variance by measuring obstacle height from server-visible ground rays.
- Wired project-owner-supplied Vault ID `rbxassetid://88476053772200` and logged the original asset.

## Next

- Test the rebuilt pounce-only revision: walking and jumping activation, no contact-only tags, player/bot pounce hits, and bot Taya recovery.

- Project owner: open the newly built `HabulanRush.rbxlx`, start a live match with two players, and follow the pounce handoff checklist. Report any denied grounded sprint pounce first.
- Do not resume agent gameplay tests unless the owner requests them.

- Wait for project-owner feedback on Part 2. Do not start Part 3 or Part 4.
- Run the Part 2 two-player checklist, including remote landing animation, remote Vault animation, server variant acceptance, interruption behavior, and zero false authority logs.
- Recheck the hard-landing cancellation path with real Vault, Roll, and Slide input timing.
- Repeat the core automatic Vault matrix with gamepad and mobile movement input. Vault itself has no extra action button.
- Check Roll mechanics, animation playback, and remote replication with two players. Also check ButtonR1 and the existing touch slide action.
- Check Sprint, Dash, and SlideLoop playback locally and remotely with two players.
- Define and approve the client state owner before wiring Walk, JumpStart, Fall, Land, LandHard, SlideEnter, SlideExit, or SlideJump into live transitions.
- Keep Batch E and F mechanic code blocked until their matching proposals and map support are approved.
- Complete the separate Step 1 two-player Studio checklist before using its telemetry as authority evidence.

## Blockers

- Part 2 implementation and solo Studio fixture evidence are complete, but required two-player, mobile, and gamepad validation remains pending.
- Manual 2-player Studio validation is still required for gameplay work.
- Published Batch A and B animations are logged as original project-owned assets. Unrelated audio and run-style catalog IDs still need their own release eligibility review.
- Movement Step 1 live two-player validation is pending.
- `TagService` now owns pounce validation and lowered slide target profiles. Pounce acceptance reliability and remaining manual checks need owner validation.
- Binaha remains in the map vote by decision, although its map and loading path are not implemented.
- Thirteen Batch A through D animation IDs are published and wired. Eight later production pose lists remain placeholders.
- Batch C two-player, gamepad, mobile, and published-animation replication validation is pending.
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
18. Animation Batch B is approved and implemented.
19. Published Batch A and B IDs supplied by the project owner are wired. Sprint, Dash, and combined slide fallbacks are removed. The existing single-state slide uses `SlideLoop` until a separate movement state-machine change is approved.
20. The project owner confirmed `rbxassetid://106234834891508` is the correct Fall ID. Preserve the measured published metadata difference as future transition-test evidence, not an ID blocker.
21. Animation Batch C and its Roll mechanic are approved and implemented.
22. Published Roll ID `rbxassetid://97323662606589` is wired and recorded as an original project-owned asset.
23. Animation Batch D and its automatic Vault mechanic are approved and implemented. Published Vault ID `rbxassetid://88476053772200` is wired and recorded as an original project-owned asset.
24. The movement upgrade must proceed one part at a time. Part 0 is audit-only. Each later part requires project-owner approval, its own note updates, a Studio checklist, and a stop for review.
25. Jump uses a fixed-height, snappy-rise, fast-fall direction. Vault must become current-feet-relative and support ground or air contact. Camera must use one client-only director that yields to Tsinelas aim and TargetLock.
26. Movement upgrade Part 1 is approved with JumpPower 50 retained, total falling gravity starting at 1.6, live coyote and jump-buffer windows, AirControlPct starting at 1.0, an always-on air cap, and log-only server validation.
27. Movement upgrade Part 1 is approved after project-owner Studio testing. Part 2 changes AirControlPct to 0.0 for committed takeoff direction, keeps FallGravityMult 1.6, and is approved for landing and chest-level Vault implementation only.

## Validation

- 2026-10-17 midair fix and shorter cooldowns: Rojo build passed, regenerating `HabulanRush.rbxlx`. No tests run at owner request.

- 2026-10-17 pounce-only revision: Rojo build passed and regenerated `HabulanRush.rbxlx`. No tests run, as requested.

- 2026-10-17: Rojo build passed and generated `HabulanRush.rbxlx`. No additional syntax, notes, gameplay, or device tests were run after the owner requested testing be left to them.

- Movement Part 2 syntax and Rojo build checks: passed on 2026-10-16.
- Part 2 fresh-build startup: passed without a movement runtime error; printed standing feet offset 3.00 studs from 1.00 root half-height plus 2.00 HipHeight.
- Landing thresholds: 9.61 studs classified Soft with no penalty; 13.75 to 14.29 studs classified Hard with speed multiplier 0.85; the cancellation hook cleared the penalty immediately.
- Committed full-sprint jump fixture: 25.20 studs/s at landing and 11.85 studs horizontal reach with `AirControlPct = 0.0`.
- Vault fixture matrix: sprint crate SpeedVault passed; 20.0 studs/s under-gate case rejected; airborne 3.5-stud crate AirVault passed; 5-stud wall rejected; no-drop platform rejected and logged the mantle boundary; thin railing SpeedVault passed; 4-stud-deep box StepVault passed; rotated slope crate LowHop passed.
- Part 2 two-player server acceptance, remote animation replication, gamepad, and mobile checks: pending project-owner Studio test.
- Movement Part 1 syntax, notes, Rojo build, and diff whitespace checks: passed on 2026-10-16.
- Movement Part 1 flat-jump matrix: apex 6.40 to 6.41 studs at all tested multipliers; 1.6 air time 0.48 to 0.49 seconds; 1.6 walk reach 9.36 studs; 1.6 sprint reach 12.18 studs.
- Movement Part 1 grace inputs: coyote jump accepted 68.6 ms after ledge exit; buffered input accepted 115.8 ms before touchdown and produced exactly one jump 15.0 ms after landing.
- Movement Part 1 controls: Studio air-control comparison measured 19.20 studs/s at 1.0 and 13.44 studs/s at 0.7; forced 100 studs/s air velocity clamped to 28.98 studs/s.
- Movement Part 1 terminal test: long-drop render sampling stopped at -100.00 studs/s. Workspace gravity remained 196.2 and was never written.
- Movement Part 1 server test: one honest flat jump ended with zero movement violations, `HRushServerAirborne = false`, and `ServerCorrectionEnabled = false`.
- Movement Part 1 map scan: no real 11 to 14 stud jump-required void and no 5.5 to 6.4 stud ledge exists in Kalsada; Binaha has no geometry.
- Movement Part 0 source trace: all Rojo-mapped jump, velocity, gravity, Vault, camera, FOV, CameraType, CameraSubject, zoom, and render-step references reviewed on 2026-10-16.
- Movement Part 0 Studio defaults: gravity 196.2, `UseJumpPower = true`, JumpPower 50, inactive JumpHeight 7.2, effective walk speed 19.2, camera render priority 200, vertical FOV mode, min zoom 0.5, and max zoom 400.
- Movement Part 0 jump measurements: stationary apex 6.40 studs and 0.53 seconds; live walk 10.24 studs at 19.2 studs/s; live sprint 13.44 studs at 25.2 studs/s.
- Movement Part 0 camera states: lobby Scriptable at FOV 42; transient live-match probe Custom at FOV 70. The play session was stopped without saving.
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
- Animation Batch C Studio validation: `validateAll()` returned true; Roll built with seven keyframes over 0.45 seconds, Action priority, non-looping, and `RollImpact` at 0.14 seconds.
- Batch C preview: normal speed, 0.25 speed, and scrub checks passed. Visual samples covered the tucked rotation, 0.38-second recovery, and 0.449-second Sprint handoff.
- Batch C fresh-build runtime: the first authority test reproduced a legitimate landing request rejected while server `FloorMaterial` still reported Air. The pending server-observed landing fix then accepted the same case with zero violations.
- Batch C client landing fallback: fresh-build input testing observed `HRushRolling = true` after `FloorMaterial` and `StateChanged` settled in the opposite order.
- Batch C end-to-end solo test: client Roll and `HRushServerRolling` were both observed, and server state returned to Walk. Two-player, gamepad, mobile, and published animation checks remain pending.
- Batch C published asset probe: `rbxassetid://97323662606589` loaded and played at 0.45 seconds, Action priority, non-looping.
- Batch C syntax, notes, Rojo build, and diff whitespace checks passed on 2026-10-16.
- Animation Batch D Studio validation: `validateAll()` returned true and `buildAll(false)` produced 13 sequences. Vault has seven keyframes over 0.40 seconds, Action priority, non-looping, `VaultPlant` at 0.10, and `VaultClear` at 0.26.
- Batch D preview: normal playback reached 0.171 seconds; quarter-speed playback reached 0.104 seconds after 0.40 seconds with a 0.400-second track length. Plant, swing, and clear silhouettes were reviewed on the current AnimationConstraint R15 rig.
- Batch D runtime compile test found and fixed a Luau 200-register failure. A subsequent fresh runtime loaded and attached `MovementController` successfully.
- Batch D local Kalsada test: automatic contact Vault cleared an exact 3.5-stud crate from z=25 to z=36.14 and exited with cooldown active.
- Batch D authority test first exposed velocity replication ordering: client Vault predicted while the server observed zero velocity and rejected it. `MovementAuthority` now validates against a recent server-observed velocity window; final acceptance retest is pending because Studio closed.
- Batch D Vault publication probe: `rbxassetid://88476053772200` loaded as a seven-keyframe KeyframeSequence with 0.40-second duration, Action priority, and non-looping metadata.
- Batch D syntax, notes, Rojo build, and diff whitespace checks pass on 2026-10-16.

## End-of-item routine

1. Update Current, Completed, Next, Blockers, and Validation here.
2. Append one row to `AI_LOG.md`.
3. Update `ASSET_LOG.md` only when an asset is added, removed, replaced, or approved.
4. Add a playtest note for test evidence and a handoff note only when work remains mid-item.
5. Stop and report before starting the next approved item.
