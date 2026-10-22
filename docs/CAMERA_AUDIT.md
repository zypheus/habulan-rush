# Habulan Rush Camera Audit

Audit date: 2026-10-17
Scope: read-only static audit of every camera-relevant system in the repository, to inform a safe third-person shoulder camera (and later first-person) director.
Constraints honored: no gameplay code, config, logs, generated place files, or assets were changed. This report is the only artifact created.

---

## 1. Purpose and method

This audit finds every current writer and reader of `Workspace.CurrentCamera`, every `CameraType`, `CFrame`, and `FieldOfView` mutation, every `BindToRenderStep` that participates in the camera pipeline, and every input, state, and signal a future camera director would need to respect.

Method: static reading of the Rojo-mapped files listed in `default.project.json`, plus grep across `src/`. Nothing is marked live-verified because a two-client Studio session was out of scope for a read-only audit.

Cross-reference: `docs/UPGRADE_REPORT.md` (2026-10-15) already flagged camera ownership as a risk. This report supersedes its camera lines with the 2026-10-16 pounce/tag integration state.

---

## 2. Executive summary

- There is no single camera owner. Six client scripts mutate the live camera, mostly additively, with no shared coordinator.
- Three scripts can force `CameraType.Scriptable` (LobbyUI, TargetLockController, MovementController aim). They restore "Custom" independently and do not coordinate.
- FOV is written additively in at least four places (PounceCamera, SprintVFX, MovementController skill FOV, LobbyUI) with different models. Additive delta and absolute assignment coexist and can fight.
- PounceCamera is already an additive, after-Camera presenter (`Camera.Value + 4`). It is the closest existing pattern to what a camera director wants.
- `PounceController.client.lua` is only a require shim; `PounceController.lua` is the state machine and the caller of `PounceCamera`.
- The game currently has no real first-person gameplay camera. First person only appears as a terminal state of the RS_03 Tsinelas aim blend.
- All camera code lives in `StarterPlayerScripts`. There is no `CameraDirector`, no `StarterCharacterScripts`, and no camera module in `ReplicatedStorage`.
- A director can be added as a new client ModuleScript and adopted by removing or demoting the Scriptable writers. It must not be added as a seventh independent `cam.CFrame` writer.

---

## 3. Repository and runtime map (camera-relevant)

Source of truth for runtime paths is `default.project.json`.

- `ReplicatedStorage/Config.lua`: all camera-related tunables.
- `ReplicatedStorage/Remotes/`: 19 RemoteEvents (list in section 15).
- `StarterPlayer/StarterPlayerScripts/`: all client camera code.
- `Workspace/Map`: `assets/Map.rbxmx` (baseplate and spawn only).
- `ServerScriptService/*`: no camera ownership; publishes state the client camera reads.

Client scripts mapped under `StarterPlayerScripts` (from `default.project.json`):

| Runtime name | File | Camera role |
|---|---|---|
| MovementController | `MovementController.client.lua` | Scriptable aim cam, skill FOV, shake, dash/slide/vault CFrame |
| AirMovement | `AirMovement.lua` | Render step at Character priority (not camera) |
| LandingController | `LandingController.lua` | Publishes landing attributes |
| PounceController (module) | `PounceController.lua` | Pounce state machine, calls PounceCamera |
| PounceBootstrap | `PounceController.client.lua` | Require shim: `require(...PounceController).start()` |
| PounceCamera | `PounceCamera.lua` | Additive pounce offsets and FOV |
| PounceEffects | `PounceEffects.lua` | Pounce VFX and audio |
| SprintVFX | `SprintVFX.lua` | Additive sprint FOV |
| SprintVFXBootstrap | `SprintVFX.client.lua` | Bootstrap |
| TargetLockController (module) | `TargetLockController.lua` | Scriptable lock-on camera (Taya) |
| TargetLockBootstrap | `TargetLockController.client.lua` | Require shim |
| UIController | `UIController.client.lua` | HUD, touch Tsinelas button, attribute reads |
| LobbyUI | `LobbyUI.client.lua` | Lobby Scriptable camera, settings panel |
| MapVoteUI | `MapVoteUI.client.lua` | Reads camera ViewportSize only |
| ClientSettings | `ClientSettings.lua` | Settings store (reducedCamera) |
| AudioRouter | `AudioRouter.lua` | Not camera |
| MusicController | `MusicController.lua` | Not camera |
| VfxScale | `VfxScale.lua` | `reducedCamera()` gate used by camera effects |

---

## 4. Camera ownership inventory

| Owner | File | CameraType | CFrame | FieldOfView | Render step | Gated by |
|---|---|---|---|---|---|---|
| Lobby camera | `LobbyUI.client.lua:2299` | Forces Scriptable (`:2306`) | Writes every frame (`:2316`) | Sets 42 (`:2307`) | `HabulanLobbyCamera`, `Camera.Value + 1` | `not HRushInMatch` (bound/unbound by `:2390`) |
| Target lock | `TargetLockController.lua:429` | Forces Scriptable (`:425`) | Lerps CFrame (`:382`) | none | `ASSIST_BIND`, `Camera.Value + 1` | Taya only, lock active |
| RS_03 aim | `MovementController.client.lua:2295` | Scriptable during blend (`:2208`), Custom at end (`:2214`) | Lerps CFrame (`:2209`) | caches/restores only | `AIMCAM_BIND`, `Camera.Value + 2` | Hold-to-aim |
| Skill FOV | `MovementController.client.lua:1465` | none | none | Tween to `base + fovBoost` (`:1468`) | none (TweenService) | Skill takeoff/landing |
| Skill shake | `MovementController.client.lua:1493` | none | Multiplies CFrame (`:1502`) | none | `HRUSH_SkillShake`, `Camera.Value + 1` | Skill landing |
| Pounce camera | `PounceCamera.lua:98` | none | Multiplies CFrame (`:84`) | Additive delta (`:71`) | `HRUSH_PounceCamera`, `Camera.Value + 4`; reset `- 1` | Pounce phases |
| Sprint FOV | `SprintVFX.lua:538` | none | none | Additive delta (`:538`) | Heartbeat, not a camera bind | Sprinting |
| Lobby/map UI | `MapVoteUI.client.lua:141` | none | none | none | reads ViewportSize | Vote UI |
| Air control | `AirMovement.lua:358` | none | none | none | `HRUSH_AirControl`, `Character.Value + 1` | Airborne |

Confirmed: no other file reads or writes `Workspace.CurrentCamera.CFrame` for presentation. `MapVoteUI` and `UIController` read the camera for UI scale only.

---

## 5. Render step priority map

Roblox runs render steps in ascending `Enum.RenderPriority` order. The default camera (`ClassicCamera`) runs at `Camera` (200). Steps below apply, from lowest to highest:

| Priority expression | Value | Bind name | File | Action |
|---|---|---|---|---|
| `Camera.Value - 1` | 199 | `HRUSH_PounceCameraReset` | `PounceCamera.lua:97` | Removes last frame's additive offset/FOV before anything else writes |
| `Camera.Value + 1` | 201 | `HabulanLobbyCamera` | `LobbyUI.client.lua:2299` | Writes lobby pose, forces Scriptable |
| `Camera.Value + 1` | 201 | `ASSIST_BIND` | `TargetLockController.lua:429` | Lock-on lerp, forces Scriptable |
| `Camera.Value + 1` | 201 | `HRUSH_SkillShake` | `MovementController.client.lua:1493` | Horizontal jitter and roll |
| `Camera.Value + 2` | 202 | `AIMCAM_BIND` | `MovementController.client.lua:2295` | RS_03 first-person blend |
| `Camera.Value + 4` | 204 | `HRUSH_PounceCamera` | `PounceCamera.lua:98` | Applies pounce offset/FOV last |
| `Character.Value + 1` | 301 | `HRUSH_AirControl` | `AirMovement.lua:358` | Air steering (not camera) |

Notes:
- Ties at `201` are all "after the default camera": Lobby, TargetLock, and SkillShake. Only one of Lobby or TargetLock is normally active at a time (lobby is out of match, lock is Taya in match), but SkillShake can overlap lock.
- PounceCamera is deliberately last (`204`) so its additive offset stacks on top of whatever the default camera produced. This is the correct pattern and should be preserved.
- The `Reset` step at `199` exists because the `204` step mutates `camera.CFrame` and `FieldOfView` in place with no saved baseline. It subtracts the previous frame's contribution before the next frame is generated. Any director must not break this add/remove symmetry.

---

## 6. CameraType state machine

Only three Scriptable transitions exist.

| Trigger | Writes | Restore | File |
|---|---|---|---|
| Enter lobby (not in match) | `Scriptable` | On match start, sets `Custom` and `CameraSubject = humanoid` | `LobbyUI.client.lua:2306`, `:2402`, `:2407` |
| Acquire lock (Taya, in match) | `Scriptable` | On break/unbind, sets `Custom` if currently Scriptable | `TargetLockController.lua:425`, `:311` |
| Hold RS_03 aim | `Scriptable` during blend | At blend end, `Custom`, sets `CameraMaxDistance = FirstPersonDistance` | `MovementController.client.lua:2208`, `:2214`, `:2215` |

