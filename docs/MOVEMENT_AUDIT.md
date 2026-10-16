# Movement System and Animation Audit

Date: 2026-10-16
Status: Steps 0 and 1 complete; Batch D Vault implemented, published, and wired; two-player validation pending
Owner: Project Owner
Task: T09 movement upgrade audit

## Scope and decision gate

This audit compares the current Rojo-mapped movement, camera, input, VFX, server, and animation-authoring code with the proposed movement upgrade. No gameplay code, `Config` value, animation ID, or asset changed in Step 0.

Step 1 was approved by the project owner and implemented on 2026-10-15. It adds configuration, centralized animation metadata, a dedicated server movement state ledger, validated movement requests, rate limits, and passive observation. It does not change movement feel or correct player position.

The project owner amended the animation plan on 2026-10-15. Every movement state now requires a newly authored original R15 animation. Earlier recommendations to reuse sprint pose math or split the existing slide source are superseded. Existing sprint, slide, and dash IDs were allowed only as temporary runtime fallbacks; all three were removed when the Batch A and B IDs were supplied.

## Executive summary

The current controller is a workable client-predicted foundation, but it is not server-authoritative and it does not yet support the proposed state-driven movement model.

- Sprint changes `Humanoid.WalkSpeed` immediately. It has stamina, FOV, VFX, and an original sprint animation, but no acceleration ramp.
- Slide is a one-second, constant-speed client sustain. It can start while walking or airborne, has no sprint-speed threshold, no slope response, no steering rate, no early release, and no slide-hop exit.
- Normal jump, fall, and landing use Roblox defaults or a randomized run-style pack. There is no coyote time, jump buffer, tuned air control, hard-landing penalty, or dedicated original movement animation set.
- `MovementAuthority` now validates sprint, slide, and dash requests and passively observes speed and displacement. Client prediction still moves the character, and server correction remains disabled until the envelope is proven in Studio.
- The existing sprint, slide, and dash clips are legacy runtime fallbacks only. Their pose data must not be copied or lightly modified for the new set.
- Camera effects are spread across SprintVFX, MovementController, TargetLockController, and lobby code. A slide camera effect should not be added until those writers have an explicit priority and restoration contract.
- Published sprint, slide, and dash animation IDs are active but are not recorded in `ASSET_LOG.md`. This is a release compliance blocker.

Recommended approach: keep the working gameplay systems, but author every movement animation from new pose data through the Batch 0 pipeline. Add mechanics one at a time only after approval.

## Map capability audit for proposed mechanics

The audit uses the canonical Rojo inputs: `assets/Map.rbxmx`, `Config.Maps`, and the Kalsada geometry built by `Bootstrap.server.lua`.

| Map | Roll on landing | Vault | Wall climb | Swing bar and zipline |
|---|---|---|---|---|
| Kalsada | Supported now for testing. The 150 by 150 street, open court, sidewalks, and spawn ring provide broad flat landing areas. No new map piece is required for the first roll test. | Partially supported now. Four crates are exactly 3.5 studs high and match the proposed starting `VaultMaxHeight`. Four jeepneys are 4 studs high and exceed that starting limit, so they are not valid vault targets without a later approved tuning or geometry change. | Needs new authored routes. The map has 10-stud sari-sari blocks and 14-stud boundary walls, but no parts are tagged `Climbable`, no safe grab volumes exist, and the boundary walls must not become escape routes. Add dedicated climb faces and mantle ledges inside the arena before implementation. | Needs new map pieces. No `SwingBar` or `Zipline` tags, bars, anchors, endpoints, or clear travel corridors exist. Author these as visible traversal lanes before mechanic code. |
| Binaha | Not currently testable. | Not currently testable. | Not currently testable. | Not currently testable. |

Binaha exists only in configuration and map-vote presentation. No Binaha geometry or loading path is implemented, so all four mechanics require map construction before support can be assessed.

### Proposed Studio authoring for Batch F

This is a map proposal only. No swing or zipline code is approved.

- Swing bar: create one anchored Model with a visible bar, a centered `Pivot` Attachment, a non-colliding `GrabVolume` part, and a `ReleaseDirection` Attachment. Tag the Model `SwingBar`. Keep the full swing arc clear of walls, roofs, spawn pads, and the court.
- Zipline: create one anchored Model with visible cable geometry, `Start` and `End` Attachments, a non-colliding start `GrabVolume`, and a clear landing zone beyond `End`. Tag the Model `Zipline`. The attachment order defines the fixed path.
- Place each mechanic first in a low-risk teaching lane, then place any chase-pressure version on an optional route.
- Size clearances from the final R15 animation silhouette and measured movement speeds before dressing the props.

