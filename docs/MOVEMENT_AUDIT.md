# Movement System and Animation Audit

Date: 2026-10-15
Status: Steps 0 and 1 complete; Step 1 live validation pending
Owner: Project Owner
Task: T09 movement upgrade audit

## Scope and decision gate

This audit compares the current Rojo-mapped movement, camera, input, VFX, server, and animation-authoring code with the proposed movement upgrade. No gameplay code, `Config` value, animation ID, or asset changed in Step 0.

Step 1 was approved by the project owner and implemented on 2026-10-15. It adds configuration, centralized animation metadata, a dedicated server movement state ledger, validated movement requests, rate limits, and passive observation. It does not change movement feel or correct player position.

## Executive summary

The current controller is a workable client-predicted foundation, but it is not server-authoritative and it does not yet support the proposed state-driven movement model.

- Sprint changes `Humanoid.WalkSpeed` immediately. It has stamina, FOV, VFX, and an original sprint animation, but no acceleration ramp.
- Slide is a one-second, constant-speed client sustain. It can start while walking or airborne, has no sprint-speed threshold, no slope response, no steering rate, no early release, and no slide-hop exit.
- Normal jump, fall, and landing use Roblox defaults or a randomized run-style pack. There is no coyote time, jump buffer, tuned air control, hard-landing penalty, or dedicated original movement animation set.
- `MovementAuthority` now validates sprint, slide, and dash requests and passively observes speed and displacement. Client prediction still moves the character, and server correction remains disabled until the envelope is proven in Studio.
- The existing sprint and slide authoring work is useful. `HRush_Sprint` already matches much of the desired silhouette, while the combined `HRush_Slide` clip can guide the new Enter, Loop, and Exit clips.
- Camera effects are spread across SprintVFX, MovementController, TargetLockController, and lobby code. A slide camera effect should not be added until those writers have an explicit priority and restoration contract.
- Published sprint, slide, and dash animation IDs are active but are not recorded in `ASSET_LOG.md`. This is a release compliance blocker.

Recommended approach: extend the current systems. Add shared movement state and server validation first, then replace one movement behavior at a time. Do not rewrite the working stamina, input bridge, VFX pooling, animation preload, or original pose math without a demonstrated need.

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
| Animation authoring | `tools/AnimationDev/HRush_AnimDev.lua` | Original R15 sprint, combined slide, dash, and pose preview helpers |
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

Current IDs are stored in `Config.Movement`, not a `Config.Animations` table:

| Track | Current ID | Runtime settings | Playback |
|---|---|---|---|
| HRush_Sprint | `rbxassetid://92487449831774` | Movement priority, looped | `Play(0.15)` while sprinting, `Stop(0.15)` otherwise |
| HRush_Slide | `rbxassetid://129414076083716` | Action priority, non-looping | `Play(0.05)`, speed-fitted to `SlideDuration`, `Stop(0.1)` on exit |
| HRush_Dash | `rbxassetid://126630478624602` | Action priority, non-looping | `Play(0.08)`, cut when the 0.2-second dash ends |

Tracks are loaded from the local character `Animator`. Owner-played tracks can replicate to other clients, but that behavior has not passed the required two-player test. The loader uses `FindFirstChildOfClass("Animator")` without waiting. If the Animator is late, all tracks remain nil. The delayed retry only covers a failed slide load after an Animator was found.

Sprint playback speed is `Humanoid.WalkSpeed / RunnerSprintSpeed`. It is not clamped and divides by the unscaled base speed. Current scale produces 1.2x playback at ordinary sprint and 1.44x during the ex-Taya sprint boost. The proposed safe clamp does not exist.

The default Roblox Animate controller and RunStyleService may continue playing a Movement-priority run track while HRush_Sprint also plays at Movement priority. Equal-priority tracks can blend instead of producing a clean replacement. This interaction needs a live local and remote observation before animation work proceeds.

There are no marker listeners. Footsteps and dust use traveled distance and timers. No `FootstepL`, `FootstepR`, `SlideStart`, or `LandImpact` markers are authored or configured.

### Authoring tool

`HRush_AnimDev.lua` builds three original R15 sequences:

- `HRush_Sprint`: a 0.64-second loop with 24 sampled intervals plus the wrap frame. It already has 18-degree forward lean, strong arm swing, 90-degree elbow carry, torso counter-rotation, head compensation, knee drive, and an airborne stride phase. It is close to the requested enhanced sprint silhouette.
- `HRush_Slide`: one 1.0-second non-looping clip with an entry at 0.12, glide keys through 0.70, a tuck at 0.85, and a sprint-pose handoff at 1.0. It is not split into Enter, Loop, and Exit assets.
- `HRush_Dash`: a 0.42-second non-looping original clip. Dash is outside this movement-upgrade scope except where shared state or camera ownership interacts with it.

The builder sets sequence priority and loop state correctly. It exposes `showAt`, `reset`, `setJointsEnabled`, `hardPose`, and `hardReset`, so individual times can be previewed on an R15 rig. It does not provide a single command that lists and scrubs every animation, and its animation definitions are not all in one uniform data table. Sprint is procedural, while slide and dash use separate key tables.