Hazards:
- Restores are conditional and uncoordinated. `TargetLockController` restores only if the camera is still Scriptable; if the aim cam also holds Scriptable, the first one to finish flips the type under the other.
- `MovementController` caches and restores `CameraType`, `FieldOfView`, `CameraMaxDistance`, `MouseBehavior`, and `MouseDeltaSensitivity` (`:2153` to `:2175`). This is the only script that restores a full saved bundle. It is the only precedent for safe Scriptable ownership. A director should adopt this save/restore contract.
- No script saves or restores `UserInputService.MouseIconEnabled`; none toggles it. Aim and lock rely on `MouseBehavior.LockCenter` set in `MovementController` (`:2283`).

---

## 7. CFrame writers

| Writer | Line | Operation | Baseline-safe? |
|---|---|---|---|
| LobbyUI | `:2316` | `cam.CFrame = base * CFrame.new(shift,0,0)` (absolute) | Yes, owns full control while lobby active |
| TargetLock | `:382` | `cam.CFrame = cam.CFrame:Lerp(desired, alpha)` | Yes, relative lerp from live pose |
| RS_03 aim | `:2209` | `cam.CFrame = fromPose:Lerp(goal, alpha)` (absolute blend) | Yes, saved `fromPose` |
| Skill shake | `:1502` | `cam.CFrame = cam.CFrame * CFrame.Angles(...)` | Additive, no vertical, restored next frame by nature of being per-frame |
| PounceCamera | `:84` | `cam.CFrame *= lastTransform` | Additive with explicit `Reset` at `:97`/`:33` |

Two absolute writers (Lobby, aim) and three relative writers. Relative writers are safe to stack; absolute writers are not compatible with any other absolute writer running the same frame.

---

## 8. FieldOfView writers

Two models are mixed.

| Writer | Model | Line | Restore |
|---|---|---|---|
| LobbyUI | Absolute 42 | `:2307` | Re-sets on entry only |
| PounceCamera | Additive delta, smoothed | `:71`, `:72` | `Reset` step at `:97`, `:33` |
| SprintVFX | Additive delta, eased | `:538` | `removeFov` subtracts `fovApplied` (`:543`) |
| MovementController skill | Absolute tween to `base + fovBoost` | `:1468` | Tween back to cached `skillFOVBase` (`:1477`) |

Hazards:
- `MovementController` caches `skillFOVBase = cam.FieldOfView` at takeoff (`:1460`) and tweens back to it. If a pounce or sprint delta is active during that window, the cached base includes their contribution at capture time, and the tween back can freeze or double a delta.
- `Config` exposes `Config.Movement.SprintFovBoost = 10` and `FovTweenTime = 0.2` (`Config.lua:24`), marked `[SD]` with the note "not live until camera ownership is updated". `Config.SprintVFX.FovDelta` is the value actually used by SprintVFX. The base-movement sprint boost is therefore a reserved, unwired knob a director is expected to consume.
- No writer sets an absolute FOV during matches. A director that sets absolute FOV each frame will fight PounceCamera, SprintVFX, and the skill tween unless it becomes the sole FOV authority and those become inputs.

---

## 9. Saved-state and restore contracts

Only `MovementController` aim saves a full bundle (`AimCamSaved`, `:2093`):

- `cameraType: Enum.CameraType`
- `cameraCFrame: CFrame`
- `fieldOfView: number`
- `maxDistance: number`
- `mouseBehavior: Enum.MouseBehavior`
- `mouseSensitivity: number`

Restore (`tsinelasRestoreCamera`, `:2153`) translates the saved pose by how far the root moved so walking aimers do not snap (`:2163` to `:2166`). This is the model a director should follow: capture the bundle on take-over, restore it on release, offset for player translation.

`PounceCamera` does not save a bundle. It relies on the `Reset` step to subtract its own delta. This works only because its contribution is small and additive.

`LobbyUI` does not save a bundle. It assumes Custom with the default subject is the correct post-lobby state and reconstructs it (`:2402` to `:2407`).

---

## 10. Input and action bindings

All bindings use `ContextActionService`. Camera-relevant and adjacent bindings:

| Action | Key (PC) | Gamepad | Touch | File |
|---|---|---|---|---|
| Pounce | `MouseButton1` | `ButtonR2` | touch pounce | `PounceController.lua:308` (`BindActionAtPriority`) |
| Sprint hold | Left Shift | `ButtonL2` | Sprint button | `MovementController.client.lua:3068`, `:3130` |
| Dash | `Q` | `ButtonB` | Dash button | `MovementController.client.lua:3080`, `:3139` |
| Slide | `C` | `ButtonR1` | Slide button | `MovementController.client.lua:3087`, `:3146` |
| Skill | `E` | `ButtonX` | Skill button | `MovementController.client.lua:3095`, `:3153` |
| Tsinelas (RS_03) | key from `Config.UI.Tsinelas` | `ButtonR1` reserved | `TsinelasTouch` button | `MovementController.client.lua:3106`, `UIController.client.lua:355` |
| Lock target | hold right mouse | `ButtonL1` | Lock button | `TargetLockController.lua:673`, `:697` |
| Diskarte | `F` (`Config.Diskarte.ActivateKey`) | `ButtonX` | Diskarte button | `Config.Diskarte` |

Notes:
- `MouseButton2` (right click) is the lock-target hold, per `md-doc/Habulan_Rush_UI_UX_Specification.md:65`. The camera look itself is the default Roblox mouse/right-stick/touch-drag (`UI_UX Spec:58`), which the default camera owns. No custom look input exists today.
- Pounce uses `BindActionAtPriority` (`PounceController.lua:308`), unlike the others. A director that rebinds mouse buttons must not steal left click from pounce or right click from lock.
- Free keys candidates for a director toggle: R, T, G, V, X-free on keyboard? `Config` uses Q/E/C/F/Shift/Space; lock uses RMB. No keyboard key is claimed for a camera mode toggle today.

---

## 11. Movement states the camera cares about

Published on the LocalPlayer as attributes by `MovementController` at ~10 Hz plus forced on events (`MovementController.client.lua:445` to `:465`):

`HRushStamina`, `HRushStaminaMax`, `HRushDashCD`, `HRushSlideCD`, `HRushDashing`, `HRushSliding`, `HRushRolling`, `HRushVaulting`, `HRushSprinting`, `HRushAbilityBusy`, `HRushVaultCD`, `HRushVaultVariant`, `HRushBoost`, `HRushRole`, `HRushSkillId`, `HRushSkillCD`, `HRushSkillCD_RS03`, `HRushSkillId_RS03`, `HRushAiming`.

Air/landing attributes: `HRushAirborne`, `HRushAirSpeedCap`, `HRushEffectiveFallGravityMult`, `HRushEffectiveAirControlPct` (`AirMovement.lua:340` to `:346`), `HRushHardLandingSpeedMult`, `HRushHardLandingUntil`, `HRushLastFallHeight`, `HRushLastLandingClass` (`LandingController.lua:94` to `:163`).

Pounce attributes: `HRushLocalPouncing`, `HRushLocalPounceState` (`PounceController.lua:72`, `:249`, `:290`), `HRushPounceCD` (`:418`).

The director can read these attributes for camera-state decisions (for example, tighten the shoulder offset while sliding, or raise the camera on hard landing) without adding new remotes.

---

## 12. Pounce lifecycle and camera hooks

`PounceController.lua` drives `PounceCamera` (`PounceCamera.lua:102` to `:109`):

| Call | Line | Effect |
|---|---|---|
| `PounceCamera:Windup()` | `PounceController.lua:251` | Slight raise, small FOV bump |
| `PounceCamera:Launch()` | `:200` | Forward push, larger FOV bump |
| `PounceCamera:Airborne()` | `:371` (after `Camera.LaunchHold`) | Air offset, forward push, near-target push |
| `PounceCamera:NearTarget(bool)` | `:397` | Extra forward push when close to target |
| `PounceCamera:Impact()` | `:355` | Shake, impact FOV, decay |
| `PounceCamera:Land()` | `:210` | Downward dip and pitch |
| `PounceCamera:Recover()` | `:226`, `:403`, `:412` | Smooth back, auto-cancel when settled |
| `PounceCamera:Cancel()` | `:104` | Hard reset (state change, respawn, round gate) |

`PounceCamera` config: `Config.Pounce.Camera` (`Config.lua:398`): `WindupFov=3`, `LaunchFov=8`, `AirFov=6`, `ImpactFov=10`, offsets, `NearPush`, `ImpactPush`, impact shake, `LandDip`, `LandPitch`, `SmoothRate=28`, `LaunchHold=0.08`, `CollisionPadding=0.05`.

Importantly, `PounceCamera.update` already does its own obstruction raycast against the character (`:74` to `:82`) and clamps the offset. A director that owns camera collision must not double-collide with this; the pounce offset should remain a post-collision additive layer.