### Proposed movement transition table

This table is documentation only until each mechanic batch is approved. One future state owner should enforce it. Animation changes occur on accepted state transitions, not independent timers.

| From state | Allowed next states |
|---|---|
| Walk | Sprint, Dash, JumpStart, Fall, SlideEnter, Vault, ClimbGrab, SwingGrab, ZipHang |
| Sprint | Walk, Dash, JumpStart, Fall, SlideEnter, Vault, ClimbGrab, SwingGrab, ZipHang |
| Dash | Walk, Sprint, Fall, Vault |
| JumpStart | Fall, Vault, ClimbGrab, SwingGrab, ZipHang |
| Fall | Land, LandHard, Roll, Vault, ClimbGrab, SwingGrab, ZipHang |
| Land | Walk, Sprint |
| LandHard | Walk, Sprint |
| SlideEnter | SlideLoop, SlideExit, SlideJump, Vault |
| SlideLoop | SlideExit, SlideJump, Vault |
| SlideExit | Walk, Sprint, Fall |
| SlideJump | Fall, Vault, ClimbGrab, SwingGrab, ZipHang |
| Roll | Walk, Sprint, Fall |
| Vault | Walk, Sprint, Fall |
| ClimbGrab | ClimbLoop, ClimbMantle, Fall |
| ClimbLoop | ClimbMantle, Fall |
| ClimbMantle | Walk, Sprint, Fall |
| SwingGrab | SwingLoop, SwingRelease, Fall |
| SwingLoop | SwingRelease, Fall |
| SwingRelease | Fall |
| ZipHang | ZipRelease, Fall |
| ZipRelease | Fall |

Starting SlideJump, Roll, or Vault cancels JumpStart and Fall tracks immediately. Transition acceptance remains server-authoritative when mechanics are implemented.

## Canonical source map

Only paths mapped by `default.project.json` are production runtime sources.

| Area | Canonical path | Current responsibility |
|---|---|---|
| Shared values | `src/ReplicatedStorage/Config.lua` | Movement, SprintVFX, settings, audio, skill, and map values |
| Local movement | `src/StarterPlayerScripts/MovementController.client.lua` | Input, stamina, speed, dash, slide, animation playback, ability presentation, and some camera effects |
| Sprint presentation | `src/StarterPlayerScripts/SprintVFX.lua` | Sprint intensity, FOV, lines, limb trails, dust, footsteps, and remote runner trails |
| Sprint startup | `src/StarterPlayerScripts/SprintVFX.client.lua` | Thin module bootstrap |
| Camera assist | `src/StarterPlayerScripts/TargetLockController.lua` | Scriptable target-lock camera at camera priority plus 1 |
| Camera settings | `src/StarterPlayerScripts/ClientSettings.lua`, `src/StarterPlayerScripts/VfxScale.lua` | Reduced-camera and VFX preferences |
| HUD and touch | `src/StarterPlayerScripts/UIController.client.lua` | HUD and a custom RS_03 touch button, but no custom movement layout |
| Character defaults | `src/ServerScriptService/Bootstrap.server.lua` | Starter walk speed and hardcoded jump power |
| Match and temporary tag | `src/ServerScriptService/MatchService.server.lua` | Match state, role attributes, bots, and temporary HRP-distance tagging |
| Planned tag authority | `src/ServerScriptService/TagService.server.lua` | Stub only |
| Skill authority | `src/ServerScriptService/SkillService.server.lua` | RS_01 and RS_03 approval, cooldowns, hit simulation, and stun |
| Animation authoring | `tools/AnimationDev/HRush_AnimDev.lua`, `tools/AnimationDev/HRush_AnimPreview.lua` | Data-driven original R15 animation definitions, validation, building, and local preview |
| Cosmetic run packs | `src/ReplicatedStorage/Cosmetics/RunStyles.lua`, `src/ServerScriptService/RunStyleService.server.lua` | Randomized idle, walk, run, jump, and fall HumanoidDescription animation IDs |

## Current movement values and behavior

`SpeedScale` is currently 1.2 after the approved follow-up balance item. The locked base values remain unchanged.

