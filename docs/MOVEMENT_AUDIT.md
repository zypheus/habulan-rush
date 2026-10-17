# Movement System and Animation Audit

Date: 2026-10-16
Status: Movement upgrade Parts 1 and 2 implemented; Part 2 awaiting project-owner validation
Owner: Project Owner
Task: T09 movement upgrade audit

## Scope and decision gate

This audit compares the current Rojo-mapped movement, camera, input, VFX, server, and animation-authoring code with the proposed movement upgrade. No gameplay code, `Config` value, animation ID, or asset changed in Step 0.

Step 1 was approved by the project owner and implemented on 2026-10-15. It adds configuration, centralized animation metadata, a dedicated server movement state ledger, validated movement requests, rate limits, and passive observation. It does not change movement feel or correct player position.

The project owner amended the animation plan on 2026-10-15. Every movement state now requires a newly authored original R15 animation. Earlier recommendations to reuse sprint pose math or split the existing slide source are superseded. Existing sprint, slide, and dash IDs were allowed only as temporary runtime fallbacks; all three were removed when the Batch A and B IDs were supplied.

## Executive summary

The controller remains client-predicted with log-only server validation. Parts 1 and 2 now add normal air ownership, landing ownership, and current-feet Vault rules while leaving correction disabled.

- Sprint changes `Humanoid.WalkSpeed` immediately. It has stamina, FOV, VFX, and an original sprint animation, but no acceleration ramp.
- Slide is a one-second, constant-speed client sustain. It can start while walking or airborne, has no sprint-speed threshold, no slope response, no steering rate, no early release, and no slide-hop exit.
- Normal jump uses live coyote time, one-shot buffering, committed takeoff momentum, fast-fall force, a terminal cap, and a permanent air-speed cap. Landing now has Soft and Hard ownership with live Land and LandHard playback.
- `MovementAuthority` validates sprint, slide, roll, Vault, landing, normal vertical air behavior, speed, and displacement. Client prediction still moves the character, and server correction remains disabled until the envelope is proven in Studio.
- The existing sprint, slide, and dash clips are legacy runtime fallbacks only. Their pose data must not be copied or lightly modified for the new set.
- Camera effects are spread across SprintVFX, MovementController, TargetLockController, the Roblox PlayerModule, and lobby code. Part 4 requires one director and an explicit yield contract for Tsinelas aim and TargetLock.
- Published sprint, slide, and dash animation IDs are active but are not recorded in `ASSET_LOG.md`. This is a release compliance blocker.

Recommended approach: keep the working gameplay systems, but author every movement animation from new pose data through the Batch 0 pipeline. Add mechanics one at a time only after approval.

## Map capability audit for proposed mechanics

The audit uses the canonical Rojo inputs: `assets/Map.rbxmx`, `Config.Maps`, and the Kalsada geometry built by `Bootstrap.server.lua`.

| Map | Roll on landing | Vault | Wall climb | Swing bar and zipline |
|---|---|---|---|---|
| Kalsada | Supported now for testing. The 150 by 150 street, open court, sidewalks, and spawn ring provide broad flat landing areas. No new map piece is required for the first roll test. | Supported for the 3.5-stud crates under the Part 2 current-feet rule. Four 4-stud jeepneys fail normal first contact from the ground. | Needs new authored routes. The map has 10-stud sari-sari blocks and 14-stud boundary walls, but no parts are tagged `Climbable`, no safe grab volumes exist, and the boundary walls must not become escape routes. Add dedicated climb faces and mantle ledges inside the arena before implementation. | Needs new map pieces. No `SwingBar` or `Zipline` tags, bars, anchors, endpoints, or clear travel corridors exist. Author these as visible traversal lanes before mechanic code. |
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
| Character defaults | `src/ServerScriptService/Bootstrap.server.lua` | Starter walk speed and `Config.Movement.JumpPower` |
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
| Jump | `Config.Movement.JumpPower = 50` | Bootstrap assigns `StarterPlayer.CharacterJumpPower`; normal Roblox jump behavior |

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

## Movement upgrade Part 0 audit

This pass is read-only for gameplay code. Runtime measurements were taken on 2026-10-16 in the generated `HabulanRush.rbxlx` with a temporary flat play-session platform. The platform was destroyed after each case, and the play session was stopped without saving.

### Jump and air physics

Current ownership and behavior:

- `Bootstrap.server.lua` assigns `StarterPlayer.CharacterJumpPower` from `Config.Movement.JumpPower = 50`. Studio measured `Humanoid.UseJumpPower = true`, `Humanoid.JumpPower = 50`, `Humanoid.JumpHeight = 7.2`, and `Workspace.Gravity = 196.2`. Since `UseJumpPower` is true, `JumpHeight` is inactive.
- Normal jump input remains Roblox PlayerModule input. No project script listens to `UserInputService.JumpRequest`, sets `Humanoid.Jump`, or changes the normal jump's vertical velocity.
- `CoyoteTime = 0.10`, `JumpBufferTime = 0.12`, and `AirControlPct = 0.40` exist only as unused Step 6 target values. Coyote time and jump buffering do not exist at runtime.
- Air control is Roblox default Humanoid behavior. There is no project-owned steering percentage, takeoff-speed ledger, horizontal air-speed cap, extra falling force, or terminal fall-speed cap.
- A normal jump preserves the horizontal speed produced by the live walk or sprint path. There is no slide-jump path. Pressing jump during the current slide does not apply `SlideJumpKeepPct`.
- Normal landing has no soft or hard landing owner and no speed penalty. Batch C only buffers the slide action for a Roll during the final `RollWindow`. The published Land and LandHard clips remain metadata-only.
- `MovementAuthority` observes horizontal speed and displacement but has no normal-jump state. It does not validate normal takeoff vertical velocity, apex, or air time.
- Project velocity writers are separate from normal jump: Dash and Vault move `HumanoidRootPart.CFrame`; Slide and Roll sustain horizontal `AssemblyLinearVelocity`; Vault zeros velocity during its path; RS_01 writes one skill takeoff velocity and then applies its skill-flight rules.

Measured flat-ground results:

| Case | Horizontal takeoff speed | Apex above takeoff | Air time | Horizontal distance |
|---|---:|---:|---:|---:|
| Stationary | 0.00 studs/s | 6.40 studs | 0.53 s | 0.00 studs |
| Live walk input | 19.20 studs/s | 6.40 studs | 0.53 s | 10.24 studs |
| Live sprint input | 25.20 studs/s | 6.40 studs | 0.53 s | 13.44 studs |

These are sampled runtime values, not formula-only estimates. The observed takeoff vertical speed was 50.55 studs/s. Frame sampling and Humanoid state timing account for the small difference from the ideal ballistic values of about 6.37 studs and 0.51 seconds at jump power 50 and gravity 196.2.

Gravity usage:

- No project script writes `Workspace.Gravity`.
- `MovementController.client.lua` is the only project script that reads it. That read computes the separate RS_01 skill launch velocity.
- `TsinelasArc.lua` deliberately does not read Workspace gravity. It uses `Config.Skills.RS_03.params.arcGravity`, currently 80, so preserving Workspace gravity still avoids changing normal character physics and RS_01 launch math while leaving the Tsinelas solver independent.

### Batch D Vault

Current height window and probes:

- The client and server raycast down from the current root by `VaultLandingProbeDepth = 8` and treat the hit surface as `footY`. This is nearby ground height, not the character's current airborne feet height.
- The contact ray is at `footY + 1.0`, the clearance ray is at `footY + 3.75`, and the accepted top is greater than 0 and no more than `footY + 3.5`.
- In practice, an obstacle must intersect the 1.0-stud knee ray, so the useful lower bound is about 1 stud for a simple block. There is no explicit `VaultMinH`.
- Detection uses one knee ray, one waist-clearance ray, one downward top ray, and one downward landing ray. It has no chest ray, depth class, exact far-edge surface probe, platform-versus-drop rule, or exclusion tag or attribute.
- Travel must be positive and no more than 8 studs. Any downward landing-ray hit is accepted, including the top of a platform, so current Vault does not preserve the future Vault-versus-Mantle boundary.

Current trigger and movement rules:

- The client probes automatically every 0.05 seconds when lobby warmup or the live round allows movement. There is no extra button.
- Entry requires at least `21 * 1.2 * 0.60 = 15.12` studs/s of horizontal speed and a movement or velocity direction whose dot product with travel is at least 0.5.
- Entry is allowed from Walk, Sprint, Dash, Slide, normal Jumping, and normal Freefall. Dash or Slide is ended before Vault starts. Roll, an existing Vault, stun, input lock, and active RS_01 skill flight block entry.
- The 0.40-second client path interpolates the root over a parabola, writes root `CFrame`, and zeros assembly velocity each Heartbeat. Exit restores 90 percent of entry speed. There is one animation variant.
- The server repeats the role, match, stun, cooldown, finite direction, direction agreement, recent observed horizontal speed, obstacle, height, clearance, travel, and landing checks. It allows ordinary Humanoid airborne states. `IsAirborne` blocks only the separate RS_01 skill state.

Why jumping into an obstacle can Vault today:

The client has no `FloorMaterial` ground gate, and the server also does not reject ordinary Jumping or Freefall. Both sides anchor the knee, waist, top, and landing probes to the ground hit beneath the character. Therefore a jump into a low obstacle can Vault while the root remains within the 8-stud downward ground probe. A high enough jump or drop loses the ground hit and fails. This is an air-capable Vault, but it is not the requested current-feet-relative AirVault rule.

### Camera ownership and conflicts

Roblox documentation confirms that the default camera callback is at render priority 200, lower priorities run first, equal-priority callbacks have undefined order, `CameraType.Custom` is the core-script default mode, `CameraType.Scriptable` disables default camera movement, and `Camera.FieldOfView` defaults to 70 degrees. Studio measured `Enum.RenderPriority.Camera.Value = 200` and `FieldOfViewMode = Vertical` in the generated place.

| Owner | Camera access | Schedule or trigger | Current winner and conflict |
|---|---|---|---|
| Roblox PlayerModule camera | Writes normal Custom camera CFrame from the Humanoid subject and handles zoom and collision | Core camera priority 200 | Owns ordinary in-match camera until a project script switches to Scriptable or writes after it |
| `LobbyUI.client.lua` | Writes `CameraType = Scriptable`, FOV 42, and CFrame; restores Custom, FOV 70, and Humanoid subject on match entry | `HabulanLobbyCamera` at camera priority 201 | Wins every lobby frame. Studio measured Scriptable and FOV 42 in lobby. It is unbound in match |
| `TargetLockController.lua` | Switches to Scriptable and writes CFrame toward the target; restores Custom on release | `TargetLockAssist` at priority 201 | Wins over PlayerModule while locked. It does not respect Reduced Camera. Its captured world-space offset bypasses default camera collision while active |
| `MovementController.client.lua`, RS_03 aim | Saves type, CFrame, FOV, max zoom, mouse behavior, and sensitivity; blends Scriptable CFrame, hides local body parts, then hands off to Custom at max zoom 0.5 | `TsinelasAimCam` at priority 202 during blend | Highest explicit repository CFrame priority. It is disabled by Reduced Camera. Restore can overwrite FOV or max-zoom changes made by another owner during aim |
| `MovementController.client.lua`, RS_01 | Tweens FOV at takeoff and back to a saved absolute base; adds landing CFrame shake | Tween plus `HRUSH_SkillShake` at priority 201 | Shake runs after PlayerModule. Absolute FOV restoration can discard a concurrent delta. Reduced Camera disables the kick and shake |
| `SprintVFX.lua` | Reads camera position for first-person detection and adds a smoothed FOV delta | Heartbeat | Current gameplay FOV owner during ordinary sprint. It respects Reduced Camera, but the VFX intensity slider scales particles and does not scale this FOV delta |
| `MapVoteUI.client.lua` | Reads `CurrentCamera.ViewportSize` only | UI resize | No camera ownership conflict |
| `ReplicatedStorage/VFX/Dash.lua` | Uses `RenderStepped` for cosmetic parts only | RenderStepped | Does not read or write camera state |

No project script writes `Humanoid.CameraOffset`, `Player.CameraMinZoomDistance`, or `Camera.Focus`. RS_03 writes `Player.CameraMaxDistance`. The generated place measured min zoom 0.5 and max zoom 400 before aim.

Current winner by situation:

- Lobby: LobbyUI.
- Ordinary match: Roblox PlayerModule for CFrame, with SprintVFX adding FOV.
- Target lock: TargetLockController for CFrame.
- RS_03 transition: Tsinelas aim at priority 202, then PlayerModule in forced first person.
- RS_01 landing: PlayerModule base CFrame followed by the priority-201 shake.

The same-priority callbacks at 201 do not have a deterministic mutual order. Current role and state gates make the main combinations mostly exclusive, but there is no central arbiter. FOV changes are split between additive SprintVFX updates and absolute Tween restores. Camera effects currently have a Reduced Camera boolean but no camera effect-intensity value. Part 4 should centralize normal movement effects and explicitly yield to Tsinelas aim and TargetLock as required.

### Verified Roblox references