---

## 13. Tag, role, and round signals

| Signal | Where | Consumer |
|---|---|---|
| `HRushRole` = "Taya" / "Runner" | LocalPlayer attribute; server authority in `MatchService.server.lua` | Lock camera, HUD, speed |
| `HRushState` = MS_01..MS_06 | LocalPlayer attribute | HUD, pounce gate, gating |
| `HRushInMatch` | LocalPlayer attribute | Lobby camera bind/unbind (`LobbyUI.client.lua:2390`), HUD gate |
| `HRushCurrentTayaName` | `ReplicatedStorage` attribute | HUD taya tracker (`UIController.client.lua:1587`) |
| `HRushPhaseEndsAt` | `ReplicatedStorage` attribute | Timers (`UIController.client.lua:1596`), lobby draft countdown |

Round states: MS_01 lobby, MS_02 draft, MS_03 countdown, MS_04 live, MS_05 round end, MS_06 match end (from `UIController` gate logic `:1548` and lobby loading states).

A director must key its enable/disable on `HRushInMatch` and `HRushState`, matching the lobby so the lobby camera is not fought. In MS_01 and out of match, the lobby camera must win.

---

## 14. Attribute bridge summary

Client-owned LocalPlayer attributes (camera inputs available without new remotes): the movement list in section 11, plus `HRushLocalPounceState` and `HRushAiming`.

World/global attributes: `HRushCurrentTayaName`, `HRushPhaseEndsAt`, `HRushSelectedMap`, `HRushRoundState` (debug, disabled in `Bootstrap.server.lua:343`).

Unknown/external reads: `MovementController` reads `HRushSettingsOpened` (a `ReplicatedStorage` BindableEvent) to pause camera effects while the settings panel is open (`MovementController.client.lua:3218` to `:3224`). A director should honor the same pause.

---

## 15. Remotes relevant to camera-adjacent state

From `default.project.json:23` to `:44`:

`RequestPounce`, `PounceEvent`, `RequestSkill`, `RequestDash`, `RequestMovementState`, `PickSkill`, `ActivateDiskarte`, `StateChanged`, `TagEvent`, `SkillEvent`, `SkillApproved`, `SkillVFX`, `SkillLanded`, `DiskarteUpdate`, `ClutchEvent`, `RoundRecap`, `MatchRecap`, `QueueEvent`, `PartyEvent`, `MapVoteEvent`.

No camera remote exists or is needed. Camera is fully client-side. A director must not introduce a new remote for camera (it is local presentation). If a director needs server state, it should read the existing `StateChanged`/`TagEvent`/attribute channels.

---

## 16. Map geometry and vertical space

Only `Kalsada` has geometry, built in code by `Bootstrap.server.lua`. This constrains a shoulder camera.

- Arena 150 x 150 studs (`Config.Maps.Kalsada.size`), boundary walls 14 studs high (`Bootstrap.server.lua:104`). Walls are unjumpable, so the player is always inside the box.
- Central open court 56 x 32 (`buildCourt`, `:140`), no cover.
- 2 sari-sari buildings 10 studs tall and 20 x 12 (`buildBuildings`, `:182`), not vaultable.
- 4 jeepneys, roof top at 4 studs (`:198`), vaultable.
- 4 crates 3.5 studs (`:212`).
- 2 low gaps 3.5 studs clearance (`:225`).
- 8 spawn pads at radius 55 (`:244`).
- Vertical range is small. The tallest player-reachable surface is 4 studs. A shoulder camera pulling up will hit the 14-stud walls quickly near the boundary.

`Binaha` has no geometry (`Config.Maps.Binaha` has no `greybox`). Any director tuning must assume Kalsada and open floor.

---

## 17. Rig and character constraints

- Rig is R15. `MatchService.server.lua` applies `Enum.HumanoidRigType.R15` via `CreateHumanoidModelFromDescription`.
- No `StarterCharacterScripts` is mapped in `default.project.json`. Custom camera code cannot rely on a per-character starter script; it must live in `StarterPlayerScripts` and track `CharacterAdded`.
- `StarterPlayer.CharacterWalkSpeed` and `CharacterJumpPower` are set by `Bootstrap.server.lua:330` to `RunnerWalkSpeed * SpeedScale` and `JumpPower`.
- Camera-relevant rig facts used by existing code: character parts are faded via `LocalTransparencyModifier` during RS_03 aim (`MovementController.client.lua:2134`). A first-person director must coordinate with this single fade path instead of adding a second.

---

## 18. UI, HUD, and mobile touch layout

- HUD root is `HRushHUD` (`UIController.client.lua:100`). The in-match HUD shows only in MS_03/MS_04/MS_05 when `HRushInMatch` (`:1664`).
- Lobby GUI is the same style but shown when not in match (`LobbyUI.client.lua:2392`).
- Mobile: a dedicated circular Tsinelas touch button sits at `Config.UI.Tsinelas.TouchPosition` (0.88, 0.68), size 76 px (`Config.lua:713`, `UIController.client.lua:355`). Sprint/Dash/Slide/Skill touch actions are bound in `MovementController`.
- The default Roblox touch camera (drag anywhere) is not overridden. A shoulder-camera director that adds touch look must reserve a screen region and avoid the Tsinelas button at right, lower-center.
- Cooldown chips use fixed keycap labels ("Q", "E") in `UIController`. A director adding a camera toggle should follow the same keycap convention.

---

## 19. Settings system

`ClientSettings.lua` exposes keys `master`, `music`, `sfx`, `vfx`, `reducedCamera` (`ClientSettings.lua:14`), each with a `Config.Settings` spec. Settings are memory-only (no DataStore). The Settings panel is built in `LobbyUI.client.lua:1423` and bound to keys `HRUSH_Settings` / `HRUSH_SettingsNav` (`:1697`, `:1704`).

Camera-relevant key: `reducedCamera`. It is read by `VfxScale.reducedCamera()` (`VfxScale.lua:55`) which also ORs `Config.SprintVFX.ReducedEffects`. Consumers:

- PounceCamera zeroes all offsets and FOV (`PounceCamera.lua:63`).
- SprintVFX zeroes the FOV widen (`SprintVFX.lua:524`).
- MovementController skill FOV and shake skip (`MovementController.client.lua:1457`, `:1487`).

A shoulder camera must respect `reducedCamera` for any shake or motion-heavy behavior, and any new camera sensitivity setting should be added to `ClientSettings`/`Config.Settings`, not hardcoded.

---

## 20. VFX scale gating

`VfxScale.lua` provides `player()`, `cosmetic()`, `telegraph()`, `reducedCamera()`. Camera effects use `reducedCamera()` only. If a director adds a camera shake or FOV kick, it should read `VfxScale.reducedCamera()` exactly as PounceCamera and SprintVFX do, so the accessibility toggle stays coherent.

---

## 21. Design intent from the design docs

Camera-related intent found in `md-doc/`:

- `Habulan Rush Game Design Document.md:46`: "Camera: Third person, soft target lock for Taya."
- Same doc `:174` (TM_02): soft target lock, range 40, breaks beyond 55, needs line of sight, steers camera toward target, does not auto-move.
- Same doc `:407` (ES_02): spectator camera (follow Taya, free cam, auto-switch) is MVP.
- `Habulan_Rush_UI_UX_Specification.md:58`: Camera = mouse / right drag / right stick. `:65`: lock target = hold right click / lock button / left bumper. `:75`: tag feedback includes a 0.1 s camera punch.
- `Habulan_Rush_System_Specification.md:90`: "Lock never moves the Taya; it only assists camera aim."
- `Habulan_Rush_Technical_Design_Document.md:125`: spectator free camera, follow Taya, auto-switch to highest-activity chase (MVP-lite).

So the intended direction is a soft third-person camera with Taya-only soft aim assist, plus a later spectator camera. A first-person shoulder camera is an addition beyond the current GDD.

---

## 22. Known risks and conflicts

1. Scriptable ownership is uncoordinated. Three writers can force Scriptable and only one restores a full bundle. Adding a fourth without a coordinator risks the camera locking in Scriptable or flipping to Custom mid-aim.
2. Mixed FOV models. Absolute tween (skill) versus additive delta (sprint, pounce) can double-count or freeze when overlapping.
3. `CameraMaxDistance` is mutated by aim (`:2170`, `:2215`) and could be mutated by a director. Only the aim restores it. A director must save and restore it, or it will persist a first-person distance into third-person play.
4. `CameraSubject` is only set in LobbyUI restore (`:2407`). If a director changes the subject (for a shoulder or spectator camera), it must restore it.
5. PounceCamera's `Reset`-then-apply pattern must be preserved. Any new `Camera.Value + n` writer that runs between `199` and `204` could be corrupted by the reset.
6. The lobby camera bind is created per character setup (`setupLobbyCamera` at `:2364`) and unbound on match start. A director enabled during a match must not be active in the lobby, or the two will fight at the same priority (`201`).
7. `MovementController` writes `cam.CFrame` in the aim restores (`:2168`) and the aim blend (`:2209`), and writes `Humanoid.AutoRotate` during dash/slide/vault. A director that also rotates the character or camera must reconcile with these. (The exact dash/slide/vault CFrame blocks were located by grep only and were not fully read in this pass.)
8. No camera collision exists except PounceCamera's local offset clamp. A shoulder camera behind the player will clip into walls and the 14-stud boundary without its own collision.