Missing authored movement assets:

- HRush_Slide_Enter
- HRush_Slide_Loop
- HRush_Slide_Exit
- HRush_JumpStart
- HRush_Fall
- HRush_Land
- Optional HRush_SlideJump

No new IDs should be invented. Step 1 should create empty placeholders in `Config.Animations`; publication and `ASSET_LOG.md` entries happen only after the human publishes original sequences.

### Asset compliance

The active sprint, slide, and dash animation IDs have no rows in `ASSET_LOG.md`. AI_LOG describes their authoring and publication history, but that does not replace the required asset record. The current sprint ID also differs from the older sprint ID recorded in AI_LOG, so provenance must identify the exact active revision.

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
| Original movement animation set | Partial | Preserve sprint pose math. Split the slide phases, then add jump, fall, and land builders with markers |
| Procedural lean and head look | Missing | Add last, on top of stable authored states. It must not fight target lock, aim camera, or animation Motor transforms |
| Mobile auto-sprint and safe buttons | Missing | Replace default unnamed touch actions with a deliberate layout and test against Roblox jump and thumbstick zones |
| Rebindable gamepad | Missing | Move bindings to config or a client binding table only after the final action map is approved |
| Server speed and displacement checks | Missing | Add a dedicated server movement authority module or an approved owner inside an existing service. Do not put it in the client |

## Recommended build sequence

The requested ten-step order is viable with these adjustments:

1. Completed on 2026-10-15: apply the separate approved `SpeedScale` 1.2 balance item. Live 2-player validation is still required before using the effective speeds as the final validation baseline.
2. Completed on 2026-10-15: added `Config.Animations`, new `Config.Movement` values, a server-owned movement state ledger, request validation, logging, and passive speed/displacement observation. Correction remains disabled.
3. Step 2: add sprint ramp and reuse SprintVFX after fixing scale normalization and the 90 percent gate. Improve the existing sprint source instead of replacing it.
4. Step 3: replace slide constant sustain with entry, decay, steering, ground, slope, cooldown-after-exit, and camera state. Preserve existing dust, sound, and HipHeight restoration patterns.
5. Step 4: split the current slide source into Enter, Loop, and Exit sequences. Drive transitions from the slide state, not independent timers.
6. Step 5: add early release and slide-hop only after the server state ledger is authoritative.
7. Step 6: add normal jump buffer, coyote time, air control, JumpStart, and Fall without changing RS_01 skill behavior.
8. Step 7: add landing height tracking, hard-landing penalty, Land animation, and marker-driven hooks.
9. Step 8: add procedural lean and head look through one animation polish layer.
10. Step 9: replace fixed and conflicting input paths with approved keyboard, gamepad, and mobile bindings. Include auto-sprint and safe touch layout.
11. Step 10: enable correction thresholds after telemetry, then perform a live two-player abuse and remote-animation test.

Vault, mantle, chase catch-up, and sprint stamina redesign remain proposal-only. Existing stamina stays unless separately approved.

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

Create one table for IDs, priorities, loop flags, fade times, safe playback-speed limits, and marker names. Preserve the three real IDs already in use. Add empty ID placeholders for unpublished original animations.

### Server scaffold

- Use a server-owned per-player movement state and cooldown ledger.
- Validate request types and finite vectors, current match membership and state, role, alive character, grounded state, speed threshold, cooldown, and request rate.
- Derive allowed speeds from server config and server state. Never accept a client speed, position, role, or cooldown claim as truth.
- Observe horizontal displacement over a time window and allow configured tolerance for physics and latency.
- Log first violations with a threshold and reason. Start correction only after the allowed envelope is proven in Studio.
- Clear state on death, respawn, leave, round transition, role change, and stun.

Implementation notes:

- `RequestMovementState` accepts only `Sprint` or `Slide` with a boolean active flag. `RequestDash` keeps its finite, bounded direction argument.
- The server derives role, match membership, character state, grounding, speed limits, cooldowns, and displacement limits from server-visible state and Config.
- Server attributes expose `HRushMovementState`, `HRushServerSliding`, `HRushServerDashing`, and the observation count for later TagService and Studio inspection.
- `ServerCorrectionEnabled` is false. Step 1 logs the first violation per reason and never bans or repositions a player.
- Legacy sprint, slide, dash, and jump behavior remains unchanged. Future tuning keys are present but stay unused until their approved implementation steps.

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

## Known risks and blockers

- Step 1 has project-owner approval and is implemented. Its live two-player validation remains pending.
- The implemented `SpeedScale` change affects every speed ceiling and speed-derived distance. Its live 2-player validation remains pending, and it must stay separate from the movement upgrade.
- Movement authority now has a dedicated canonical module. TagService integration for slide profile and pounce remains future work.
- Published movement animation provenance is incomplete in `ASSET_LOG.md`.
- Existing run-style animation IDs also need competition eligibility review.
- No automated gameplay tests, lint, or CI exist. Syntax, Rojo build, and live two-player tests are required for implementation steps.
- Mobile, gamepad, remote animation replication, slopes, low gaps, and camera ownership all require live Studio evidence.