| Behavior | Config or source value | Effective behavior |
|---|---|---|
| Runner walk | `RunnerWalkSpeed = 16`, `SpeedScale = 1.2` | 19.2 studs/s |
| Runner sprint | `RunnerSprintSpeed = 21`, `SpeedScale = 1.2` | 25.2 studs/s, applied instantly |
| Taya movement | `TayaSpeed = 18`, `SpeedScale = 1.2` | 21.6 studs/s, no stamina |
| Ex-Taya boost | `PostTagSpeedBoostMult = 1.20`, duration 2.0 s | Runner walk 23.04 and sprint 30.24 while active |
| Stamina | 100 max, drain 20/s, regen 16/s after 0.6 s, depleted unlock at 10 | Client-owned. Current values differ from the older system specification defaults of 12/s and 1.0 s |
| Dash | 12 x scale over 0.2 s, cooldown 1.5 s, stamina cost 20 | 14.4-stud client CFrame glide. No server handler |
| Slide entry | `max(role walk speed, horizontal velocity) * 1.25` | Runner walk entry 24, sprint entry 31.5, Taya entry 27, then constant for 1.0 s |
| Slide cooldown | 3.0 s | Starts on entry, so about 2.0 s remains after a natural one-second slide |
| Slide hitbox | `HipHeight * 0.5` | Local Humanoid change only. Server tag code does not read slide state or a reduced profile |
| Jump | `StarterPlayer.CharacterJumpPower = 50` | Hardcoded in Bootstrap, not in `Config.Movement`; normal Roblox jump behavior |

Important behavior details:

- Sprint requires held input, movement input, available stamina, and no dash, slide, recovery, or stun. Taya cannot sprint.
- Keyboard uses Shift for sprint, Q for dash, C for slide, and the default Space jump.
- Gamepad uses L2 or left-stick magnitude over 0.8 for sprint, B for dash, and R1 for slide.
- The ten-hertz stick poll overwrites the same `sprintHeld_GP` flag used by L2. On a controller that reports Thumbstick1, holding L2 with a stick magnitude at or below 0.8 is cleared on the next poll.
- Touch uses ContextActionService-generated actions. No explicit title, position, safe-area layout, auto-sprint toggle, or coordination with the default jump button is implemented.
- Slide requires only movement input. It does not require sprint state, minimum speed, or `FloorMaterial` grounding.
- Slide heading is locked when `SlideSteerLock` is true. When false, it snaps directly to `MoveDirection`; it is not rate-limited steering.
- Slide sustains the same horizontal speed every Heartbeat. There is no decay curve, slope contribution, uphill shortening, release-to-exit, jump cancel, or momentum handoff.
- Normal jump, fall, and land states are not managed. The only explicit airborne state machine belongs to the RS_01 skill, which is outside this upgrade scope.

## Camera and game-feel audit

### Sprint

SprintVFX already applies an additive, frame-rate-independent FOV delta and respects Reduced Camera. Current values are `FovDelta = 5`, `FovInTime = 0.25`, and `FovOutTime = 0.3`. The proposal asks for an 8 to 12 degree push and about 0.2 seconds, so these are tuning changes that require approval.

The intensity calculation uses unscaled 16 and 21 speed endpoints while actual movement is scaled. At the current 1.2 scale, ordinary effective sprint speed still saturates intensity instead of representing the walk-to-sprint range. Local lines start above intensity 0.02, trails at 0.2, and dust at 0.5. This does not meet the proposed 90 percent sprint-speed gate.

### Slide and landing

There is no slide camera dip, slide FOV kick, landing camera bump, or hard-landing camera response. Slide dust and sound fire once on entry. Dust is not surface-tinted and is created per action.

### Camera ownership

Current camera writers include:

- SprintVFX adds and removes an FOV delta.
- RS_01 changes FOV and applies a landing shake.
- RS_03 saves camera state, takes Scriptable control at camera priority plus 2, moves into first person, and later restores saved values.
- TargetLockController takes Scriptable control at camera priority plus 1.
- LobbyUI owns a separate lobby camera path.

The additive sprint FOV implementation is a good pattern, but full state save and restore in another controller can still discard changes made during the saved interval. Slide and landing effects need a single effect owner or a small shared camera contract before more writers are added.

## Animation audit

### Runtime loading and playback

The runtime resolver reads `Config.Animations` and accepts only numeric `rbxassetid://` values. The project owner supplied the following published Batch A and B IDs:

| Track | Published ID | Live runtime state |
|---|---|---|
| HRush_Walk | `rbxassetid://89956272220101` | Metadata only |
| HRush_Sprint | `rbxassetid://132688446420207` | Active loop while sprinting |
| HRush_JumpStart | `rbxassetid://115591963738630` | Metadata only |
| HRush_Fall | `rbxassetid://106234834891508` | Metadata only |
| HRush_Land | `rbxassetid://83446879560399` | Metadata only |
| HRush_LandHard | `rbxassetid://93067099789487` | Metadata only |
| HRush_SlideEnter | `rbxassetid://89876839852879` | Metadata only |
| HRush_SlideLoop | `rbxassetid://106056699835668` | Active loop for the existing single-state slide |
| HRush_SlideExit | `rbxassetid://110417300002501` | Metadata only |
| HRush_SlideJump | `rbxassetid://77860783763073` | Metadata only |
| HRush_Dash | `rbxassetid://118315275767975` | Active one-shot while dashing |

The old Sprint, combined slide, and Dash fallbacks are removed. Wiring the eight metadata-only clips requires an approved state owner and transition rules. This publication pass does not introduce a timer-driven slide animation state machine.

Tracks are loaded from the local character `Animator`. Owner-played tracks can replicate to other clients, but that behavior has not passed the required two-player test. The loader uses `FindFirstChildOfClass("Animator")` without waiting. If the Animator is late, all tracks remain nil. The delayed retry only covers a failed slide load after an Animator was found.

Sprint playback speed is `Humanoid.WalkSpeed / RunnerSprintSpeed`. It is not clamped and divides by the unscaled base speed. Current scale produces 1.2x playback at ordinary sprint and 1.44x during the ex-Taya sprint boost. The proposed safe clamp does not exist.

The default Roblox Animate controller and RunStyleService may continue playing a Movement-priority run track while HRush_Sprint also plays at Movement priority. Equal-priority tracks can blend instead of producing a clean replacement. This interaction needs a live local and remote observation before animation work proceeds.

There are no runtime marker listeners. Footsteps and dust still use traveled distance and timers. Batch A authors `FootstepL` and `FootstepR` in Sprint and `LandImpact` in Land and LandHard. Later placeholders already reserve `RollImpact`, `VaultPlant`, and `VaultClear`.

### Authoring tool

Batch 0 rebuilt `HRush_AnimDev.lua` around one `AnimationSpecs` table. All 21 requested production animations have their own entry with name, loop flag, priority, duration, keyframes, and markers. Batches A through D fill 13 entries with newly authored original pose data. The other eight production keyframe arrays remain empty until their assigned batch.

The builder now:

- creates the full R15 Pose tree from `HumanoidRootPart` through both hands and feet;
- supports Root, Waist, Neck, both Shoulders, Elbows, Wrists, Hips, Knees, and Ankles;
- rejects horizontal Root translation while allowing LowerTorso Y offsets for bob and drop;
- provides cubic easing constants, pose mirroring, and cycle mirroring with a phase offset;
- validates loop closure, marker bounds, joint names, keyframe bounds, and adjacent rotation jumps over 120 degrees;
- uses `AnimationClipProvider:RegisterAnimationClip()` for current local preview;
- spawns an R15 preview rig and supports normal speed, 0.25 speed, and scrubbed poses.

`HRush_PipelineSelfTest` is development-only. It proves the base pipeline and must never be published.

The hierarchy was verified against current Roblox documentation and a generated R15 rig. The generated Studio rig uses `AnimationConstraint` joints with the standard Root, Waist, Neck, shoulder, elbow, wrist, hip, knee, and ankle names.

No ID was invented. The 11 Batch A and B IDs came from the project owner. The other 10 entries retain explicit `REPLACE_ME_HRush_*` placeholders, and the old sprint, combined slide, and dash fallbacks are removed.

### Asset compliance

All 11 published Batch A and B animations are recorded in `ASSET_LOG.md` as original project-owned assets sourced from `tools/AnimationDev/HRush_AnimDev.lua`.

RunStyleService uses Roblox catalog animation IDs for Elder, Pirate, Toy, and Ninja walk, run, jump, and fall sets. Their competition eligibility and provenance are not recorded in `ASSET_LOG.md`. They should not be treated as approved substitutes for the original movement set.

## Server authority and exploit risks

### Critical

1. Movement remains client-predicted. `MovementAuthority` observes speed and displacement but intentionally does not correct position in Step 1.
2. The server owns a slide request ledger and validates cooldown, grounding, role, match state, and observed speed. The current client slide still uses its legacy behavior until Step 3.
3. `RequestDash` now has server validation and a cooldown ledger. The client still performs the predicted dash without waiting for approval, and authoritative pounce interaction remains future TagService work.

### High