---

## 23. Non-negotiable constraints for a CameraDirector

- Client-only. No new remote, no server change, no `Config` write at runtime.
- One owner. The director must be the single authority that sets `CameraType` and the base pose, with existing writers demoted to inputs or removed.
- Preserve additive layers. PounceCamera, SprintVFX, and skill shake should remain additive `FieldOfView`/`CFrame` contributions applied after the director, not absolute writers.
- Save and restore the full bundle on take-over: `CameraType`, `CFrame`, `FieldOfView`, `CameraMaxDistance`, `MouseBehavior`, `MouseDeltaSensitivity`, `CameraSubject`. Follow `MovementController`'s `AimCamSaved` contract.
- Respect `HRushInMatch` and `HRushState`: never active in MS_01 or the lobby; defer to the lobby camera whenever it is bound.
- Honor `VfxScale.reducedCamera()` for shake, FOV kick, and any motion-heavy behavior.
- Honor the settings-panel pause (`HRushSettingsOpened`).
- Keep camera values in `Config.lua` (marked `[LOCKED]` or `[SD]`), never hardcoded. Do not change locked values without owner sign-off.
- Do not edit `HabulanRush.rbxlx`; build via Rojo.
- New Luau files must start with `--!strict` and a header (path, owner, responsibility, task/spec).
- Test on PC, gamepad, and mobile (touch look region must avoid the Tsinelas button and the right-thumb cluster).

---

## 24. Open questions and unverified items

- No two-client Studio session was run, so overlap of TargetLock and SkillShake, and aim-cam restore during a pounce, are reasoned from code, not observed.
- Whether the default Roblox classic camera is customized by any unread `PlayerModule` override: not found, assumed default.
- Exact device split and safe-area behavior of the touch layout: not measured.
- Spectator camera (ES_02) has no implementation and no consumer of `CameraSubject` switching.
- `MovementController` line 2168 and 2209 CFrame writes were located by grep; the surrounding dash/slide/vault blocks were not fully read in this read-only pass.
- `Md-doc` does not specify a shoulder offset or first-person mode, so target framing values are undefined and must come from the project owner.

---

## 25. Recommended integration approach (no code)

1. Create `CameraDirector.lua` as a `StarterPlayerScripts` ModuleScript with a thin bootstrap, mirroring the `PounceController`/`PounceController.client.lua` shim pattern.
2. Implement one `BindToRenderStep` at `Camera.Value + 1` (or just after), owning base pose and `CameraType`.
3. Convert existing Scriptable writers into director states: lobby (hands to LobbyUI), lock (director applies aim bias), aim (director applies first-person blend), pounce/sprint/shake (director applies additive after base).
4. Move all camera tunables into a `Config.Camera` table (marked `[SD]` while iterating, `[LOCKED]` once approved).
5. Add director enable/disable on `HRushInMatch`/`HRushState`, and a save/restore bundle exactly like `AimCamSaved`.
6. Keep `PounceCamera` as the after-director additive layer; do not fold it in.
7. Validate with a 2-player Studio session, on PC + gamepad + touch, before any push.

---

## 26. Verification performed

- Static read of every camera-mapped file and `default.project.json`.
- Grep for `CameraType`, `CurrentCamera`, `BindToRenderStep`, `FieldOfView`, `CameraMaxDistance`, `MouseBehavior`, `MouseDeltaSensitivity`, `AutoRotate`, `PounceCamera:`, `SetAttribute("HRush`.
- No gameplay code changed. No `HabulanRush.rbxlx` build run. No Studio session run.
- This report created at `docs/CAMERA_AUDIT.md`.

---

# CAMERA IMPLEMENTATION CONTEXT FOR CHATGPT

Paste-ready summary. Every fact below was verified by reading the mapped repository files on 2026-10-17. Line numbers are the mapped source files.

## Project
- Roblox + Luau, Rojo 7.7.1. Build: `%LOCALAPPDATA%\rojo-bin\rojo.exe build default.project.json -o HabulanRush.rbxlx`. Do not hand-edit `HabulanRush.rbxlx`.
- `default.project.json` is the authority for which files build.
- New or edited Luau files start with `--!strict` and a header (path, owner, responsibility, task/spec).
- All camera code is client-side in `StarterPlayerScripts`. There is no `StarterCharacterScripts`, no existing camera module, and no camera remote.

## The one goal
Add a single third-person shoulder camera director (later first-person) that owns the base camera, without fighting the six existing additive/scriptable camera writers.

## Existing camera writers (what must be preserved or demoted)
1. `LobbyUI.client.lua` (`:2272` setup, `:2299` bind `HabulanLobbyCamera` at `Camera.Value + 1`): forces `Scriptable`, FOV 42, writes `cam.CFrame` each frame. Active only while `HRushInMatch ~= true`. Restores `Custom` + `CameraSubject` at `:2402`/`:2407`. Consts at `:81` to `:85` (`CameraDistance 9.5`, `CameraHeight 1.4`, `CameraYawDegrees 18`, `CameraShiftX 1.5`, `CameraFOV 42`).
2. `TargetLockController.lua` (`:399` bind `ASSIST_BIND` at `Camera.Value + 1`): Taya-only soft lock. Forces `Scriptable` (`:425`), lerps `cam.CFrame` toward a smoothed aim point (`:382`). On break restores `Custom` if still Scriptable (`:311`). Config `Config.TargetLock.CameraAssist` (`Config.lua:443`).
3. `MovementController.client.lua` RS_03 aim (`:2295` `AIMCAM_BIND` at `Camera.Value + 2`): blends to first person and back, forcing `Scriptable` during the blend (`:2208`) then `Custom` (`:2214`). Saves a full bundle in `AimCamSaved` (`:2093`) and restores it (`tsinelasRestoreCamera`, `:2153`). Translates the saved pose by root movement on restore.
4. `MovementController.client.lua` skill FOV (`:1451` `startSkillFOV`, `:1472` `stopSkillFOV`): caches `skillFOVBase = cam.FieldOfView` and tweens to `base + fovBoost` and back. Skill shake binds `HRUSH_SkillShake` at `Camera.Value + 1` (`:1493`), additive horizontal + roll, no vertical.
5. `PounceCamera.lua`: the correct additive pattern. Reset step `HRUSH_PounceCameraReset` at `Camera.Value - 1` (`:97`) subtracts last frame's FOV/CFrame delta; apply step `HRUSH_PounceCamera` at `Camera.Value + 4` (`:98`) adds `fovDelta` (`:71`) and multiplies `cam.CFrame` (`:84`). Has its own obstruction raycast (`:74`). Driven by `PounceController.lua` (`Windup :251`, `Launch :200`, `Airborne :371`, `Impact :355`, `Land :210`, `Recover :226/:403/:412`, `Cancel :104`). Config `Config.Pounce.Camera` (`Config.lua:398`).
6. `SprintVFX.lua` (`updateFov` `:519`): additive FOV delta on `cam.FieldOfView` (`:538`), eased, gated by `VfxScale.reducedCamera()`.

## Render-step order in use
`Camera.Value - 1` = PounceCamera reset. `Camera.Value + 1` = Lobby, TargetLock, SkillShake. `Camera.Value + 2` = RS_03 aim. `Camera.Value + 4` = PounceCamera apply. `Character.Value + 1` = AirMovement.

## CameraType transitions (all Scriptable entries)
Lobby (`:2306`), TargetLock (`:425`), RS_03 aim (`:2208`). Restores are uncoordinated. Only MovementController restores a full saved bundle.

## FOV models in use (mixed, must be unified by the director)
Absolute: Lobby (42), skill tween (to `base + fovBoost`). Additive delta: PounceCamera, SprintVFX. Reserved unwired knob: `Config.Movement.SprintFovBoost = 10`, `FovTweenTime = 0.2` (`Config.lua:24`), noted "not live until camera ownership is updated".

