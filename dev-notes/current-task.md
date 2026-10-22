---
title: current task
type: task
status: active
owner: project-owner
task: lihim-na-target-all-phases
updated: 2026-10-23
source: 2026-10-23 owner-approved Lihim na Target all-phases plan
related:
  - ../AGENTS.md
  - ../docs/MOVEMENT_AUDIT.md
  - ../docs/CAMERA_AUDIT.md
  - ../docs/UPGRADE_REPORT.md
  - ../.gemini/TASK.md
  - ../MODULE_OWNERSHIP.md
---

This is the live resume page for Codex and Obsidian. Keep it concise and update it after every approved item.

## Current

- 2026-10-23: Implemented the approved Lihim na Target phases in repository source and rebuilt `HabulanRush.rbxlx`. The mode uses private server-owned target cycles, validated click/R2/mobile captures, protections and streaks, 120-second rounds, practice rules, timed hints, a private HUD, and Hunt recaps. Syntax, notes, diff whitespace, and Rojo checks passed. Owner Studio acceptance remains pending; see [full-mode handoff](playtests/2026-10-23-secret-hunt-full-mode-handoff.md).
- 2026-10-23: Implemented the owner-approved mobile STEAL button refresh and persistent Carrier highlight and trail in source. The touch button now rechecks its actual visibility every 0.1 seconds, while the Carrier has a gold outline and movement trail with stronger timed reveals. Syntax, notes, diff whitespace, and Rojo build passed; fresh-build owner Studio acceptance remains pending; see [full-mode handoff](playtests/2026-10-23-panyo-full-mode-handoff.md).
- 2026-10-23: Phase 3 source review found and fixed an invalid-round scoring path: when a competitive Panyo round fell below two players, it awarded no match points but still added hold time and steals to final MVP totals. Only valid rounds now contribute to those totals. A fresh Rojo build and owner Studio matrix remain the acceptance steps; see [full-mode handoff](playtests/2026-10-23-panyo-full-mode-handoff.md).
- 2026-10-23: The project owner approved all Agawan ng Panyo phases. Repository source now includes the enabled mode vote, Kalsada-only Panyo round, server-observed pickup and steal, Carrier recovery, possession scoring, timed events, HUD, recaps, and original local cue files. Source checks and Rojo build pass. Owner Studio, mobile, and gamepad validation plus cue upload remain; see [full-mode handoff](playtests/2026-10-23-panyo-full-mode-handoff.md).
- 2026-10-23: Implemented the approved Agawan ng Panyo Phase 1 mode-selection foundation. Classic Tag is the sole enabled mode, so it is selected immediately and the existing map vote, MS_RPS, and three-round flow remain active. `MatchService` now publishes `HRushGameMode`, and a validated mode ballot plus `ModeVoteUI` are mapped for use after Panyo gameplay is built. The ballot is dormant while only Classic is enabled. Owner Studio regression remains pending; see [Phase 1 handoff](playtests/2026-10-23-panyo-phase1-handoff.md).
- 2026-10-22: Implemented the owner-approved first-person FOV setting, then reduced its upper limit to 95 degrees at owner request. The 50–95 degree, 1-degree slider defaults to the existing 72-degree base and applies locally with the existing FOV catch-up; first-person effects are also capped at 95 degrees. The settings panel can open over the match HUD while lobby controls stay hidden. Owner Studio and device checks remain pending. See [first-person FOV handoff](playtests/2026-10-22-first-person-fov-handoff.md).
- 2026-10-22: Replaced the server-played third-person tag animation with owner-supplied `rbxassetid://132133679924288`, superseding `139144393566205`. The first-person animation and tag logic are unchanged. Source syntax, notes, and Rojo build passed; arm-only blending and two-player playback await owner Studio testing.
- 2026-10-22: The owner-approved wind dash VFX replacement is implemented in repository source. `WindDash` creates one Beam, three Trails, and two one-shot emitters with a 0.35-second cleanup; the old inline ribbon and sparkle are removed. Accepted live dashes broadcast a cosmetic observer event. Dash movement, input, and the unrelated in-progress EquipmentGlide edits are preserved. Syntax and Rojo build passed. The owner will perform final visual, two-player, wall-stop, mobile, and gamepad validation. See [wind dash handoff](playtests/2026-10-22-wind-dash-handoff.md).
- 2026-10-19: The owner subsequently requested a local build of the slide chaining fix. Rojo built `HabulanRush.rbxlx` successfully (708545 bytes). The new source is in the generated place; it has not been published or tested in a live Studio round.
- 2026-10-19: Fixed the generated-place slide momentum path in source. `MovementAuthority` had required a Runner `Sprint` ledger state and applied the old slide speed threshold to the entire slide; the client allowed a moving slide and predicted a gain. Rejected requests had no confirmed gain for `MomentumHUD` to show. The server now accepts moving grounded slides regardless of sprint ledger state, while a shared 80% role-sprint entry-speed rule gates only momentum. The client sends its pre-burst eligibility as a veto; the server independently checks observed speed. Slow slides still run and correct prediction without a popup. `Config.Movement.SlideCooldown` is 1.25 seconds from entry, `Config.Momentum.ChainWindow` is 2.5 seconds, and `DiminishWindow` stays 2.0. Debug traces are gated by `Config.Momentum.Debug = false`. Source syntax passed; no new Rojo build, publish, or live Studio validation was run per owner instruction. See [slide chaining handoff](playtests/2026-10-19-slide-chaining-handoff.md).
- 2026-10-19: Successful normal and perfect roll popups now remain visible for 3 seconds total. The existing 0.6-second rise and fade plays after a 2.4-second hold; slide popups keep the original 0.6-second timing. `Config.Momentum.Fx.RollPopupTime` owns the roll duration. Source validation and Rojo rebuild passed; Studio visual timing remains pending.
- 2026-10-19: Momentum steps 2, 3, and 4 were implemented in source. The client predicts accepted slide and landing-roll gains with shared rules, sends pre-landing roll intent, and reconciles to owner-only server snapshots. The old slide and roll speed boosts are removed. The local HUD shows the bar, action and loss feedback, chain, and three owner-supplied sounds; settings control popups, bar, sounds, and reduced motion. CameraDirector adds tier FOV and the confirmed perfect-roll kick; the server changes `MomentumTier` only on tier transitions. At that handoff the 3-second slide cooldown exceeded the 2-second diminishing window; the slide chaining follow-up above changes this. Source checks and the owner-requested Rojo place build passed for that earlier version; two-player Studio, device, sound playback, and runtime Luau compile checks remain pending. See [steps 2-4 handoff](playtests/2026-10-19-momentum-steps-2-4-handoff.md).
- 2026-10-19: Momentum slice 1 implemented from the owner-pasted task. `Config.Momentum`, pure `MomentumRules`, and `MovementAuthority` now own validated slide/roll gains, diminishing returns, decay, hard zero, owner-only snapshots, and a capped ordinary speed allowance. The old client slide/roll boosts remain until slice 2. Syntax and notes checks passed; no place build or Studio test was run per task. See [handoff](playtests/2026-10-19-momentum-step1-handoff.md).
- 2026-10-18: Extended each MS_RPS sign pick window to 5 seconds live and 3 seconds in Studio through `Config.Match.Rps`. The server deadline and client timer both read those values. The new timing still needs a Studio feel check.
- 2026-10-18: Implemented owner-requested MS_RPS bato bato pick before MS_03 and removed the remaining MS_02 match-loop transition. The server owns the match-long eligible pool, timed sign submissions, AFK choices, ties, elimination, stage cap, disconnect fallback, and starting Taya. The client shows cards, hidden picks, simultaneous reveal, safe row, timer, controls, and result. Config values, pure resolve assertions, design docs, ownership, and Rojo mappings are updated. The owner subsequently requested a Rojo build, which passed. No Studio run was performed. See [MS_RPS handoff](playtests/2026-10-18-rps-handoff.md).
- 2026-10-18: Fixed the owner-reported animation regression from the simple-tag reimplementation. Root cause was the first-person `AnimationController` being attached to the live character alongside the Humanoid Animator. The first-person tag clip now runs on an isolated local cloned R15 arm rig; the live character keeps one Humanoid Animator for all movement and replicated animations. The real arms are hidden locally only while the first-person clip plays, then their previous local transparency is restored. The server third-person tag clip now uses Action4 priority. Rojo build passed; runtime verification remains with the project owner.
- 2026-10-18: Reimplemented the owner-approved simple click-to-tag mechanic after the earlier changes were discarded. Pounce motion, cooldown, camera, VFX, remotes, attributes, and HUD were removed. Taya now tags with left-click, R2, or the mobile TAG button; the server selects and validates the nearest Runner in a 6.5-stud forward volume with a 70-degree arc, line of sight, safe-window, dash-immunity, role, match, health, stun, and skill checks. `HRush_TagFirstPerson` (`rbxassetid://105436702082738`) plays through a local-only Action4 controller in first person. `HRush_TagThirdPerson` (`rbxassetid://139144393566205`) plays from the server Animator for all players. Rojo build passed; gameplay and device testing remain with the project owner.
- 2026-10-18: Replaced the four jump animations per owner request. `Config.Animations` JumpStart/Fall/Land/LandHard IDs are now `rbxassetid://74307357863566`, `rbxassetid://84863749801510`, `rbxassetid://88319270506819`, and `rbxassetid://104821646839230`, superseding the Batch A IDs `115591963738630`, `106234834891508`, `83446879560399`, and `93067099789487`. `ASSET_LOG.md` added four Approved rows and marked the old rows Superseded; `docs/MOVEMENT_AUDIT.md` tables updated. Syntax, notes, and Rojo build passed. No Studio metadata probe was run (owner choice). Runtime playback and 2-player replication checks pending.
- 2026-10-18: Replaced the sprint animation per owner request. `Config.Animations.Sprint.Id` is now `rbxassetid://74829353930740` (studio probe: `HRush_ExaggeratedSprint`, 0.6 s, Movement priority, looped, 48 keyframes), superseding the Batch A ID `132688446420207`. ASSET_LOG row added (Pending Review, owner provenance confirmation) and the old row marked Superseded; `docs/MOVEMENT_AUDIT.md` sprint table updated. Syntax, notes, and Rojo build passed. Runtime sprint playback and 2-player replication checks pending.
- 2026-10-18: Fixed the owner-reported first-person regression: after an FP session the character no longer turned toward movement in third person. Root cause was an `AutoRotate` capture corruption: `PounceController` and the Vault mechanic capture `Humanoid.AutoRotate` at start (capturing the director's FP forced `false`), and `stepFacing` used to restore and clear its saved value mid-mechanic, so the mechanic wrote back `false` and FP re-captured it; the TP exit then restored `false`. `stepFacing` now hands off completely while FP is active and a scripted mechanic owns the body (writes nothing, keeps the saved value) and restores only on camera-side exits. Movement direction was verified unaffected (PlayerModule `ControlModule` never reads `AutoRotate`). No other module changed. Syntax, notes, and Rojo build passed. Studio repro pending: FP, pounce or vault once, return to TP, body must turn toward movement and `Humanoid.AutoRotate` must read true.
- 2026-10-18: Owner approved full removal of the test bots from the game. Implemented across the whole stack: `MatchService` lost the bot fill, spawn/AI, bot votes, bot participants, and bot branches in vote roster, role transfer, teleport, and recap mapping; the search phase now starts the match with whatever queued when the 10-second timeout ends, even a single player (sandbox), and `Config.Match.MinPlayers` is no longer read by the match loop; `TagService` lost the `HRUSH_RequestBotPounce` bindable, bot pounce fields, bot pose/velocity restore helpers, and bot branches in target query, wall filters, heartbeat lifecycle, and payload mapping (`actor`/`actorId` are Player-only now); `Config` lost `BotFillTarget`, `AllowBots`, and `BotAttemptRange`; client scans over `Workspace.Bots` were deleted in `TargetLockController`, `ChaseState`, `ChaseHUD`, and `PounceController` (aim assist, wall exclude, and third-party pounce react). UI payloads keep the `isBot` field shape by owner decision, so `MapVoteUI`, `UIController`, and the recap builders are untouched. Legacy `TayaSpeed` stays in `Config` though nothing reads it. Syntax, notes, and Rojo build passed on 2026-10-18. No Studio test yet.
- Validation pending: open the rebuilt `HabulanRush.rbxlx`, queue solo, and confirm the search-timeout start (match begins with one player after the countdown), no bots spawn or vote, a solo round ends cleanly at MS_05, and a two-player match has visible Runner candidates in the Taya marker and target lock. Then delete this line.
- 2026-10-18: Camera overhaul Phase 4 is implemented in the repository: first person as a second view mode of the same `CameraDirector`. Toggle on Z / DPadUp / the new mobile view button; deferred blended switching with latest-request-wins; eye-anchored pose with a lighter capsule-safe effect set; body yaw ease with an AutoRotate contract that yields to dash, slide, vault, roll, and every existing owner; head visibility driven by the blend with an RS_03 aim exception; FOV base 72 with the same catch-up limit; `PounceCamera` FP scaling 0.6 FOV / 0.35 offsets; FP resume from aim or lock eases over 0.2 s. Added `Config.Camera.FirstPerson` (all [SD]), the two `Config.Pounce.Camera` FP scales, `Config.Settings.CameraViewModeDefault`, and the `cameraViewMode` string setting in `ClientSettings`. Syntax, notes, and Rojo build passed. No Studio test was run.
- Project owner review: run the Phase 4 checklist in Next. Spectator camera, final-seconds effects, and polish stay blocked until the owner approves.

- 2026-10-18: Owner requested a read-only analysis of the target lock and pounce aiming, because the lock felt off and tagging a locked target often missed. Verified findings. Pounce aim assist is a 10 percent blend inside an 18 degree, 14 stud cone (`Config.Pounce.AimAssist`) and never reads the lock. While locked the camera is fully Scriptable with no manual look (`TargetLockController`). Acquisition has no minimum angle, no immunity filter, and no range or line-of-sight auto-break. `Config.TargetLock.BreakRange` 55 and `LosBreakTime` 1.0 are defined but unused, and `LockDisabled` and `LockDelayUntil` are documented in comments but never checked. A lock break blocks reacquisition for `BreakCooldown` 4.0 seconds. The server measures the tag cone against replicated horizontal velocity captured at pounce request time, and travel validation allows only `MaxSteerAngle` 30 degrees of deviation. Delivered the state plus recommendation memo in chat. Option 1 is a client-only locked-target redirect clamped inside the 30 degree travel tolerance. Option 3 is a server-assisted lock pounce with a validated target hint and a `RequestPounce` payload change. No code changed. The owner will route the memo to a reviewing agent, and no implementation is approved.

- 2026-10-18: Camera overhaul Phase 3 is implemented in the repository. `CameraDirector` now blends Runner (72 FOV / 10.25 studs) and Taya (68 / 9.25) role profiles, adds Runner hold-to-look-back (B / ButtonL1, 160 degree swing) with a previous-frame movement-stability assist, chase proximity FOV, and tag-transfer FOV and shake feedback. New `ChaseState` module resolves the active Taya from players and `Workspace.Bots` and computes one shared smoothed chase intensity. New `ChaseHUD` module draws the Runner edge chevron, the Taya advisory tag-target marker, the tag-transfer edge pulse, and the mobile look-back button. Added `Config.Camera.RoleProfiles/LookBack/Chase/ChaserIndicator/TagMarker/TagTransfer` (all [SD]) and the `lookBackEnabled`/`chaserIndicatorEnabled` settings keys. Syntax, notes, and Rojo build passed. No Studio test was run.
- Project owner review: run the Phase 3 checklist in Next. First person, final-seconds effects, and spectator camera stay blocked until the owner approves.
- 2026-10-18: Camera overhaul Phase 2 is implemented in the repository. The movement camera effect system now lives inside `CameraDirector`: sprint, falling, landing, dash, slide, vault, and roll effects across FOV, position, rotation, and shake channels, with `Config.Camera.Effects`, the `cameraEffectsIntensity` setting, the `HRushSkillFov` suppression attribute, and the SprintVFX FOV migration. Syntax, notes, and Rojo build passed. No Studio test was run.
- Project owner review: run the Phase 2 checklist in Next. The owner then requested Phase 3, which is now implemented.
- 2026-10-18: Camera overhaul Phase 1 is implemented in the repository. `CameraDirector` plus starter, `Config.Camera`, two new `ClientSettings` keys, and the expanded settings panel are in the build. Syntax and Rojo build passed. No Studio test was run.
- Project owner review: run the Phase 1 checklist in Next, especially the settings pause, the aim and lock yields, and pounce compatibility.
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

- Lihim na Target Phases 0-5: audited repository and connected Studio Edit model read-only; implemented and enabled the full source mode; added the owner test and audio handoff. No new asset was added.
- Added a Panyo touch-button recovery check and persistent client-only Carrier highlight and trail. The server-owned steal rules and Classic tag path remain unchanged.
- Implemented the approved Agawan ng Panyo gameplay, event, UI, scoring, and audio source phases. Panyo is enabled in the ballot and restricted to the playable Kalsada map. Classic Tag retains its existing match branch.
- Agawan ng Panyo Phase 1 mode selection foundation: mapped the dormant multi-mode ballot and UI, published match mode to participants, and kept Classic as the only enabled mode. No asset was added.
- Added a live, memory-only first-person FOV slider with a 95-degree upper limit and in-match settings access; retained third-person FOV behavior and reset-to-defaults support.
- Wired the owner-supplied replacement third-person tag animation ID, logged the new asset and superseded ID, refreshed the tag handoff, and rebuilt the place.
- Ported the approved wind dash preview into source-owned `WindDash` and `[SD]` Config values; mapped `DashVFXEvent`, replaced the local legacy VFX, added server-accepted observer playback, and logged the three approved imported textures.
- Slide chaining source fix and tuning: shared slide eligibility, slow-slide no-gain correction, 1.25-second entry cooldown, 2.5-second chain window, gated debug traces, and pure rule assertions. No new asset was added.
- Momentum steps 1 to 4 source implementation is complete. Server sends value snapshots only to the owner and replicates `MomentumTier` on character models; all HUD, audio, and FOV effects are local.
- Extended the MS_RPS pick window in Config to 5 seconds live and 3 seconds in Studio; no other phase timing changed.
- Added MS_RPS first Taya selection, removed the MS_02 match-loop transition, and recorded the locked-rule revisions for owner review. Retained ShuffleBag only as a disconnect fallback.
- Removed the competing local Animator from the live character and isolated `HRush_TagFirstPerson` on a local arm rig while preserving the server-replicated `HRush_TagThirdPerson` path.
- Reimplemented simple click tagging, removed the complete pounce runtime, added server-owned target selection and final tag commit, wired perspective-specific tag animations, updated the Rojo map, ownership, asset log, and owner-test handoff.
- Replaced the four jump animations with the owner-supplied `rbxassetid://74307357863566` (JumpStart), `rbxassetid://84863749801510` (Fall), `rbxassetid://88319270506819` (Land), and `rbxassetid://104821646839230` (LandHard) in `Config.Animations`; added four Approved `ASSET_LOG.md` rows, marked the Batch A rows Superseded, and updated the `docs/MOVEMENT_AUDIT.md` ID table and Fall observation.
- Replaced the sprint animation with the owner-supplied `rbxassetid://74829353930740` (`HRush_ExaggeratedSprint`, verified 0.6 s / Movement / looped / 48 keyframes in Studio) in `Config.Animations.Sprint`; logged it in `ASSET_LOG.md` and marked the Batch A sprint row Superseded, and updated the `docs/MOVEMENT_AUDIT.md` sprint table.
- Fixed the owner-reported first-person exit regression (body not turning in third person). Read-only audit traced the `AutoRotate` capture corruption through `stepFacing`, `PounceController`, and the Vault mechanic, then `stepFacing` was reworked to three cases: FP manual (unchanged), FP plus scripted mechanic (hands off, saved value kept), and every camera-side exit (restore once). Movement direction confirmed independent of `AutoRotate` against the Studio-shipped PlayerModule `ControlModule`.
- Implemented camera overhaul Phase 4, the owner-requested first-person phase: a second view mode of the same `CameraDirector` with deferred blended switching, eye-anchored pose, first-person effect set, body yaw alignment, head visibility, `PounceCamera` FP scaling, and aim and lock resume blending. All three toggle routes write through `ClientSettings`, so the store handler is the single switch path.
- Added `Config.Camera.FirstPerson` (Enabled, CameraHeight 1.6, ForwardOffset 0.12, BaseFov 72, SwitchTime 0.2, YawAlignTime 0.12, ToggleKey Z, ToggleGamepad DPadUp, and the Effects block; all [SD]), `Config.Pounce.Camera.FirstPersonFovScale` 0.6 and `FirstPersonOffsetScale` 0.35, and `Config.Settings.CameraViewModeDefault` "ThirdPerson".
- Extended `ClientSettings` with a string spec kind and the memory-only `cameraViewMode` key (`ThirdPerson` / `FirstPerson`). No settings-panel row; the in-match panel limitation is unchanged.
- Added the `HRUSH_CameraView` action (Z / DPadUp, Pass while not the live input owner) and the `toggleViewMode` / `getViewMode` API. Both keys verified unused before binding.
- Added the mobile 48 px view button to `ChaseHUD` at (0.94, 0.40) with a polled 3P / 1P label; the LOOK button hides in first person and any touch look-back is released.
- `PounceCamera` scales its FOV layer by 0.6 and its positional and angular layers by 0.35 in first person through a lazy `CameraDirector` require; the reset and apply symmetry is untouched.
- Deferred switching waits for a free frame (no aim, lock, dash-deferral is per design, slide, vault, roll, pounce, stun, ability busy, settings, menu, yield) and blends from the last written frame over 0.2 s. FP resume from the aim or lock camera arms the same blend instead of cutting.
- Completed the owner-requested read-only TargetLock and pounce aiming analysis and delivered the state plus recommendation memo. No game code, Config value, remote, or asset changed.
- Implemented camera overhaul Phase 3, the owner-requested chase awareness phase: role camera profiles, Runner hold-to-look-back with a movement-stability assist, chase proximity FOV, tag-transfer feedback, the Runner edge chevron, the Taya advisory tag-target marker, and the mobile look-back button.
- Added `ChaseState.lua` (client chase state shared by camera and HUD) and `ChaseHUD.lua` plus `ChaseHUD.client.lua`; mapped all three in `default.project.json`.
- Added `Config.Camera.RoleProfiles` (BlendTime 0.3; Runner 72 / 10.25; Taya 68 / 9.25), `LookBack` (B / ButtonL1, 160 degrees, 0.15 s blend), `Chase` (20 to 2 studs, 3 FOV, 0.35 s rise, 0.6 s fall, closing bonus capped 0.35, visibility 0.8), `ChaserIndicator` (14 studs, 0.06 margin, 56 px padding), `TagMarker` (18 studs, 0.15 s scan), and `TagTransfer` (ToTaya -1.5 FOV, ToRunner +2 FOV, 0.07 shake) (all [SD]).
- Added `Config.Settings.LookBackDefault` and `ChaserIndicatorDefault`; added `lookBackEnabled` and `chaserIndicatorEnabled` to `ClientSettings`. No settings-panel rows.
- FOV composition is now role profile plus the boost sum (movement, chase, transfer) clamped to `MaxFovBoostTotal`; the rate-limited catch-up, `HRushSkillFov` suppression, and PounceCamera reset symmetry are preserved.
- Look-back is gated to Runner free movement (not Taya, not aim or lock, not scripted movement, not paused); the assist rotates `Humanoid.MoveDirection` by the previous frame's applied yaw so steering stays world-consistent. No movement value, speed, or AutoRotate is changed and no new remote was added.
- The tag marker is advisory only: nearest eligible Runner or bot within 18 studs with line of sight, respecting `HRushTagSafeUntil` and `TagRules.isUntouchable`; the server still decides every tag. Keys B and ButtonL1 were verified unused before binding.
- Passed syntax, notes, and Rojo build checks on 2026-10-18. No Studio or 2-player test has been run.
- Implemented camera overhaul Phase 2, the owner-requested centralized movement camera effect system: sprint, falling, landing, dash, slide, vault, and roll effects across FOV, position, rotation, and shake channels, with dt-based envelopes, movement-attribute suppression, and the hard-landing shake fed by `HRushLandingEvent`.
- Added `Config.Camera.Effects` (all [SD]) and `Config.Settings.CameraEffectsDefault`; added `cameraEffectsIntensity` to `ClientSettings`. No settings row yet.
- Moved FOV ownership to the director: absolute `BaseFov`-relative write per frame with a 40 degree/s catch-up limit, suppressed while the `HRushSkillFov` attribute is true.
- Removed the SprintVFX camera FOV code and the `Config.SprintVFX` FOV keys. `ReducedEffects` remains for count halving.
- Fixed the latent Phase 1 nil `SensitivityDefault` key in `CameraDirector.refreshSensitivity`.
- Passed syntax, notes, and Rojo build checks on 2026-10-18. No Studio or 2-player test has been run.
- Implemented camera overhaul Phase 1: the approved single client base camera director with third-person shoulder orbit, mouse/gamepad/touch look, collision, shoulder swap, MS_03/MS_04 cursor control, settings pause by panel visibility, and deferred lobby, match, and respawn handoffs around RS_03 aim and TargetLock.
- Added `Config.Camera` (all [SD]) plus `Config.Settings.CameraSensitivityDefault` and `InvertCameraYDefault`; extended `ClientSettings` with `cameraSensitivity` and `invertCameraY`.
- Expanded the lobby settings panel from 520x640 to 520x812 with generic toggle-row helpers. Existing rows keep identical behavior.
- Mapped `CameraDirector` and its starter in `default.project.json`. PounceCamera, SprintVFX, skill shake, lobby camera, TargetLock, and aim writers are untouched.
- Passed syntax and Rojo build checks on 2026-10-18. No Studio or 2-player test has been run.
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

- Project owner: run the [Lihim na Target full-mode checklist](playtests/2026-10-23-secret-hunt-full-mode-handoff.md) from the fresh Rojo place with 1, 2, 4, and 8 clients, then PC, mobile, gamepad, Classic Tag, and Panyo regressions. Report the first failure with client count, steps, server time, affected player, relevant `HRushHunt*` attributes, and expected versus observed behavior. Supply original or approved audio IDs for Hunt cues before audio acceptance.
- Project owner: in the fresh Rojo place, use two mobile clients to repeat A to B to A steals. After A loses possession, confirm STEAL reappears, the 2-second return block still rejects early attempts, and a valid later tag transfers possession once. Check PC and R2, the Carrier highlight and trail in third person, own first-person HUD without world effects, VFX 0 and 100, cleanup on death/drop/round end, and one Classic match.
- Project owner: run the [Agawan ng Panyo full-mode checklist](playtests/2026-10-23-panyo-full-mode-handoff.md) in a fresh build with 1, 2, 4, and 8 clients. Check Classic regression, pickup and steal timing, recovery, scoring, recaps, events, and device controls. Include the invalid-round MVP case from the Phase 3 source review. Send the first failing case with client count, steps, server time, affected player, and `HRushPanyo*` attributes. Upload the five original cue WAV files through the project account and enter approved IDs in `Config.Panyo.Sounds` before expecting Panyo-specific audio.
- Project owner: run the [first-person FOV handoff checklist](playtests/2026-10-22-first-person-fov-handoff.md) with two Studio clients, including 50/72/95 degrees, live changes, reset, match access, switching views, and mobile/gamepad controls.
- Project owner: open the rebuilt `HabulanRush.rbxlx` with two clients and tag while walking and sprinting. Confirm `132133679924288` moves the arm, keeps the legs walking or sprinting, and is visible to the other client. Report any lower-body motion or replication issue.
- Project owner: run the [wind dash handoff checklist](playtests/2026-10-22-wind-dash-handoff.md) in the newly built place. Review burst, ribbon thickness and direction, fade, one effect per dash, observer playback, wall stops, respawn, VFX settings at 0/50/100, and mobile/gamepad input. Report any visual adjustment needed before release.
- Momentum: open the newly built `HabulanRush.rbxlx` and run the [slide chaining checklist](playtests/2026-10-19-slide-chaining-handoff.md) with at least two clients, plus gamepad and mobile. Then run the broader [steps 2-4 checklist](playtests/2026-10-19-momentum-steps-2-4-handoff.md). Keep the 30 studs/s ceiling and other momentum values provisional until chase results are reviewed. Confirm the three supplied sounds are competition-safe before release.
- Project owner: review the MS_RPS doc lines, open the rebuilt `HabulanRush.rbxlx`, then run the [1, 2, and 8 player Studio cases](playtests/2026-10-18-rps-handoff.md), including the 3-second Studio pick feel, remote abuse, gamepad, mobile, and disconnect behavior. Supply approved reveal and result sound IDs if audio is wanted.
- Project owner: confirm walk, sprint, jump, fall, landing, dash, slide, roll, and vault animations work before and after tag attempts. Then verify first-person tag arms are local-only and the Action4 third-person tag clip is visible to both players.
- Project owner: test click, R2, and the mobile TAG button with two players. In first person, only the tagging player should see `HRush_TagFirstPerson`; both players should see `HRush_TagThirdPerson` for the same attempt, with the local Action4 clip taking visual priority. Check standing, running, jumping, sliding, vaulting, rapid clicks, misses, walls, side/rear targets, dash immunity, safe window, stun, and skill-busy rejection.
- Project owner: check the four new jump animations in a fresh build. Jump takeoff responsiveness, the airborne loop and its seam, soft and hard landing playback, the `LandImpact` marker in Land and LandHard, and 2-player replication.
- Project owner: check the new sprint animation in a fresh build. Sprint as both roles, confirm the loop, the speed-fit playback (`WalkSpeed / RunnerSprintSpeed`), and 2-player replication. Confirm the license/provenance for `rbxassetid://74829353930740` for the ASSET_LOG row.
- Project owner: verify the first-person exit fix. Enter first person, pounce once and vault once, then switch back to third person and confirm the body turns toward movement again and `Humanoid.AutoRotate` reads true. Repeat without pounce and vault to confirm no regression.
- Project owner: run the bot-removal validation bullet in Current. Config values were deleted (not dormant): if any old `HabulanRush.rbxlx` from before this change is open in Studio, reopen the rebuilt file.
- Project owner: run the Phase 4 first-person checklist with at least 2 players. Toggle on Z, DPadUp, and the mobile view button, and confirm the 3P / 1P label; switch while running, mid-slide, mid-vault, mid-roll, and mid-pounce and confirm the request waits and blends with no cut; first-person look and pitch limits, mouse, gamepad, and touch; body yaw alignment while strafing, sprinting, and turning, and that dash, slide, vault, and roll keep their authored facing; head and accessory hiding in and out of first person with accessories equipped and after a respawn; RS_03 aim entry and exit and TargetLock entry and exit from first person with no third-person flash and eased resumes; pounce camera in first person scaled but readable; landing, jump, slide, vault, and roll first-person effects at intensity 0, 50, and 100 with reducedCamera on and off; FOV feel against third person; mode persistence within a session and a return to ThirdPerson on a fresh join; mobile button placement with no overlap at 16:9, ultrawide, portrait, and landscape; toggling near a wall and in a corner; a full round in each mode.

- Target lock and pounce aiming: wait for the reviewing agent and the project owner to solidify the memo. If approved, do Option 1 first: client-only locked-target redirect, no remote change, clamped to about 25 degrees so travel validation stays clear. Option 3 later: server-assisted lock pounce with a validated target hint and a `RequestPounce` payload change. `Config.Pounce` is a locked revision, so any change needs project-owner sign-off. Do not implement before approval.

- Project owner: run the Phase 3 chase awareness checklist with at least 2 players. Role profile blend on both sides of a tag transfer; Runner profile look and feel against the Phase 1 baseline; hold B / ButtonL1 while running, standing, sprinting, dashing, sliding, turning a wall corner, on mobile with the LOOK button, and on gamepad; confirm the character keeps its heading while looking back and swings out cleanly on release; role transfer feedback fires once per transfer in both directions with no CameraType corruption; Taya marker with none, one, and multiple targets, behind a wall with line of sight lost, while locked, while pouncing, and on range exit; chase FOV rise and fall while the Taya closes and opens; pounce, TargetLock, RS_03, and Phase 2 effect regressions; UI at 16:9, ultrawide, and mobile portrait and landscape with no control overlap; reducedCamera on at intensity 0, 50, and 100.
- Project owner: run the Phase 1 camera checklist with at least 2 players. PC first: in-match third-person look and mouse feel, collision against walls and crates, aim hold and release with no snap, target-lock yield and break, pounce during camera control, respawn snap, match start and end handoff, out-of-match settings pause, both new settings rows, and shoulder swap on V and ButtonL3. Then one mobile touch-look pass and one gamepad pass.
- Project owner: run the Phase 2 movement camera checklist with at least 2 players. Sprint widen per role, falling pull-back, soft and hard landing dip and shake, dash pull-in, slide tilt, vault plant and clear bumps with AirVault scaling, roll dip, pounce regression, aim and lock regression, collision, reducedCamera on at intensity 0/50/100, and PC, gamepad, and mobile passes.
- `cameraEffectsIntensity` has no settings row yet. It stays at the 100 default until an eighth row is approved.
- `lookBackEnabled` and `chaserIndicatorEnabled` also have no settings-panel rows yet. They stay at their true defaults until rows are approved.
- Do not start the next camera phase (final-seconds effects, spectator camera, death cinematics, round-end camera, cinematic sequences, any TargetLock or RS_03 redesign) until the owner approves. Phase 4 first person was requested and is implemented.
- Camera sensitivity and invert stay memory-only. DataStore persistence remains a later approved item.
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

- Lihim na Target is source-complete but has no owner Studio gameplay, mobile, or gamepad results. Its four sound hooks have blank IDs until original or approved cues are supplied and logged. Kalsada is its only verified playable map.
- The owner-reported mobile STEAL disappearance and new Carrier effects need a fresh-build Studio check. Source inspection cannot prove the ContextActionService button lifecycle or visual clarity on mobile.
- Agawan ng Panyo is built from source but has no owner Studio, mobile, or gamepad validation yet. The five original WAV cues need owner upload and approved Roblox IDs; their runtime IDs are blank, so Panyo-specific cues are silent. Kalsada is the only playable Panyo map.
- The replacement third-person tag animation has not been loaded or visually checked in Studio. Its arm-only blend, availability, and two-player replication remain pending owner validation; provenance confirmation remains pending before release.
- Wind dash final acceptance remains with the project owner: close and gameplay views, wall-stop and interruption cleanup, repeated-dash residue, mobile touch, and full gamepad feel. No release or publish has occurred for this item.
- The slide chaining fix is in the newly built `HabulanRush.rbxlx`, but live slide, popup, chain, two-player, mobile, and gamepad checks remain pending. Momentum steps 1 to 4 also await pure and client Command Bar assertions, two-player chase, perfect-roll receipt timing, cap, FOV, layout, and sound playback. In-match settings access now awaits owner validation.
- MS_RPS gameplay, two-player, gamepad, and mobile validation are pending after a successful Rojo build. `RevealSoundId` and `ResultSoundId` are empty placeholders. The GDD, System Spec, production tracker, and DESIGN_LOCK revisions need owner sign-off.
- The animation regression repair has no Studio validation yet by owner request. Existing movement animation playback, first-person arm visibility and cleanup, and third-person tag replication are pending project-owner testing.
- Simple click tagging and both supplied animations have no Studio validation yet by owner request. Two-player replication, first-person isolation, gamepad, and mobile behavior are pending project-owner testing.
- The jump animation replacements have no runtime check yet. Takeoff, airborne, landing, marker firing, and 2-player replication are pending project-owner review. No Studio metadata probe was run at owner choice, so published durations, priorities, loop flags, and keyframe counts for the four new IDs are unverified.
- The sprint animation replacement has no runtime check yet. Loop, speed-fit playback, and 2-player replication are pending project-owner review. The ASSET_LOG row is Pending Review until the owner confirms provenance.
- The first-person exit `AutoRotate` fix has no Studio validation yet. The repro (FP, pounce or vault, return to TP) is pending project-owner review.
- Bot removal has no Studio validation yet: solo search-timeout start, zero bot spawns, solo round end, and two-player target lock and marker checks are pending owner or agent testing. Note the `TayaSpeed` legacy key is now unread and should be dropped in a later Config cleanup round with owner sign-off (it is outside this approved item).
- Pounce aiming and TargetLock findings are recorded but unapproved: no lock-aware pounce direction, dormant `BreakRange` and `LosBreakTime`, no immunity filtering in acquisition, unimplemented `LockDisabled` and `LockDelayUntil`, and no manual look while the lock camera is active.
- Camera Phase 4 has no Studio validation yet. Toggle feel, blend, body yaw, head visibility, aim and lock resumes, mobile button, and effect feel are pending project-owner review. 2-player, gamepad, and mobile checks are required.
- Camera Phase 3 has no Studio validation yet. 2-player, gamepad, and mobile checks are pending project-owner review.
- Camera Phase 2 has no Studio validation yet. 2-player, gamepad, and mobile checks are pending project-owner review.
- Camera Phase 1 has no Studio validation yet. 2-player, gamepad, and mobile checks are pending project-owner review.
- The first-person FOV slider and in-match settings panel have not been visually tested. Owner validation must confirm match access, no visible lobby controls, live FOV changes, and mouse, touch, and gamepad input.
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
8. Current AGENTS.md limits Studio MCP to read-only inspection when explicitly requested. Studio testing and validation belong to the project owner. Repository source remains canonical.
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
28. Camera overhaul proceeds in approved phases. Phase 1 (client base camera director only: third-person shoulder, look input, collision, shoulder swap, sensitivity and invert settings) is approved and implemented. Chase awareness, first person, look-back, chaser indicators, and tag-target UI remain future phases.
29. Camera overhaul Phase 2 is the owner-requested centralized movement camera effect system (sprint, falling, landing, dash, slide, vault, roll; FOV, position, rotation, and shake channels with movement-aware suppression). It is implemented. First person, look-back, chase awareness, chaser indicators, tag-target UI, final-seconds effects, and spectator camera remain future phases.
30. Camera overhaul Phase 3 is the owner-requested chase awareness phase (role camera profiles, Runner hold-to-look-back with a movement-stability assist, chase proximity FOV, chaser edge indicator, Taya advisory tag-target marker, tag-transfer feedback, mobile look-back button). It is implemented. First person, final-seconds effects, spectator camera, and any TargetLock or RS_03 redesign remain future phases.
31. Camera overhaul Phase 4 is the owner-requested first-person view mode: a second mode of the same `CameraDirector` with a deferred blended switch, eye-anchored pose, capsule-safe effect set, body yaw alignment with an AutoRotate contract, head visibility with an RS_03 aim exception, `PounceCamera` FP scaling, and eased FP resume from aim or lock. It is implemented. Spectator camera, final-seconds effects, death cinematics, round-end camera, cinematic sequences, and polish remain future phases.
32. The owner-reported first-person exit regression is approved and fixed: `CameraDirector.stepFacing` hands off `Humanoid.AutoRotate` completely while first person is active and a scripted mechanic (pounce, vault, dash, slide, roll, skill, stun) owns the body, and restores the saved value only on camera-side exits. `PounceController`, the Vault mechanic, movement, and all remotes are untouched.
33. The owner-supplied `rbxassetid://74829353930740` (`HRush_ExaggeratedSprint`) replaces the Batch A sprint ID in `Config.Animations.Sprint`. Studio metadata probe: 0.6 s, Movement priority, looped, 48 keyframes. The previous ID `132688446420207` is superseded.
34. The owner-supplied `rbxassetid://74307357863566`, `rbxassetid://84863749801510`, `rbxassetid://88319270506819`, and `rbxassetid://104821646839230` replace the Batch A JumpStart, Fall, Land, and LandHard IDs in `Config.Animations`. The previous IDs `115591963738630`, `106234834891508`, `83446879560399`, and `93067099789487` are superseded. The new rows are logged Approved at owner direction; no Studio metadata probe was run.
35. For the MS_RPS item, remove MS_02 from the live match loop. Keep the old draft UI and Config value dormant until a separate cleanup is approved. MS_RPS runs before MS_03 each round.
36. Agawan ng Panyo planning scope and Phase 1 were approved. The later owner instruction approved implementation through all phases and enabled the Panyo ballot choice.
37. The project owner approved all Lihim na Target phases. Full reshuffle follows each capture, target lock and Tsinelas are disabled, and a zero-capture round awards no points. Competitive play starts at four and continues a round with three, ending it at two.

## Validation

- 2026-10-23 Lihim na Target full mode: `scripts/check-syntax.ps1`, `scripts/check-notes.ps1`, `git diff --check`, and Rojo build passed. No Studio execution or gameplay test was run by the agent. The owner-run 1, 2, 4, and 8-client matrix and Classic/Panyo regressions remain pending.
- 2026-10-23 Panyo mobile STEAL and Carrier feedback: `scripts/check-syntax.ps1`, `scripts/check-notes.ps1`, `git diff --check`, and Rojo build passed. No Studio execution or gameplay test was run by the agent.
- 2026-10-23 Agawan ng Panyo Phase 3 source review: `scripts/check-syntax.ps1`, `scripts/check-notes.ps1`, `git diff --check`, and Rojo build passed after the invalid-round MVP total fix. The defect was reproduced by source path review, not by a Studio playtest. The owner-run 1, 2, 4, and 8-client matrix and Classic regression are pending.
- 2026-10-23 Agawan ng Panyo full mode: Luau source syntax, notes, `git diff --check`, and Rojo build passed. No Studio execution, gameplay test, mobile test, or gamepad test was run by the agent. Original cue WAV files were generated locally but cannot play in Roblox until owner upload and ID entry.
- 2026-10-23 Agawan ng Panyo Phase 1: source syntax, notes, `git diff --check`, and Rojo build passed. No Studio execution or playtest was run by the agent; owner Classic regression remains pending. The two-choice ballot is dormant until Phase 2 enables Panyo.
- 2026-10-22 first-person FOV 95-degree limit: `scripts/check-syntax.ps1`, `scripts/check-notes.ps1`, `git diff --check`, and Rojo build passed. No Studio test was run; owner should confirm the slider and final first-person camera stop at 95 degrees.
- 2026-10-22 first-person FOV setting: `scripts/check-syntax.ps1`, `scripts/check-notes.ps1`, and Rojo build passed. Settings range, in-match panel visibility, device input, and two-player behavior still require owner Studio testing; no Studio execution was run by the agent.
- 2026-10-22 third-person tag animation replacement: `scripts/check-syntax.ps1`, `scripts/check-notes.ps1`, and Rojo build passed. No Studio execution or playtest was run; animation metadata, arm-only blending, and two-player visibility are unverified.
- 2026-10-22 wind dash: syntax, notes, and `git diff --check` passed; Rojo rebuilt `HabulanRush.rbxlx` after the final source patch and mapped `WindDash` plus `DashVFXEvent`. An earlier two-client Studio run observed one local and one remote rig from an accepted dash, sideways alignment, automatic cleanup, a gamepad ButtonB observer rig, and VFX scales at 0/50/100. A later direct module probe verified death and respawn cleanup. These are implementation checks; the owner has reserved final visual and device validation.
- 2026-10-19 slide chaining local build: owner-requested `rojo build default.project.json -o HabulanRush.rbxlx` passed and generated a 708545-byte place. No publish or Studio gameplay run was performed.
- 2026-10-19 slide chaining: source syntax passed. Pure Studio assertions were updated but have not been run; two-player, mobile, and gamepad gameplay remain pending. No Rojo build or publish was run per owner instruction.
- 2026-10-19 roll popup duration: source syntax, notes, diff whitespace, and Rojo place build passed. Studio visual timing remains pending.
- 2026-10-19 momentum steps 2 to 4: source syntax, notes, test parsing, project JSON, and diff whitespace checks pass. The owner-requested `rojo build default.project.json -o HabulanRush.rbxlx` passed and generated a 705403-byte place file. No publish or Studio gameplay run was performed. Fresh-place runtime compile, two-player, mobile, gamepad, and sound checks remain pending.
- 2026-10-19 momentum slice 1: `scripts/check-syntax.ps1`, `scripts/check-notes.ps1`, test file StyLua parsing, Rojo JSON parsing, and `git diff --check` passed. No place build or publish was run per owner instruction. Pure Studio assertions and two-player/gamepad/mobile gameplay tests have not been run.
- 2026-10-18 MS_RPS pick-time adjustment: syntax, notes, and Rojo build passed. No Studio timing feel check was run.
- 2026-10-18 MS_RPS: Luau syntax and notes checks passed. The owner then requested a Rojo build; `rojo build default.project.json -o HabulanRush.rbxlx` passed. No Studio runtime, multiplayer, gamepad, mobile, or audio test was run. `tests/RpsRules.spec.lua` is ready for Studio.
- 2026-10-18 animation regression repair: Rojo build passed and regenerated `HabulanRush.rbxlx`. No syntax, notes, Studio, multiplayer, gamepad, or mobile test was run.
- 2026-10-18 simple click-to-tag reimplementation: Rojo build passed and regenerated `HabulanRush.rbxlx`. No syntax, notes, Studio, multiplayer, gamepad, or mobile test was run at owner request.
- 2026-10-18 jump animation replacement: `scripts/check-syntax.ps1` passed after the Config edit. `scripts/check-notes.ps1` passed. Rojo build passed and regenerated `HabulanRush.rbxlx`. No Studio metadata probe or runtime test was run (owner choice); takeoff, airborne, landing, marker, and 2-player replication checks pending.
- 2026-10-18 sprint animation replacement: Studio probe loaded `rbxassetid://74829353930740` (`HRush_ExaggeratedSprint`, 0.6 s, Movement, looped, 48 keyframes) from placeId 133869267942827. `scripts/check-syntax.ps1` passed after the Config edit. `scripts/check-notes.ps1` passed. Rojo build passed and regenerated `HabulanRush.rbxlx`. No runtime sprint test was run; loop, speed-fit, and 2-player replication pending.
- 2026-10-18 first-person exit AutoRotate fix: `scripts/check-syntax.ps1` passed after the edit. `scripts/check-notes.ps1` passed. Rojo build passed and regenerated `HabulanRush.rbxlx`. No Studio test was run; the repro (FP, pounce or vault, return to TP, body turns and `AutoRotate` true) is pending.
- 2026-10-18 camera Phase 4: `scripts/check-syntax.ps1` passed after all edits. `scripts/check-notes.ps1` passed. Rojo build passed and regenerated `HabulanRush.rbxlx`. No Studio or 2-player test was run.
- 2026-10-18 TargetLock and pounce aiming analysis (read-only): no code changed and no build needed. Findings verified against `TargetLockController`, `PounceController`, `TagService`, and `Config`. `scripts/check-notes.ps1` rerun after this update.
- 2026-10-18 camera Phase 3: `scripts/check-syntax.ps1` passed. `scripts/check-notes.ps1` passed. Rojo build passed and regenerated `HabulanRush.rbxlx`. No Studio or 2-player test was run.
- 2026-10-18 camera Phase 2: `scripts/check-syntax.ps1` passed. `scripts/check-notes.ps1` passed. Rojo build passed and regenerated `HabulanRush.rbxlx`. No Studio or 2-player test was run.
- 2026-10-18 camera Phase 1: `scripts/check-syntax.ps1` passed. Rojo build passed and regenerated `HabulanRush.rbxlx`. No Studio or 2-player test was run.
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