1. MatchService exposes a temporary client `TagEvent` request path with no per-player rate limit. Its distance gate is `TAG_RANGE * 3`, where `TAG_RANGE` is already the configured range plus 1.5 studs. This allows a much larger request distance than the normal temporary touch check.
2. Temporary touch tagging checks only HRP distance. It does not use the approved sliding low-gap rule, a server slide state, body profile, line of sight, rewind, or `TagRules`.
3. The planned TagService is still a stub. It cannot validate pounce, slide profile, dash invulnerability, or rewound movement.

### Medium

1. Stamina and sprint state are local only. An exploiter can set arbitrary WalkSpeed without any server detection.
2. Cooldowns count down using client frame time. They are presentation gates, not authority.
3. Server stun saves and restores a previous `WalkSpeed`. Future movement state changes during a stun can make the saved value stale. The movement authority owner should compute allowed speed from state after stun instead of restoring an arbitrary snapshot.
4. Debug movement-adjacent output and role bypasses remain enabled in `Config.Debug`, which can hide authority mismatches during testing.

The first authority implementation should log and correct repeated violations. It should not ban on one sample. Honest clients can exceed simple speed limits briefly because of slopes, collisions, network correction, dash, slide-hop, and server-approved abilities.

## Spec comparison

| Proposed feature | Current status | Adaptation to this codebase |
|---|---|---|
| Sprint ramp | Missing | Add a client target-speed ramp inside the existing speed owner. Mirror the allowed sprint state on the server. Keep stamina logic |
| Sprint FOV and 90 percent VFX gate | Partial | Reuse SprintVFX additive FOV and pooled effects. Fix scaled normalization and add one configured activation threshold |
| Decaying slide | Missing | Replace constant sustain with one explicit slide state containing entry direction, current speed, elapsed time, and exit reason |
| Ground and speed entry checks | Missing | Client predicts checks, server repeats grounded, state, cooldown, membership, and speed checks |
| Limited steering | Missing | Rotate entry direction toward desired direction by a configured degrees-per-second cap |
| Slope response | Missing | Project gravity or ground normal along slide direction with configured caps. Do not trust a client-reported slope |
| Release exit | Missing | Treat slide input as held state on keyboard, gamepad, and touch instead of a one-frame request |
| Slide-hop | Missing | Add only after the server recognizes slide state and can approve the retained-speed envelope |
| Lower profile | Partial client-only | Keep local visual prediction, but give TagService an authoritative slide state and approved profile rule |
| Coyote time and jump buffer | Missing | Add around the default jump request. Do not reuse RS_01 `IsAirborne`, which means skill immunity |
| Air control | Default Roblox behavior | Requires a deliberate movement implementation and multiplayer validation. Avoid per-frame velocity fights with RS_01 |
| Landing response | Missing for normal jump | Track fall start and landing on the local client for presentation, with server limits only for any speed penalty |
| Original movement animation set | Partial | Batches A through D author Walk, Sprint, Dash, JumpStart, Fall, Land, LandHard, the four slide states, Roll, and Vault. The remaining eight clips stay batch-gated |
| Procedural lean and head look | Missing | Add last, on top of stable authored states. It must not fight target lock, aim camera, or animation Motor transforms |
| Mobile auto-sprint and safe buttons | Missing | Replace default unnamed touch actions with a deliberate layout and test against Roblox jump and thumbstick zones |
| Rebindable gamepad | Missing | Move bindings to config or a client binding table only after the final action map is approved |
| Server speed and displacement checks | Missing | Add a dedicated server movement authority module or an approved owner inside an existing service. Do not put it in the client |

## Amended build sequence

1. Batch 0, implemented on 2026-10-15: data-driven authoring, validation, placeholder metadata, and preview workflow.
2. Batch A, implemented on 2026-10-15: newly authored Walk, Sprint, JumpStart, Fall, Land, and LandHard.
3. Batch B, implemented on 2026-10-15: newly authored SlideEnter, SlideLoop, SlideExit, SlideJump, and Dash.
4. Batch C, implemented and published on 2026-10-16: landing-input Roll with a newly authored Roll clip. Two-player validation remains pending.
5. Batch D, implemented and published on 2026-10-16: automatic low-obstacle Vault with a newly authored Vault clip. Published metadata is verified; two-player authority validation remains pending.
6. Batch E: author the climb set and implement climb only after map-route and mechanic approval.
7. Batch F: author swing and zipline sets only after supporting map pieces and mechanic approval.

Each batch stops for review. Published IDs are wired only after the project owner supplies them. The matching fallback is then removed and the asset is recorded in `ASSET_LOG.md`.