## Client attributes available to the director (no new remotes needed)
Movement/misc (LocalPlayer): `HRushStamina`, `HRushStaminaMax`, `HRushDashCD`, `HRushSlideCD`, `HRushDashing`, `HRushSliding`, `HRushRolling`, `HRushVaulting`, `HRushSprinting`, `HRushAbilityBusy`, `HRushVaultCD`, `HRushVaultVariant`, `HRushBoost`, `HRushRole`, `HRushSkillId`, `HRushSkillCD`, `HRushSkillCD_RS03`, `HRushSkillId_RS03`, `HRushAiming`.
Air/landing: `HRushAirborne`, `HRushAirSpeedCap`, `HRushEffectiveFallGravityMult`, `HRushEffectiveAirControlPct`, `HRushHardLandingSpeedMult`, `HRushHardLandingUntil`, `HRushLastFallHeight`, `HRushLastLandingClass`.
Pounce: `HRushLocalPouncing`, `HRushLocalPounceState`, `HRushPounceCD`.
Global (ReplicatedStorage): `HRushCurrentTayaName`, `HRushPhaseEndsAt`.
Gate (LocalPlayer): `HRushInMatch`, `HRushState` (MS_01 lobby, MS_02 draft, MS_03 countdown, MS_04 live, MS_05 round end, MS_06 match end).
Settings-panel pause signal: `ReplicatedStorage.HRushSettingsOpened` (BindableEvent), currently read by `MovementController.client.lua:3218`.

## Settings and accessibility
`ClientSettings.lua` keys: `master`, `music`, `sfx`, `vfx`, `reducedCamera`. `VfxScale.reducedCamera()` (`VfxScale.lua:55`) ORs `Config.SprintVFX.ReducedEffects`. PounceCamera, SprintVFX, and skill camera effects all skip when reduced. A director must do the same, and any new camera sensitivity should be a `ClientSettings` key, not hardcoded. Settings are memory-only (no DataStore).

## Input bindings (do not steal)
Pounce = LMB / R2 (uses `BindActionAtPriority`, `PounceController.lua:308`). Lock = hold RMB / L1 (`TargetLockController.lua:673`). Sprint = Shift / L2. Dash = Q / B. Slide = C / R1. Skill = E / X. Diskarte = F / Y. Camera look is default Roblox (mouse / right stick / touch drag); no custom look input exists. Mobile Tsinelas touch button sits at (0.88, 0.68) 76 px (`Config.lua:713`); keep the touch look region clear of it and the right-thumb cluster.

## World and rig constraints
R15 rig, no `StarterCharacterScripts`. Only `Kalsada` has geometry (`Bootstrap.server.lua`): 150 x 150 street, 14-stud unjumpable boundary walls, open central court, 2 buildings 10 studs, 4 jeepneys 4 studs, 4 crates 3.5 studs, 2 low gaps 3.5 studs, 8 spawns at radius 55. Highest reachable surface is 4 studs, so a shoulder camera pulling up near the boundary will hit walls. `Binaha` has no geometry. Vertical range is narrow.

## Hard rules for the director
Client-only, no new remote, no runtime `Config` write. Be the single owner of `CameraType` and base pose. Keep PounceCamera/SprintVFX/skill shake as additive layers after the base. Save and restore the full bundle on take-over (`CameraType`, `CFrame`, `FieldOfView`, `CameraMaxDistance`, `MouseBehavior`, `MouseDeltaSensitivity`, `CameraSubject`). Never active in MS_01 or the lobby; defer to the lobby camera. Honor `VfxScale.reducedCamera()` and the settings-panel pause. All tunables in `Config.lua` marked `[SD]`/`[LOCKED]`; locked changes need owner sign-off. Follow the `PounceController` shim-plus-module pattern. Test PC + gamepad + mobile with 2 players before pushing.

## Known gaps to design around
No camera collision except PounceCamera's offset clamp. `CameraSubject` only handled in lobby restore. `CameraMaxDistance` only restored by aim. Mixed absolute/additive FOV can double-count. `docs/UPGRADE_REPORT.md` (2026-10-15) lists overlapping camera risks; this audit is the current camera-specific truth.

---

## Phase 1 implementation record (2026-10-18)

Implemented in the repository on 2026-10-18 by opencode. Studio validation is pending project-owner review.

### What was built
- `src/StarterPlayerScripts/CameraDirector.lua` (ModuleScript) and `CameraDirector.client.lua` (thin starter). Client-only. No remote, no server code, no runtime `Config` write.
- Fixed-distance third-person shoulder base camera bound at `Enum.RenderPriority.Camera.Value` while `HRushInMatch == true`.
- Look input: mouse through per-frame `UserInputService:GetMouseDelta()` times a `ClientSettings` sensitivity factor; gamepad right stick with deadzone and per-second rate; touch drag confined to the right screen half and rejected when the touch starts on a CAS touch button or any `GuiButton`.
- Collision: one reused `RaycastParams` with the character excluded, one ray from the focus point, snap in and exponential ease out at `CollisionReturnRate`.
- Shoulder swap on V and ButtonL3 through CAS `HRUSH_CameraShoulder`.
- Cursor lock and icon hiding with self-heal after Alt+Tab. Never fights a focused text box or the platform menu.
- Settings pause from per-frame `LobbyUI.Enabled and SettingsPanel.Visible`. The `HRushSettingsOpened` event is deliberately not subscribed because the X button (`LobbyUI.client.lua:2208`) and the match gate close the panel without firing it.
- Lobby settings panel grew from 520x640 to 520x812 with two new rows and generic toggle-row helpers.

### Handoff and yield rules
- Yields to the RS_03 aim camera (`HRushAiming == "RS_03"`) and the TargetLock assist (`TargetLockController:GetTarget() ~= nil`).
- While yielded it adopts the live `CFrame` each frame. On re-entry it starts from that pose and blends to the orbit over `TakeoverTime`.
- Does not yield during pounce. PounceCamera stays an additive layer above the base.
- Release restores CameraType, FOV, MouseBehavior, and MouseIconEnabled. The pose is not restored by design; the next base owner writes its own pose on the following frame.
- Look input and the cursor lock are live only in MS_03 and MS_04. The MS_02 draft and the MS_05/MS_06 recaps need a free cursor; the camera holds its pose there but stops taking input.
- Respawn snaps to the new body instead of sweeping across the map.
- The saved bundle is limited to the properties the director actually mutates. CFrame, CameraMaxDistance, MouseDeltaSensitivity, and CameraSubject are never written, so they are not saved. The aim camera keeps its own `AimCamSaved` bundle.

### New values (all [SD])
- `Config.Camera`: Enabled true, ThirdPersonDistance 10, ShoulderOffset 1.5, CameraHeight 1.5, PitchMin -80, PitchMax 80, BaseFov 70, MouseDegPerPixel 0.12, GamepadLookDegPerSec 260, GamepadDeadzone 0.12, TouchLookDegPerPixel 0.25, TouchMinScreenXScale 0.5, CollisionPadding 0.4, CollisionReturnRate 6, TakeoverTime 0.2, ShoulderSwapTime 0.15, ShoulderSwapKey V, ShoulderSwapGamepad ButtonL3, SensitivityScaleMax 2.0, SensitivityScaleMin 0.25, Debug false.
- `Config.Settings`: CameraSensitivityDefault 50, InvertCameraYDefault false.
- `ClientSettings.lua`: `cameraSensitivity` (0 to 100 slider) and `invertCameraY` (toggle). Settings stay memory-only.

### Decisions taken during implementation
- Mouse look multiplies `GetMouseDelta()` by our own factor. `MouseDeltaSensitivity` is not touched, so scaling cannot double-count.
- No FOV is written per frame. `BaseFov` is enforced only at acquire, so the additive PounceCamera and SprintVFX delta model stays intact. `Config.Movement.SprintFovBoost` remains reserved and unwired.
- The base stays at `Camera.Value`, between the PounceCamera reset at `Camera.Value - 1` and every additive or scriptable writer at `Camera.Value + 1` and later.
- Acquisition is deferred one frame after `HRushInMatch` and after respawn so the lobby gate finishes its own `Custom` restore first.
- V and ButtonL3 were verified unused before binding.

### Preserved behavior
- PounceCamera, SprintVFX FOV, skill shake, RS_03 aim, TargetLock assist, and the lobby camera are unchanged.
- Existing settings rows (`master`, `music`, `sfx`, `vfx`, `reducedCamera`) keep identical behavior.

### Known limitation (pre-existing, not changed)
- In match, the HUD gear fires `HRushSettingsToggle`, but the LobbyUI settings panel cannot render while its gui is disabled in match. The settings pause is therefore observable only out of match. Phase 1 documents this instead of changing the in-match settings flow.

### Validation state
- `scripts/check-syntax.ps1` passed on 2026-10-18.
- Rojo build passed on 2026-10-18 and regenerated `HabulanRush.rbxlx`.
- No Studio or 2-player acceptance test has been run. The Phase 1 checklist lives in `dev-notes/current-task.md`.

### Not in Phase 1
- Chase awareness, first person, look-back, chaser indicators, and tag-target UI remain future phases.

---

## Phase 2 implementation record (2026-10-18)

Implemented in the repository on 2026-10-18 by opencode, requested by the project owner as the movement camera effect phase. Studio validation is pending project-owner review.