- [Humanoid API](https://create.roblox.com/docs/reference/engine/classes/Humanoid): `UseJumpPower` selects JumpPower instead of JumpHeight, and jump behavior is influenced by Workspace gravity.
- [Workspace Gravity API](https://create.roblox.com/docs/reference/engine/classes/Workspace/Gravity): default gravity is 196.2 studs/s squared.
- [RunService API](https://create.roblox.com/docs/reference/engine/classes/RunService): default camera controls run at priority 200, lower values run earlier, and equal priorities have undefined order.
- [RenderPriority enum](https://create.roblox.com/docs/reference/engine/enums/RenderPriority): Camera is 200.
- [Camera API](https://create.roblox.com/docs/reference/engine/classes/Camera) and [camera guide](https://create.roblox.com/docs/workspace/camera): Custom is the default core-script mode, Scriptable disables default movement, and FieldOfView defaults to 70.

### Part 0 Studio review checklist

1. Open the generated `HabulanRush.rbxlx` and start a solo Play session.
2. Confirm Output reports gravity 196.2, `UseJumpPower = true`, JumpPower 50, and no runtime error from MovementController or MovementAuthority.
3. On flat ground, hold W and jump. Confirm the current baseline is about 6.4 studs of apex, 0.53 seconds airborne, and 10.2 studs of travel at the effective 19.2 studs/s walk speed.
4. Hold Shift and W, reach 25.2 studs/s, and jump. Confirm about 13.4 studs of travel with the same apex and air time.
5. Jump toward the 3.5-stud Kalsada crate above the 15.12 studs/s Vault threshold. Confirm the current implementation can start Vault while the Humanoid is Jumping or Freefall, subject to the 8-stud ground probe.
6. In lobby, confirm Scriptable camera and FOV 42. Enter a match and confirm Custom camera and FOV 70 before sprint effects.
7. Confirm no test changes Workspace gravity and no temporary audit platform remains after the session.

## Part 1 implementation report

Part 1 is implemented and approved after project-owner Studio testing. Part 2 below supersedes the earlier landing and air-control status. Parts 3 and 4 remain untouched.

### Ownership and physics

- `AirMovement.lua` owns normal jump grace windows, character-only falling force, air control, takeoff momentum, and the horizontal air-speed cap.
- JumpPower remains 50. The measured apex remains about 6.4 studs because extra gravity begins only when vertical velocity is downward.
- Falling force uses a `VectorForce` attached to the HumanoidRootPart, with world-relative force and `ApplyAtCenterOfMass = true`.
- The force is `(FallGravityMult - 1) * Workspace.Gravity * AssemblyMass` downward. `FallGravityMult` is therefore the total falling multiplier.
- The force affects only the local character assembly. No code writes `Workspace.Gravity`.
- Studio-only player attributes `HRushDebugFallGravityMult` and `HRushDebugAirControlPct` allow Play-mode comparisons without editing source. Their effective values are exposed as read-only diagnostic attributes.

### Measured flat jumps

Measurements used a temporary flat runtime platform, live W and Shift movement to establish the exact takeoff speed, and the normal Humanoid Jumping state. The platform was not saved.

| FallGravityMult | Case | Target apex | Measured apex | Target air time | Measured air time | Target reach | Measured reach |
|---:|---|---:|---:|---:|---:|---:|---:|
| 1.4 | Walk at 19.2 | About 6.4 | 6.40 | Comparison | 0.50 s | Comparison | 9.60 |
| 1.4 | Sprint at 25.2 | About 6.4 | 6.40 | Comparison | 0.50 s | Comparison | 12.50 |
| 1.6 | Walk at 19.2 | About 6.4 | 6.40 | 0.46 to 0.50 s | 0.49 s | Comparison | 9.36 |
| 1.6 | Sprint at 25.2 | About 6.4 | 6.40 | 0.46 to 0.50 s | 0.48 s | About 11 to 12 | 12.18 |
| 1.8 | Walk at 19.2 | About 6.4 | 6.41 | Comparison | 0.47 s | Comparison | 8.96 |
| 1.8 | Sprint at 25.2 | About 6.4 | 6.40 | Comparison | 0.47 s | About 11 to 12 | 11.76 |

`FallGravityMult = 1.6` is the recommendation. It meets the requested air-time band, keeps the current apex, lands close to the requested sprint reach, and does not remove any current map route. The 1.4 comparison is visibly floatier and reaches 12.50 studs. The 1.8 comparison meets the reach band but gives less timing margin.

### Terminal speed selection

The pre-change drop from the tallest Kalsada point measured 71.94 studs/s at impact. Scaling that result by the square root of 1.6 gives about 91.0 studs/s for the same drop under the selected falling gravity. `TerminalFallSpeed = 100` keeps that existing tallest-map fall uncapped while still bounding longer falls. A tall synthetic drop reached a render-sampled minimum of exactly -100.00 studs/s.

### Coyote time and jump buffer

- `CoyoteTime = 0.10`. A live input test jumped 68.6 ms after leaving a narrow ledge.
- `JumpBufferTime = 0.12`. A live input 115.8 ms before touchdown produced one jump 15.0 ms after landing.
- The buffer is cleared before consumption and marked consumed for the following airborne interval, preventing a repeated JumpRequest from scheduling another landing jump.
- Ground jumps continue through the normal Roblox input path. Coyote and buffered jumps use `Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)`. Studio verified that this produces a normal JumpPower takeoff from Freefall, while assigning `Humanoid.Jump = true` alone did not reliably leave Freefall.
- `JumpRequest` is debounced because Roblox may emit it repeatedly for one held input.

### Momentum, air control, and landing

- The controller records horizontal takeoff velocity and restores it only if the jump transition reduced it. A jump never reduces ordinary takeoff speed.
- Slide jump exits Slide and retains `SlideJumpKeepPct = 0.85`. Studio measured 26.775 studs/s from a 31.5 studs/s slide.
- The permanent horizontal cap is `max(takeoffSpeed, RunnerSprintSpeed * SpeedScale * AirSpeedCapMult)`. The ordinary floor is 28.98 studs/s. An injected 100 studs/s air velocity clamped to 28.98.
- Part 1 shipped with `AirControlPct` at 1.0. Part 2 changes the live default to 0.0 for committed takeoff direction while retaining the Studio override.
- At the Part 1 boundary there was no normal hard-landing speed penalty or live Land and LandHard owner. Part 2 supplies that owner and behavior below.

### Server vertical ledger

`MovementAuthority` now observes and logs:

- positive takeoff only from ground or the coyote tolerance window;
- takeoff vertical speed above JumpPower plus the existing percentage tolerance;
- upward velocity gain after the configured replication observation window;
- falling speed beyond TerminalFallSpeed plus the existing tolerance;
- normal air time beyond the configured maximum and sample tolerance.

Scripted RS_01 air and Vault are exempt from normal-air checks. A clean flat jump ended with zero movement violations, `HRushServerAirborne = false`, and `ServerCorrectionEnabled = false`.

### Map reachability scan

Kalsada has a continuous 150 by 150 street beneath its props. It has no jump-required void between 11 and 14 studs. Binaha has no implemented geometry. The static scan also found no usable ledge with a top between 5.5 and 6.4 studs. Current ledges are primarily 3.5-stud crates, 4-stud jeepneys, 4.5-stud low-gap structures, 10-stud buildings, and 14-stud boundary walls.

Raw AABB separation checks do find decorative-part and spawn-pad pairs in the requested horizontal band, but the street remains beneath every pair. They are not gaps and do not require a jump. The reachability result is therefore:

| Feature band | Features found | Unreachable at 1.4 | Unreachable at 1.6 | Unreachable at 1.8 |
|---|---:|---|---|---|
| Jump-required gaps from 11 to 14 studs | 0 | None | None | None |
| Ledges from 5.5 to 6.4 studs | 0 | None | None | None |

For future map work, the measured sprint reaches are 12.50 studs at 1.4, 12.18 at 1.6, and 11.76 at 1.8. A new 13-stud void would already be unreachable at all three settings, while an 11.5-stud void would remain reachable at all three.

### Verified Roblox references for Part 1

- [Humanoid API](https://create.roblox.com/docs/reference/engine/classes/Humanoid): JumpPower is active when UseJumpPower is true, and ChangeState can request Jumping from Freefall.
- [UserInputService API](https://create.roblox.com/docs/reference/engine/classes/UserInputService): JumpRequest reports jump intent and can fire repeatedly while input is held.
- [VectorForce API](https://create.roblox.com/docs/reference/engine/classes/VectorForce): VectorForce applies constant force to an assembly and supports world-relative center-of-mass application.
- [BasePart API](https://create.roblox.com/docs/reference/engine/classes/BasePart): AssemblyMass represents the connected assembly mass and AssemblyLinearVelocity exposes assembly velocity.

### Part 1 Studio checklist

1. Build and open `HabulanRush.rbxlx`. Start a two-player Clients and Servers session.
2. Confirm both clients spawn with JumpPower 50, Workspace gravity 196.2, and no AirMovement or MovementAuthority error.
3. On flat ground, measure walk and sprint jumps at the default 1.6. Confirm an apex near 6.4 studs, 0.46 to 0.50 seconds of air time, and sprint reach near 11 to 12 studs.
4. In a solo Play comparison, set the local player attribute `HRushDebugFallGravityMult` to 1.4, 1.6, and 1.8. Confirm only the falling half changes. Clear the attribute afterward.
5. Walk off a ledge and press jump within 0.10 seconds. Confirm one normal jump. Repeat outside the window and confirm no coyote jump.
6. Press jump within 0.12 seconds before landing. Confirm one jump on touchdown and no second buffered jump.
7. Sprint-jump and slide-jump. Confirm takeoff does not lose horizontal speed and slide-jump retains 85 percent of slide speed.
8. Inject or reproduce excess air steering and confirm horizontal speed cannot exceed `max(takeoffSpeed, 28.98)`.
9. Set `HRushDebugAirControlPct` to 1.0 and 0.7 in solo Play. Compare steering, then clear the attribute.
10. Use a tall temporary drop and confirm falling speed stops at 100 studs/s without changing Workspace gravity.
11. This Part 1 landing check is superseded by the Part 2 checklist below.
12. On the server, confirm honest jumps leave `HRushMovementViolations` at zero and `ServerCorrectionEnabled` remains false.
13. With two players, observe each other walking, sprinting, jumping, falling, coyote-jumping, buffered-jumping, slide-jumping, rolling, and vaulting. Confirm no remote jitter, speed loss, false authority warning, or role-specific difference.
14. Repeat core jump, buffer, and steering checks with gamepad and mobile controls.
15. Stop Play without saving temporary test geometry or debug attributes.

## Part 2 implementation report

Part 2 is implemented. No Part 3 Vault animation work and no Part 4 camera work has started.

### Air-control decision

`AirControlPct` now defaults to 0.0. This project uses the momentum-first feel associated with traversal games such as Apex Legends, Titanfall 2, Mirror's Edge, and Assassin's Creed as a reference, but implements the project owner's explicit rule: once a normal moving jump starts, the takeoff vector is committed. The module records that horizontal vector and restores it after Humanoid simulation. Direction input cannot turn the jump at 0.0, jumping does not reduce takeoff speed, and the existing air-speed cap remains active. The Studio-only `HRushDebugAirControlPct` attribute can still compare values from 0.0 through 1.0.

A fresh full-sprint fixture entered the jump at the effective 25.2 studs/s sprint speed, landed at 25.20 studs/s, and traveled 11.85 studs. Part 1's approved `FallGravityMult = 1.6`, JumpPower 50, coyote time, jump buffer, terminal speed, and gravity behavior remain unchanged.

### Landing owner

`LandingController.lua` is the single client owner for normal landing classification and presentation. It tracks the maximum root Y during each airborne interval and subtracts landing root Y. Root-space subtraction is equivalent to feet-space subtraction because the standing feet offset is constant for the measured fall.

The controller fires `HRushLandingEvent` with `fallHeight`, `horizontalSpeed`, and `class`. It plays `HRush_Land` or `HRush_LandHard` through the character Animator, rejects empty or placeholder IDs before `LoadAnimation`, and listens for the authored `LandImpact` marker. `HRushLandImpact` exposes that marker to later presentation code. Both are client-only BindableEvents, so no network remote was needed and no camera code was touched.

| Drop case | Expected | Measured fall height | Measured result |
|---|---|---:|---|
| Kalsada building-height drop | Soft | 9.61 studs | Soft, no speed change |
| Kalsada boundary-wall-height drop | Hard | 13.75 to 14.29 studs | Hard, 0.85 speed multiplier for 0.10 s |
| Hard drop plus cancellation hook | Penalty cancelled | 14.29 studs | 0.85 present before cancellation, nil immediately after |

Kalsada's tallest implemented surface is the 14-stud boundary wall. The next major surface is the 10-stud sari-sari building. `HardLandHeight = 12` cleanly separates those two authored drops, so the starting value remains 12. Soft landing does not change sprint state or speed. A valid Vault, Roll, or Slide start calls the landing owner during the active 0.10-second window and clears the multiplier. Roll and Slide already exist, so no stub was required.

The server independently tracks airborne peak Y and landing Y, records `HRushServerFallHeight` and `HRushServerLandingClass`, applies the same short allowed-speed ledger window, and clears that window for accepted Vault, Roll, or Slide state. It only logs violations. `ServerCorrectionEnabled` remains false.

### Chest-level Vault geometry

The live R15 rig printed a standing feet offset of 3.00 studs, calculated as the 1.00-stud HumanoidRootPart half-height plus `Humanoid.HipHeight = 2.00`. Every forward probe uses `feetY = rootY - standingFeetOffset`, including airborne contact.

The client and server now repeat these checks:

- knee, waist, and chest forward rays originate at configured heights above current feet;
- the obstacle top must be 1.5 to 3.5 studs above current feet, with 0.10 studs of contact-settling tolerance;
- a separate ground-below ray limits the top to 7.0 studs above ground;
- a top-surface ray identifies the obstacle and a ray beyond its far edge reads depth and landing ground;
- the landing side must be at least 1.5 studs below the obstacle top;
- depth through 2 studs can use SpeedVault, depth through 5 studs can use StepVault, and anything deeper is rejected;
- contact speed must reach 80 percent of effective sprint speed, or 20.16 studs/s;
- exit speed is 95 percent of entry speed and is never greater than entry speed;
- cooldown is 0.25 seconds.

The first rejected contact with a too-tall obstacle remains rejected until the character leaves that obstacle. This prevents a normal jump into a 5-stud wall from becoming valid only because the feet later rise into the relative-height band. A platform whose far-side ray has less than the configured drop is logged as the future Batch E mantle boundary.

### Vault variants and transitions

All four variants use the existing published Vault animation in Part 2. `HRushVaultVariant` and `HRushServerVaultVariant` expose the accepted tag so Part 3 can replace clips individually.

| From | To | Status |
|---|---|---|
| Sprint | SpeedVault, StepVault, or LowHop | Allowed when speed and geometry pass |
| Jump | AirVault | Allowed |
| Fall | AirVault | Allowed |
| Slide | Vault variant | Allowed; Slide closes first |
| Vault | Jump | Allowed only through a still-live jump buffer after Vault ends |
| Vault | Sprint | Allowed; held Sprint resumes through normal speed ownership |
| Dash | Vault | Rejected as unsafe because Dash also owns scripted movement |
| Roll | Vault | Rejected as unsafe because Roll owns momentum and animation |
| RS_01 skill flight | Vault | Rejected as unsafe because the skill owns airborne motion |

Vault wins when a valid landing-frame Vault and a buffered jump compete. `AirMovement` asks the Vault owner first and consumes the jump buffer only after Vault declines.

The scripted arc checks each root movement step with `Workspace:Blockcast`. A blocking side or obstacle contact interrupts the arc instead of moving through geometry. A valid upward landing contact near the arc end settles the Vault. Stun, tag or role change, round end, character loss, and death also interrupt through one cleanup path and print the reason. Normal completion preserves 95 percent of entry momentum and hands control to the grounded state or normal fall handling.

### Requested Vault fixture matrix

Measurements used temporary Studio-only parts outside Kalsada. They were not saved to the repository.

| Test | Expected | Measured result | Variant |
|---|---|---|---|
| Ground 3.5-stud obstacle at 25.2 studs/s | Vault | Vaulted and cleared | SpeedVault |
| Ground obstacle at 20.0 studs/s | No Vault, below 20.16 gate | Rejected | None |
| Airborne contact with 3.5-stud crate | Vault | Vaulted and cleared | AirVault |
| Jump into 5-stud wall | No Vault | Rejected for first-contact height | None |
| 3.5-stud obstacle with same-height landing platform | No Vault, mantle boundary | Rejected and printed boundary | None |
| Thin 0.5-stud railing | Vault | Vaulted and cleared | SpeedVault |
| 4-stud-deep box | Vault | Vaulted and cleared | StepVault |
| 12-degree slope crate fixture | Vault | Vaulted and cleared | LowHop |

### Server and networking

No new remote was added. `RequestMovementState` already carries the finite horizontal Vault direction. The server derives current feet height, ground height, obstacle top, depth, landing drop, grounded or airborne variant, observed contact speed, distance, and cooldown from its own character and Workspace state. It does not trust a client height, position, speed, variant, or landing claim.

The authority continues to log only. Synthetic same-frame teleport and velocity injection is not accepted as server evidence because it can reach the client predictor before velocity replication. The required two-player test below uses a real run-up and remains the acceptance gate.

### Verified Roblox references for Part 2

- [Humanoid API](https://create.roblox.com/docs/reference/engine/classes/Humanoid): `HipHeight`, `FloorMaterial`, `StateChanged`, state enablement, and `ChangeState` behavior used by the landing and jump owners.
- [HumanoidStateType API](https://create.roblox.com/docs/reference/engine/enums/HumanoidStateType): `Jumping`, `Freefall`, `Landed`, and `Running` transition meanings.
- [WorldRoot API](https://create.roblox.com/docs/reference/engine/classes/WorldRoot): `Raycast` and `Blockcast` geometry queries, direction vectors, filters, hit position, distance, and normal.
- [AnimationTrack API](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack) and [animation events](https://create.roblox.com/docs/animation/events): marker listeners through `GetMarkerReachedSignal`.

### Part 2 Studio checklist

1. Build and open `HabulanRush.rbxlx`. Start Test, Clients and Servers with two players.
2. Confirm both clients print a 3.00-stud standing feet offset and load without LandingController, AirMovement, Vault, or MovementAuthority errors.
3. Sprint-jump while holding forward, then press left, right, or backward in air. Confirm the jump keeps its takeoff direction and does not lose horizontal speed. Set `HRushDebugAirControlPct` to 1.0 for comparison, then clear it.
4. Repeat coyote and buffered jump checks. Land a buffered jump beside a valid obstacle and confirm Vault wins when both are valid on the same frame.
5. Use the 10-stud building and 14-stud boundary wall drops. Confirm Soft near 10, Hard above 12, 0.85 speed for 0.10 seconds, correct Land or LandHard animation, and one LandImpact event.
6. During the hard-landing window, trigger Vault, Roll, and Slide separately. Confirm each accepted action clears `HRushHardLandingSpeedMult` immediately and no double action fires.
7. Run the eight-case matrix above. Confirm the same measured result and variant tag on both clients. Confirm walking at 19.2 and the 20.0 under-gate fixture do not Vault.
8. On the no-drop platform, confirm one throttled mantle-boundary message and no Vault. On an obstacle deeper than 5 studs, confirm no Vault.
9. Interrupt an active Vault by tag or role change, stun, and round end. Confirm one reason is printed, the player does not clip, AutoRotate restores, and movement remains usable.
10. On the server, confirm accepted ground and AirVault requests set the matching server variant, rejected cases log once, honest movement adds no violation, and `ServerCorrectionEnabled` remains false.
11. Have player A Vault and land while player B watches. Confirm the existing Vault, Land, and LandHard animations replicate and no remote jitter or position snap appears.
12. Repeat automatic Vault approaches using gamepad and mobile movement. No separate Vault button should appear or be required.
13. Confirm Workspace gravity remains 196.2 and Part 3 animation IDs plus Part 4 camera behavior remain unchanged.
14. Stop without saving temporary fixtures or debug attributes, then report feel, false positives, and any server warnings.

## Earlier camera and game-feel audit

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
| HRush_Land | `rbxassetid://83446879560399` | Active Soft landing one-shot |
| HRush_LandHard | `rbxassetid://93067099789487` | Active Hard landing one-shot |
| HRush_SlideEnter | `rbxassetid://89876839852879` | Metadata only |
| HRush_SlideLoop | `rbxassetid://106056699835668` | Active loop for the existing single-state slide |
| HRush_SlideExit | `rbxassetid://110417300002501` | Metadata only |
| HRush_SlideJump | `rbxassetid://77860783763073` | Metadata only |
| HRush_Dash | `rbxassetid://118315275767975` | Active one-shot while dashing |

The old Sprint, combined slide, and Dash fallbacks are removed. Six published clips remain metadata-only after Part 2 activates Land and LandHard. This publication pass does not introduce a timer-driven slide animation state machine.

Tracks are loaded from the local character `Animator`. Owner-played tracks can replicate to other clients, but that behavior has not passed the required two-player test. The loader uses `FindFirstChildOfClass("Animator")` without waiting. If the Animator is late, all tracks remain nil. The delayed retry only covers a failed slide load after an Animator was found.

Sprint playback speed is `Humanoid.WalkSpeed / RunnerSprintSpeed`. It is not clamped and divides by the unscaled base speed. Current scale produces 1.2x playback at ordinary sprint and 1.44x during the ex-Taya sprint boost. The proposed safe clamp does not exist.

The default Roblox Animate controller and RunStyleService may continue playing a Movement-priority run track while HRush_Sprint also plays at Movement priority. Equal-priority tracks can blend instead of producing a clean replacement. This interaction needs a live local and remote observation before animation work proceeds.

LandingController now listens for `LandImpact` in Land and LandHard and forwards a client-only impact event. Footsteps and dust still use traveled distance and timers. No runtime listener was added for `RollImpact`, `VaultPlant`, or `VaultClear` in Part 2.

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
| Coyote time and jump buffer | Implemented in Part 1 | Uses normal JumpRequest and keeps RS_01 `IsAirborne` separate |
| Air control | Implemented in Parts 1 and 2 | Commits the takeoff vector at 0.0, supports a Studio override, and yields to scripted air states |
| Landing response | Implemented in Part 2 | One client owner tracks fall height, plays Land or LandHard, exposes events, and owns the cancellable penalty |
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

## Original Animation and mechanic Batch D validation before Part 2

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
- Six published clips remain metadata-only until an approved client movement-state owner integrates them. Roll, Vault, Land, and LandHard code and animation are live.
- Part 2 adds the normal hard-landing owner and penalty. Its remote replication and real-input cancellation timing still require the two-player checklist.
- Kalsada climb, swing, and zipline routes do not exist. Binaha has no implemented map geometry.
- No automated gameplay tests, lint, or CI exist. Syntax, Rojo build, and live two-player tests are required for implementation steps.
- Mobile, gamepad, remote animation replication, slopes, low gaps, and camera ownership all require live Studio evidence.