## Implemented Step 1 scope

Step 1 is a scaffold only. It does not alter movement feel.

### Config.Movement additions

- `SprintAccelTime`
- `SprintFovBoost`
- `FovTweenTime`
- `SprintVfxMinSpeedPct`
- `SlideMinSpeedPct`
- `SlideStartMult`
- `SlideEndMult`
- `SlideDuration`
- `SlideSteerRate`
- `SlideCooldown`
- `SlideJumpKeepPct`
- `SlideCameraDip`
- `SlideFovKick`
- `CoyoteTime`
- `JumpBufferTime`
- `AirControlPct`
- `LandBumpMax`
- `HardLandHeight`
- `HardLandPenaltyTime`
- Server tolerance, sample window, correction threshold, request rate, and log threshold keys with explicit `[SD]` comments

Existing keys that need a migration decision:

- Replace `SlideSpeedMult` with `SlideStartMult` and `SlideEndMult` when the slide implementation changes, not during a no-behavior scaffold unless aliases are required.
- Replace `SlideSteerLock` with `SlideSteerRate` when Step 3 lands.
- Decide whether sprint FOV values move from `Config.SprintVFX` to `Config.Movement` or remain presentation-owned. Do not keep duplicate live values.
- Move hardcoded jump power 50 into `Config.Movement` without changing its value.

### Config.Animations additions

Batch 0 expanded the table to every requested movement animation. Batches A through D now supply 13 published IDs. The eight later entries use explicit `REPLACE_ME_HRush_*` values. The Sprint and Dash `FallbackId` fields and `SlideLegacy` entry are removed. Runtime loading accepts only numeric `rbxassetid://` strings, so placeholders never reach `LoadAnimation` or preload.

### Server scaffold

- Use a server-owned per-player movement state and cooldown ledger.
- Validate request types and finite vectors, current match membership and state, role, alive character, grounded state, speed threshold, cooldown, and request rate.
- Derive allowed speeds from server config and server state. Never accept a client speed, position, role, or cooldown claim as truth.
- Observe horizontal displacement over a time window and allow configured tolerance for physics and latency.
- Log first violations with a threshold and reason. Start correction only after the allowed envelope is proven in Studio.
- Clear state on death, respawn, leave, round transition, role change, and stun.

Implementation notes:

- `RequestMovementState` accepts `Sprint`, `Slide`, `Roll`, or `Vault` with a boolean active flag. Vault adds one finite, bounded horizontal direction; `RequestDash` keeps its separate direction argument.
- The server derives role, match membership, character state, grounding, speed limits, cooldowns, and displacement limits from server-visible state and Config.
- Server attributes expose `HRushMovementState`, `HRushServerSliding`, `HRushServerDashing`, `HRushServerRolling`, `HRushServerVaulting`, and the observation count for later TagService and Studio inspection.
- `ServerCorrectionEnabled` is false. Step 1 logs the first violation per reason and never bans or repositions a player.
- Roll and Vault are the approved mechanics beyond the scaffold. Other future tuning keys stay unused until their approved implementation steps.

The project owner approved a dedicated module at `src/ServerScriptService/MovementAuthority.lua` with `MovementAuthority.server.lua` as its thin bootstrap. `TagService` remains responsible for tag and pounce authority.

## Step 1 Studio test checklist

1. Open the newly generated place and start a two-player Clients and Servers test.
2. Confirm Server Output has no MovementAuthority startup assertion or runtime error.
3. Inspect each player for `HRushMovementState`, `HRushServerSliding`, `HRushServerDashing`, and `HRushMovementViolations`.
4. Sprint as a Runner and confirm the server state changes from `Walk` to `Sprint` and back without changing movement feel.
5. Slide while sprinting and grounded. Confirm the state changes to `Slide`, then returns to `Walk` on exit.
6. Attempt a walking or airborne slide. The legacy client may still predict it, but the server must reject the request, log the reason once, and never reposition the player.
7. Dash once, then attempt another dash before cooldown. Confirm the first records `Dash` and the second records a cooldown violation without changing prediction.
8. Walk, sprint, collide, jump, and move on slopes normally. Record any false speed or displacement warning.
9. Test death, respawn, tag role change, stun, and round end. Confirm server movement state and cooldowns clear.
10. Confirm `ServerCorrectionEnabled` is false and no test causes a server position snap.

## Animation Batch 0 validation