### What was built
- Centralized movement camera effect engine inside `CameraDirector.lua` with four channels: FOV, position offset, rotation, and landing shake. Caps: `MaxFovBoostTotal` 12 degrees, `MaxPositionOffset` 1.5 studs, `MaxRotationDegrees` 6.
- Effects: sprint (role FOV 7 Runner / 5 Taya plus pull-back), falling (FOV 3 plus pull-back scaled by vertical speed 12 to 45 studs/s), landing (Soft and Hard dips, Hard pitch, Hard shake), dash (FOV 5 plus pull-in), slide (dip 0.6, FOV 4, pitch 3.5), vault (plant pull-in and pitch, clear FOV, AirVault scale), roll (dip 0.18, FOV 2).
- One reused state table with dt-based exponential attack and release envelopes; no per-frame table allocation; one render update.
- `resetEffects()` on acquire and release, so re-entry never carries a stale kick.
- Intensity setting `cameraEffectsIntensity` in `ClientSettings` (0 to 100, default 100), scaled by device factor (Touch 0.75, Gamepad 0.9, Default 1.0) and by `VfxScale.reducedCamera()` (half FOV, zero spatial, smoothed over `ScaleSmoothTime` 0.4).
- Position offsets bake into the collision-checked `desired` pose; rotation and shake apply after the base `CFrame.lookAt`. Pitch only; yaw and roll are unused.

### FOV ownership change
- The director now writes absolute `FieldOfView` per frame at `Camera.Value` (`BaseFov + effective effect FOV`), rate limited at `FovCatchupRate` 40 degrees/s so post-yield and post-skill resumes ease instead of snapping.
- PounceCamera reset at `Camera.Value - 1` removes its delta before the director write; pounce re-adds at `Camera.Value + 4`. The add/remove symmetry is preserved.
- Skill FOV suppression: new `HRushSkillFov` LocalPlayer attribute mirrored by `MovementController`; the director skips its FOV write while true, then catches up at the rate limit.
- SprintVFX camera FOV removed (`fovApplied`, `updateFov`, `removeFov`). `Config.SprintVFX.FovDelta`, `FovInTime`, and `FovOutTime` removed. PounceCamera, skill shake, RS_03 aim, TargetLock, and the lobby camera are unchanged.

### Movement integration
- Effects read the LocalPlayer attributes pushed by `MovementController`: `HRushSprinting`, `HRushDashing`, `HRushSliding`, `HRushRolling`, `HRushVaulting`, `HRushVaultVariant`, `HRushAbilityBusy`, `HRushRole`, `HRushStunned`, `HRushLocalPouncing`.
- Effects suppress while `HRushAbilityBusy`, `HRushLocalPouncing`, or `HRushStunned` is true. The landing impulse is gated only on the director being bound.
- Landing reads the `HRushLandingEvent` BindableEvent from the existing `LandingController` publisher (`fallHeight`, `horizontalSpeed`, `class` Soft or Hard). Hard landings add pitch and shake; Soft landings dip only.
- Sprint FOV uses real horizontal speed: full sprint speed is the role base speed times `SpeedScale`; the effect starts at `Config.Movement.SprintVfxMinSpeedPct` (0.9) of that, so the previously unused key is now consumed.
- Vault uses rising-edge detection with time-based plant and clear bumps; roll, slide, and dash are envelope based. Falling requires being airborne and not in a vault, and ignores the Studio-only `HRushAirborne` flag used elsewhere.

### Direct camera writers remaining after Phase 2
- `LobbyUI.client.lua`: lobby camera, out of match only.
- `TargetLockController.lua`: lock assist at `Camera.Value + 1`, Taya only.
- `MovementController.client.lua`: RS_03 aim at `Camera.Value + 2`, skill FOV tween (suppressed from the director through `HRushSkillFov`), skill shake at `Camera.Value + 1`.
- `PounceCamera.lua`: additive reset at `Camera.Value - 1` and apply at `Camera.Value + 4`.
- `CameraDirector.lua`: base pose and absolute FOV at `Camera.Value`, including the four movement effect channels.

### New values (all [SD])
- `Config.Camera.Effects`: MaxFovBoostTotal 12, MaxPositionOffset 1.5, MaxRotationDegrees 6, FovCatchupRate 40, ScaleSmoothTime 0.4; Sprint (RunnerFov 7, TayaFov 5, PullBack 0.6, AttackTime 0.25, ReleaseTime 0.3); Fall (Fov 3, PullBack 0.3, SpeedMin 12, SpeedMax 45, AttackTime 0.2, ReleaseTime 0.35); Landing (SoftDip 0.12, HardDip 0.38, HardPitch 1.5, ShakeAmp 0.06, ShakeTime 0.11, AttackTime 0.05, RecoveryTime 0.18); Dash (Fov 5, PullIn 0.7, AttackTime 0.08, ReleaseTime 0.25); Slide (Dip 0.6, Fov 4, Pitch 3.5, AttackTime 0.12, ReleaseTime 0.15); Vault (PlantPullIn 0.45, PlantPitch 2.5, ClearFov 3, AirScale 0.6, PlantEnd 0.6, ClearStart 0.3); Roll (Dip 0.18, Fov 2, AttackTime 0.08, ReleaseTime 0.15); Device (Touch 0.75, Gamepad 0.9, Default 1.0).
- `Config.Settings.CameraEffectsDefault` 100.
- `ClientSettings.lua`: `cameraEffectsIntensity` (0 to 100 slider). Settings stay memory-only.

### Fixes and cleanup
- Fixed a latent Phase 1 bug: `CameraDirector.refreshSensitivity` initialized its percent from `Cfg.SensitivityDefault`, which does not exist. It now reads `Config.Settings.CameraSensitivityDefault`.
- `Config.SprintVFX.ReducedEffects` is kept; its comment now notes camera FOV is owned by `Config.Camera.Effects`.
- `Config.Movement.SprintFovBoost` and `FovTweenTime` remain reserved and unwired, their comments updated to match.

### Decisions taken during implementation
- `cameraEffectsIntensity` has no settings-panel row yet. An eighth row would grow the 520x812 panel again; the key ships in `ClientSettings` only and the UI row is deferred.
- The director writes absolute FOV because it must own the baseline; the rate limit keeps pounce, skill, and respawn transitions eased instead of snapping.
- Effects suppress each other through `HRushAbilityBusy` and the related gates; the landing impulse stacks by design.
- Pitch only. Yaw and roll channels are not used in Phase 2.

### Known limitations
- No Studio test has been run for Phase 2. Movement combinations, accessibility, and device behavior are code-verified only.
- The in-match settings panel limitation from Phase 1 is unchanged.
- RS_03 skill FOV remains an absolute tween owned by `MovementController`; the director suppresses its own FOV writes while it runs instead of migrating it.

### Not in Phase 2
- First person, look-back, chase intensity, chaser indicators, tag-target UI, final-seconds effects, spectator camera, and any TargetLock or RS_03 redesign remain future phases.

---

## Phase 3 implementation record (2026-10-18)

Implemented in the repository on 2026-10-18 by opencode, requested by the project owner as the chase awareness phase. Studio validation is pending project-owner review.

### What was built
- Role camera profiles: Runner 72 FOV / 10.25 studs, Taya 68 FOV / 9.25 studs, eased over `RoleProfiles.BlendTime` 0.3 s. Unknown roles fall back to `BaseFov` and `ThirdPersonDistance`.
- Runner hold-to-look-back: a 160 degree orbit yaw swing held on B (PC) or ButtonL1 (gamepad), eased in and out over 0.15 s, enabled from `ClientSettings` and `Config`.
- Movement-stability assist: while the swing is active, `Humanoid.MoveDirection` is re-issued rotated by the previous frame's applied yaw offset so camera-relative steering stays world-consistent. The assist must use the previous frame's value because the default PlayerModule ControlModule reads the camera that was written at the end of the previous frame. No movement value, speed, or AutoRotate is changed, and `AirMovement` clears `MoveDirection` after this camera step so committed jumps are preserved.
- Chase proximity FOV: distance dominant (zero at 20 studs, full at 2), closing-speed bonus (0.12 per stud/s, capped 0.35), visibility modifier 0.8 while the Taya is on screen, asymmetric smoothing (rise 0.35 s, fall 0.6 s), 3 degrees at full intensity.
- `ChaseState.lua`: resolves the active Taya from players and `Workspace.Bots`, tracks distance, closing speed, on-screen visibility, `near` (14 studs), and the shared smoothed chase intensity. It advances once per frame from the director's `stepEffects`, including while the camera is yielded, so re-entry never reads stale numbers.
- `ChaseHUD.lua` plus `ChaseHUD.client.lua`: `HRushChaseHUD` ScreenGui (DisplayOrder 9, IgnoreGuiInset, ResetOnSpawn false) bound at `Camera.Value + 5` while `HRushInMatch` and `Config.Camera.Enabled`.
- Runner edge chevron: clamped 56 px inside the screen edges, rotated at the Taya bearing, mirrored when the Taya is behind the camera, hidden once the Taya is inside the 0.06 viewport margin and while the RS_03 aim camera is active.
- Taya advisory tag marker: the nearest eligible Runner or bot within 18 studs with line of sight, rescanned every 0.15 s. A white diamond marks a candidate; an amber pulsing diamond marks a target inside `Config.Pounce.MaxHitDistance`. Hidden when TargetLock holds that target, off screen, tag-immune (`HRushTagSafeUntil`), untouchable (`TagRules.isUntouchable`), while pouncing, or while stunned. The marker is advisory; the server still decides every tag.
- Tag-transfer feedback: one FOV pop and shake impulse on a local role change during MS_04 (ToTaya -1.5 FOV, ToRunner +2 FOV, 0.07 stud shake, 0.06 s attack, 0.35 s release, 0.5 s debounce), plus an amber edge pulse in the HUD.
- Mobile hold-to-look-back button: a 56 px LOOK button, touch only, shown for the Runner in an action phase with both enables on; it feeds `CameraDirector.setLookBackTouch`.