- Repository Luau syntax check passed on 2026-10-15.
- The Rojo build passed on 2026-10-15.
- A generated R15 rig confirmed the 15 standard joint names and connected body parts.
- The pipeline self-test built three keyframes, preserved the full hand and foot Pose tree, attached `PipelineMidpoint`, and rejected an empty production placeholder.
- Validator branch tests detected a loop mismatch, an unflagged rotation jump over 120 degrees, and an out-of-range marker. Restored data validated, and `buildAll()` removed stale HRush sequences.
- In Studio Play mode, normal preview advanced to 0.150 seconds and 0.25-speed preview advanced to 0.033 seconds over the same sample. Scrub held at 0.250 seconds.
- Temporary Studio validation objects were removed after the test. Repository files remain canonical.

## Animation Batch A validation

- Repository Luau syntax check passed after authoring and after the scrub preview fix.
- `validateAll()` passed and `buildAll(false)` produced exactly six production KeyframeSequences.
- Walk uses seven keyframes over 0.700 seconds. Sprint uses seven keyframes over 0.450 seconds. JumpStart uses five keyframes over 0.200 seconds. Fall uses five keyframes over 0.600 seconds. Land uses five keyframes over 0.250 seconds. LandHard uses seven keyframes over 0.400 seconds.
- Sprint markers resolved to `FootstepL` at 0.000 and `FootstepR` at 0.225. Land and LandHard resolved `LandImpact` at 0.080 and 0.100.
- Every Batch A clip passed normal-speed playback, 0.25-speed playback, and midpoint scrubbing in Studio Play mode with full track weight.
- Visual samples confirmed the Sprint airborne pose at 0.115 and the LandHard deep crouch with a planted hand at 0.160.
- Scrubbing now forces preview weight to 1 before pausing. This fixes the rest-pose display that occurred when a zero-speed track was paused during its blend-in.
- The authoring validation ended before publication. The later publication pass wired the six project-owner-supplied Batch A IDs; repository source remains canonical.

## Animation Batch B validation

- Repository Luau syntax check passed after authoring all five table entries.
- `validateAll()` returned true and `buildAll(false)` produced 11 completed production KeyframeSequences, including all five Batch B clips.
- Dash uses six keyframes over 0.250 seconds. SlideEnter uses four keyframes over 0.120 seconds. SlideLoop uses five keyframes over 0.450 seconds. SlideExit uses four keyframes over 0.150 seconds. SlideJump uses five keyframes over 0.300 seconds.
- Every Batch B clip passed normal-speed playback, 0.25-speed playback, and midpoint scrubbing in Studio Play mode with full track weight.
- The first SlideEnter playback assertion sampled before its standard 0.08-second blend completed. Moving the test sample to 0.096 seconds passed without changing the animation or blend time.
- Rear and side visual samples of SlideLoop confirmed a reclined torso, one extended leg, one tucked leg, and wide braced arms.
- SlideEnter ends on the exact SlideLoop opening pose. SlideExit and SlideJump start on the same pose. SlideExit ends on Sprint's opposite contact pose.
- The authoring validation ended before publication. The later publication pass wired the five project-owner-supplied Batch B IDs; repository source remains canonical.

## Animation Batch A and B publication wiring

- All 11 supplied IDs are present in `Config.Animations` and recorded in `ASSET_LOG.md`.
- Sprint and Dash no longer use `FallbackId`, and `SlideLegacy` is removed.
- The existing single-state slide loads and preloads `SlideLoop`. SlideEnter, SlideExit, and SlideJump remain metadata until an approved state-machine change.
- Repository syntax, notes, and Rojo build checks passed after wiring.
- A fresh-build Studio probe loaded and played all 11 IDs. Ten assets matched the authored duration, loop flag, priority, and keyframe count.
- The supplied Fall ID `rbxassetid://106234834891508` repeatedly returned a 0.25-second, Action, non-looping, five-keyframe clip. The authored source is 0.60 seconds, Movement, looping, and five keyframes. The project owner confirmed the ID is correct; recheck this metadata difference when Fall receives a live state owner.

## Animation and mechanic Batch C validation

- `Config.Movement` now owns `RollWindow = 0.15`, `RollDuration = 0.45`, and `RollSpeedBonus = 0.10`.
- The existing slide action starts Roll when pressed during the final configured pre-landing window. Keyboard C, gamepad ButtonR1, and the existing touch slide action share this path, so no new mobile button was added.
- Roll preserves the accepted horizontal direction and momentum, adds 10 percent of effective Runner sprint speed, lasts 0.45 seconds, and grants no tag or pounce invulnerability.
- `MovementAuthority` validates match state, role, alive character, stun state, conflicting movement state, request rate, and a server-observed prompt landing. A short pending request closes the client/server `FloorMaterial` replication race without trusting a client landing claim.
- Client prediction also checks both the Humanoid state transition and grounded `FloorMaterial`, because those signals can settle in either order.
- Roll cancels on stun, role change, round end, death, respawn, or a new jump or freefall transition. Sprint, Slide, Dash, and skill entry are gated while Roll is active.
- `HRush_Roll` uses seven keyframes over 0.45 seconds, Action priority, non-looping, and `RollImpact` at 0.14 seconds. Normal, 0.25-speed, and scrubbed preview checks passed.
- A fresh-build solo client/server test reproduced both landing replication races, verified the fixes, then observed client Roll and server Roll in the same attempt with zero authority violations. The server returned to `Walk` after the configured duration.
- `Config.Animations.Roll.Id` is `rbxassetid://97323662606589`. Studio loaded and played it with 0.45-second, Action, non-looping metadata.
- The repository syntax check, Rojo build, and diff whitespace check pass. The required two-player, gamepad, mobile, and published-animation replication checks remain pending.

## Animation and mechanic Batch D validation

- `Config.Movement` owns all Vault values, including the 3.5-stud height cap, 60 percent entry threshold, 90 percent retained speed, 0.40-second duration, probes, clearance, travel cap, and cooldown.
- Vault contact is automatic, so keyboard, gamepad, and touch share the same path and no mobile button or new remote was added.
- The client predicts a short upright parabolic root arc. It can enter from walk, sprint, dash, jump or fall, and slide states, but never Roll or an active skill flight. Stun, role change, round end, death, and respawn cancel it.
- The server validates membership, round state, role, character, stun, skill state, request rate, cooldown, finite direction, direction agreement, recent server-observed speed, knee contact, high-body clearance, obstacle top, 3.5-stud cap, travel cap, and landing ground.
- Ground-relative probes avoid false rejection from avatar-specific HipHeight. A short server-observed velocity window avoids rejecting legitimate client prediction after it freezes velocity for the scripted arc.
- `HRush_Vault` uses seven keyframes over 0.40 seconds, Action priority, non-looping, `VaultPlant` at 0.10 seconds, and `VaultClear` at 0.26 seconds. `validateAll()` passed and `buildAll(false)` produced 13 completed production sequences.
- Normal playback reached 0.171 seconds. Quarter-speed playback reached 0.104 seconds after 0.40 seconds with a 0.400-second track length. Plant, swing, and clear silhouettes were visually reviewed on an AnimationConstraint R15 rig.
- Fresh runtime testing found and fixed the client controller's Luau 200-register limit, then loaded and attached the controller successfully.
- A local Kalsada test automatically cleared an exact 3.5-stud crate. The first live-round authority attempt exposed the velocity replication race described above. The final server-acceptance retest and required two-player test remain pending because Studio closed.
- `Config.Animations.Vault.Id` is `rbxassetid://88476053772200`, supplied by the project owner and recorded in `ASSET_LOG.md`. Studio verified seven keyframes, 0.40-second duration, Action priority, and non-looping metadata. Replication checks remain pending.

## Known risks and blockers

- Step 1 has project-owner approval and is implemented. Its live two-player validation remains pending.
- The implemented `SpeedScale` change affects every speed ceiling and speed-derived distance. Its live 2-player validation remains pending, and it must stay separate from the movement upgrade.
- Movement authority now has a dedicated canonical module. TagService integration for slide profile and pounce remains future work.
- Existing run-style animation IDs also need competition eligibility review.
- Thirteen Batch A through D clips have published IDs. The other eight production entries remain ID and pose placeholders.
- All 11 published assets load under the experience owner. The confirmed Fall ID metadata differs from its authored source and needs transition testing when Fall becomes live. Local and remote gameplay playback still require two-player evidence.
- Eight published clips are intentionally metadata-only until an approved client movement-state owner integrates them. Roll code and animation are live.
- The existing codebase has no normal hard-landing penalty. Batch C preserves that behavior; adding one belongs to a separately approved landing step.
- Kalsada climb, swing, and zipline routes do not exist. Binaha has no implemented map geometry.
- No automated gameplay tests, lint, or CI exist. Syntax, Rojo build, and live two-player tests are required for implementation steps.
- Mobile, gamepad, remote animation replication, slopes, low gaps, and camera ownership all require live Studio evidence.