### FOV composition
- `boost = clamp(effFov + extraFov, -MaxFovBoostTotal, MaxFovBoostTotal)`, where `extraFov` is the chase and transfer contributions and `effFov` stays the Phase 2 movement sum.
- `targetFov = profileFovSmooth + boost`, written absolutely at `Camera.Value` with the 40 degree/s catch-up limit. `HRushSkillFov` suppression and the PounceCamera reset symmetry are unchanged.
- `profileFovSmooth` and `profileDistSmooth` replace `Cfg.ThirdPersonDistance` in the desired pose, the adopt pose, acquire, and the respawn snap.

### Input routing
- New `HRUSH_CameraLookBack` action at Default priority on B and ButtonL1; both were verified unused in the source. The action sinks except for a focused-textbox pass on Begin.
- The per-frame gate decides engagement: not Taya, not aim or lock yielded, not settings or platform menu, not `HRushAbilityBusy`, `HRushLocalPouncing`, or `HRushStunned`, and not dash, vault, or roll. Standing, running, sliding, and airborne are allowed. A hold during a blocked state simply waits.

### Direct camera writers remaining after Phase 3
- `LobbyUI.client.lua`: lobby camera, out of match only.
- `TargetLockController.lua`: lock assist at `Camera.Value + 1`, Taya only.
- `MovementController.client.lua`: RS_03 aim at `Camera.Value + 2`, skill FOV tween (suppressed through `HRushSkillFov`), skill shake at `Camera.Value + 1`.
- `PounceCamera.lua`: additive reset at `Camera.Value - 1` and apply at `Camera.Value + 4`.
- `CameraDirector.lua`: base pose, absolute profile and boost FOV, look-back yaw, and the Phase 2 effect channels at `Camera.Value`.
- `ChaseHUD.lua` reads the camera and writes no camera or FOV properties.

### New values (all [SD])
- `Config.Camera.RoleProfiles`: BlendTime 0.3; Runner Fov 72 / Distance 10.25; Taya Fov 68 / Distance 9.25.
- `Config.Camera.LookBack`: Enabled true, Angle 160, BlendTime 0.15, Key B, GamepadKey ButtonL1.
- `Config.Camera.Chase`: MaxDistance 20, MinDistance 2, MaxFov 3, RiseTime 0.35, FallTime 0.6, ClosingGain 0.12, ClosingMax 0.35, VisibleModifier 0.8, ClosingSmoothTime 0.25.
- `Config.Camera.ChaserIndicator`: Enabled true, MaxDistance 14, VisibleMargin 0.06, EdgePadding 56.
- `Config.Camera.TagMarker`: Enabled true, MaxDistance 18, ScanInterval 0.15.
- `Config.Camera.TagTransfer`: ToTayaFov -1.5, ToRunnerFov 2, ShakeAmp 0.07, AttackTime 0.06, ReleaseTime 0.35.
- `Config.Settings.LookBackDefault` true and `ChaserIndicatorDefault` true.
- `ClientSettings.lua`: `lookBackEnabled` and `chaserIndicatorEnabled` toggles. Settings stay memory-only. No settings-panel rows.

### Performance
- `ChaseState` does one player and one bot scan per frame, one world projection, and no per-frame table allocation beyond the loop reads.
- `ChaseHUD` does one projection per visible element and a throttled 0.15 s candidate scan with one raycast per candidate. The transfer pulse and marker pulse are procedural; no tween objects exist to leak.
- No new remotes, no per-frame Instance churn, and no new render bindings beyond the one HUD render step.

### Decisions taken during implementation
- The tag marker is advisory because the client has no exposed server-valid tag target. Distance, immunity, and untouchable checks mirror `PounceController` candidate rules, but the server still validates every tag.
- The marker hides when TargetLock holds the nearest candidate; the lock reticle owns that target.
- Role profile distance and FOV blend through the same eased channels instead of snapping on transfer; the existing FOV catch-up limit covers acquire and post-yield resume.
- The look-back movement assist is a movement-stability measure, not a movement change: it only re-issues the existing `MoveDirection`, and only while a swing is applied.
- `lookBackEnabled` and `chaserIndicatorEnabled` ship in `ClientSettings` with no panel rows, matching the `cameraEffectsIntensity` decision.

### Known limitations
- No Studio test has been run for Phase 3. Look-back feel, the assist rotation sign, marker alignment near the screen edges and the topbar inset, and chase intensity feel are code-verified only and are on the Studio checklist.
- The in-match settings panel limitation from Phase 1 is unchanged, so the two new settings keys stay at their defaults during a match.
- The movement assist was reasoned against the ControlModule camera read order and `AirMovement`'s clear-after-camera step; the sign needs the Studio pass before acceptance.

### Validation state
- `scripts/check-syntax.ps1` passed on 2026-10-18.
- `scripts/check-notes.ps1` passed on 2026-10-18.
- Rojo build passed on 2026-10-18 and regenerated `HabulanRush.rbxlx`.
- No Studio or 2-player acceptance test has been run. The Phase 3 checklist lives in `dev-notes/current-task.md`.

### Not in Phase 3
- First person, final-seconds effects, spectator camera, any TargetLock or RS_03 redesign, and chase audio remain future items. No original chase sound exists in the project, so no hook was added; a named hook would be the first step if the owner requests it.

---

## Phase 4 implementation record (2026-10-18)

Implemented in the repository on 2026-10-18 by opencode, requested by the project owner as the first-person phase. Studio validation is pending project-owner review.

### What was built
- First person as a second view mode of the existing `CameraDirector` (explicit `ThirdPerson` / `FirstPerson` modes). Third person is the default; first person is opt-in through the new `cameraViewMode` `ClientSettings` key. No second camera module, no competing render writer, and no new remote.
- Eye-anchored pose inside the capsule: anchor at HumanoidRootPart position plus `CameraHeight` 1.6, forward offset 0.12 studs toward the look direction, camera pitch clamped to `PitchMin` / `PitchMax`. No collision ray in first person (the capsule keeps the eye out of walls; documented decision).
- Deferred, blended mode switching: toggle requests wait until the frame is free, then blend the written pose from the last written frame to the new mode pose over `SwitchTime` 0.2 s with a smoothstep. Latest request wins while a switch is pending.
- Inputs: PC `Z`, gamepad `DPadUp`, and a 48 px mobile view button in `ChaseHUD` at scale (0.94, 0.40) that shows 3P or 1P. All three routes call the same `CameraDirector.toggleViewMode()` and write through `ClientSettings`, so the `Changed` handler stays the single path that arms a switch. Z was verified unused; DPadUp only drives the LobbyUI settings navigation, which passes while the panel is closed.
- `CameraDirector.getViewMode()` is public and consumed by the HUD label poll and the `PounceCamera` scaling.

### Deferred switching gates
- A pending request resolves only when: the director is bound and not yielded, the settings panel is closed, the phase is MS_03 or MS_04, the platform menu is closed, the RS_03 aim and TargetLock are inactive, and none of `HRushSliding`, `HRushVaulting`, `HRushRolling`, `HRushLocalPouncing`, `HRushStunned`, `HRushAbilityBusy` is true. Dash is deliberately not deferred; the body facing yields to it while the camera keeps first person.
- On a switch the director zeroes `takeoverLeft`, blends from `lastWrittenFrame`, and forces a head-visibility refresh.
- The toggle action itself returns `Pass` whenever the director is not the live input owner (not bound, not an action phase, settings open, or disabled), so the settings panel and lobby keys keep working.

### First-person pose and view effects
- Position: anchor plus `fpRot.LookVector * ForwardOffset` plus the effect Y dip. The shake channel applies after the pose as a small local translation.
- Pitch: camera pitch plus a first-person effect pitch sum (jump start, slide, vault plant, hard landing), clamped to the shared pitch range.
- Effects are a lighter, capsule-safe set (`Config.Camera.FirstPerson.Effects`): sprint FOV 4, fall FOV 3, dash FOV 5, slide FOV 4 / dip 0.85 / pitch 3, vault FOV 3 / dip 0.4 / pitch 5, roll dip 0.12, jump pitch 1 easing out over 0.25 s from a grounded-to-air velocity edge, soft landing dip 0.22, hard landing dip 0.55 / pitch 0.8 / shake 0.05. No pull-backs, no roll channel.
- FOV: first person uses the flat `BaseFov` 72 instead of the role profiles, plus the clamped first-person effect sum and the chase and transfer extras, written absolutely at `Camera.Value` with the same 40 degree/s catch-up. `HRushSkillFov` suppression and the PounceCamera reset symmetry are unchanged.
- Reduced camera halves the first-person FOV effects and zeroes the dips and shake, matching the third-person rule.

### Body rotation
- While first person owns the turn, `Humanoid.AutoRotate` is saved once and disabled, and the root yaw is eased toward the camera yaw with a shortest-arc approach over `YawAlignTime` 0.12 s. The body facing yields while dash, slide, vault, roll, or any ability-busy state owns the character, while yielded to another camera, while paused, and while the platform menu is open. Every exit path restores `AutoRotate`, and the pounce, vault, and bot owners are untouched.

### Head visibility
- `rebuildHeadParts` collects the Head part and every BasePart under the character's direct `Accessory` children; `headVisuals` collects Decal and Texture descendants of the Head. Hiding writes `LocalTransparencyModifier` 1, never the authored `Transparency`, and only those parts.
- The set rebuilds on character change and on accessory or appearance `DescendantAdded` / `DescendantRemoving` (a separate rebuild flag), and re-applies after a yield resume or a mode change.
- Derivation: entering first person hides the head at 60 percent of the blend, leaving first person shows it at 50 percent. While yielded it stays hidden only for the RS_03 aim (a head-based camera) and is shown for the TargetLock camera (a third-person style view). Release and character loss restore everything.

### Pounce integration
- `PounceCamera` composes on top of both modes. In first person the FOV layer scales by `FirstPersonFovScale` 0.6 and the positional and angular layers by `FirstPersonOffsetScale` 0.35, so the base pose stays inside the capsule. The module reads the mode through a lazy `CameraDirector` require with no load-order dependency. The reset at `Camera.Value - 1` and apply at `Camera.Value + 4` symmetry is unchanged.

### TargetLock and RS_03 integration
- Both remain yield owners exactly like Phases 1 to 3. While yielded, presence still runs: AutoRotate is handed back and the head visibility follows the mode and the aim state.
- On a first-person resume the director arms the same 0.2 s pose blend from the live takeover pose, so returning from the aim or the lock camera eases instead of cutting. Third person keeps its existing orbit takeover untouched.
- The RS_03 aim fade stays owned by `MovementController`; first person adds no second fade path. There is no third-person flash on aim entry or exit in first person because both head-based poses sit at the same anchor.

### Collision
- First person deliberately has no collision ray: the eye offset is small and rides inside the character capsule, so walls cannot clip it. The mode-switch blend is a straight smoothstep between two collision-safe poses and adds no ray either. Both choices are documented deviations from the original plan, which allowed an optional blend ray.

### New values (all [SD])
- `Config.Camera.FirstPerson`: Enabled true, CameraHeight 1.6, ForwardOffset 0.12, BaseFov 72, SwitchTime 0.2, YawAlignTime 0.12, ToggleKey Z, ToggleGamepad DPadUp, Effects (SprintFov 4, FallFov 3, DashFov 5, SlideFov 4, SlideDip 0.85, SlidePitch 3, VaultFov 3, VaultDip 0.4, VaultPitch 5, RollDip 0.12, JumpPitch 1, JumpPitchTime 0.25, LandSoftDip 0.22, LandHardDip 0.55, LandHardPitch 0.8, LandShakeAmp 0.05).
- `Config.Pounce.Camera.FirstPersonFovScale` 0.6 and `FirstPersonOffsetScale` 0.35.
- `Config.Settings.CameraViewModeDefault` `"ThirdPerson"`.
- `ClientSettings.lua`: `cameraViewMode` string setting (`ThirdPerson` / `FirstPerson`). The store gains a string spec kind. Settings stay memory-only. No settings-panel row.

### Performance
- No new render steps, no new remotes, and no per-frame instance churn. The first-person path adds one angle approach, one pose compose, and the existing per-frame visibility derive. Head parts rebuild only on character or content change. The debug second line is gated by `Config.Camera.Debug` and off by default.

### Decisions taken during implementation
- First person is a mode of the single director, not a second camera owner: it writes at the same `Camera.Value` bind, so the writer order and the PounceCamera symmetry are untouched.
- No collision ray in first person and no extra ray during the blend (both documented above).
- The head set is collected from direct `Accessory` children rather than welds, because every R15 accessory is a direct child and welds vary by accessory type.
- `cameraViewMode` has no settings-panel row yet, matching the earlier `cameraEffectsIntensity`, `lookBackEnabled`, and `chaserIndicatorEnabled` decisions.
- The view toggle waits for a free frame instead of interrupting aim, lock, slide, vault, roll, pounce, or stun, so no camera or animation transitions are cut.

### Known limitations
- No Studio test has been run for Phase 4. Feel, the blend duration, the body yaw ease, head-visibility timing, the mobile button, and aim and lock resume are code-verified only and are on the Studio checklist.
- In first person the body keeps the camera heading while sprinting (strafe look), which is intentional but unverified on mobile.
- The head-visibility set covers Head decals and textures plus accessory parts. Any future custom head content parented outside those containers would not be hidden until the set is extended.
- The in-match settings panel limitation from Phase 1 is unchanged.

### Validation state
- `scripts/check-syntax.ps1` passed on 2026-10-18 after all Phase 4 edits.
- `scripts/check-notes.ps1` passed on 2026-10-18.
- Rojo build passed on 2026-10-18 and regenerated `HabulanRush.rbxlx`.
- No Studio or 2-player acceptance test has been run. The Phase 4 checklist lives in `dev-notes/current-task.md`.

### Not in Phase 4
- Spectator camera, final-seconds effects, death cinematics, round-end camera, cinematic sequences, and general polish remain future phases and wait for owner approval. No TargetLock or RS_03 redesign was performed.

---

## First-person exit AutoRotate fix (2026-10-18)

Found by project-owner testing right after the Phase 4 report: after entering first person and switching back to third person, the character moved in the camera-relative direction but never turned its body toward movement.

### Root cause
- `PounceController` (start capture at `:239`, restore at `:93`) and the Vault mechanic (capture at `MovementController.client.lua:1289`, restore at `:1218`) each save `Humanoid.AutoRotate` at start and write it back at exit. During a first-person session the saved value was the director's forced `false`.
- `stepFacing` used to restore and clear `autoRotateSaved` on any frame where first person was not the manual owner, including frames owned by a scripted mechanic. That restore fired one frame into a pounce or vault, spending the director's saved `true` mid-mechanic; the mechanic's own exit then wrote back the captured `false`.
- Still in first person, the director re-captured that `false`, and the third-person exit restored it. With `AutoRotate` false the body stops turning toward movement and the avatar slides while facing its last heading.
- Movement itself was never affected: the default PlayerModule `ControlModule` binds at `Input` priority and applies a camera-relative vector through `Player:Move` with no `AutoRotate` dependency (verified against the Studio-shipped PlayerModule source, version `4f087c32742644ab`, `ControlModule.lua:123` and `:508`).

### Fix
- `stepFacing` is now three-way. First person without a mechanic: capture once, hold `AutoRotate` false, ease the root yaw (unchanged). First person with a scripted mechanic (dash, slide, vault, roll, pounce, skill, stun): hands off completely, writes nothing, and keeps the saved value, so the mechanic's own capture and restore govern. Every camera-side exit (mode switch, yield, menu, pause, death): restore the saved value once.
- No changes to `PounceController`, the Vault mechanic, movement, remotes, or any other module. The fix also removes the old mid-mechanic restore that briefly fought pounce and vault while they ran in first person.

### Validation state
- `scripts/check-syntax.ps1` passed on 2026-10-18 after the fix.
- `scripts/check-notes.ps1` passed on 2026-10-18.
- Rojo build passed on 2026-10-18 and regenerated `HabulanRush.rbxlx`.
- Studio repro pending: enter first person, pounce or vault once, return to third person, and confirm the body turns toward movement again and `Humanoid.AutoRotate` reads true.

---

## First-person FOV setting and match access (2026-10-22)

The owner-approved `firstPersonFov` slider supersedes the earlier fixed first-person base FOV and in-match settings-panel limitation described above. It keeps the existing 72-degree default, offers 50 to 120 degrees in 1-degree steps, and remains local to the current session. `CameraDirector` uses it only in first person, preserves the movement and momentum additions and FOV catch-up, and caps the final first-person target at the camera's 120-degree limit.

`LobbyUI` now keeps its settings panel available above the match HUD while hiding lobby controls and other panels during matches. The H key, ButtonSelect, and HUD gear can open it; Reset to Defaults restores 72 degrees. Syntax and Rojo build passed. Live UI, camera, mobile, gamepad, and two-player validation remain with the project owner.

Owner revision on 2026-10-22: the slider maximum and final first-person FOV cap are now 95 degrees. The earlier 120-degree limit in this section is superseded; the 50-degree minimum and 72-degree default are unchanged.
