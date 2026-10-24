---
title: First-person match and TAG animation handoff
type: playtest
status: pending-owner-validation
owner: project-owner
task: first-person-match-tag-animation
updated: 2026-10-24
source: owner-approved first-person match and TAG animation plan
---

# First-person match and TAG animation handoff

## Source changes

- `TagController` now waits for the complete R15 arm parts and shoulder, elbow, and wrist joints before cloning the local punch rig. Character replacement cancels stale builds. Missing rig pieces and synchronous load failures produce a named warning.
- `CameraDirector` selects first person as soon as `HRushInMatch` becomes true and keeps it through results. Match view-toggle requests are ignored; the previous lobby preference returns afterward. First-person look-back is disabled.
- `TargetLockController` keeps its camera at the character's eye height in a match. `CameraDirector` keeps the head hidden while target lock or Tsinelas aim owns the view. The mobile view-toggle button was removed.
- No animation ID, server tag validation, remote, locked Config value, or authored map object changed. The four touched modules are in `studio-camera-tag.project.json`, restricted to place ID `127422539599317` with unknown objects preserved.

## Open Studio and asset status

- Read-only Studio output showed that `rbxassetid://132133679924288` was denied. The owner subsequently reported granting this experience access to the existing asset. Playback after that permission change remains unverified; old Output errors do not establish the current permission state. If the first-person ID `rbxassetid://105436702082738` produces the same error in owner testing, grant that asset access too. Neither asset ID was replaced.
- Syntax, notes, diff whitespace, full Rojo build, and targeted Rojo build passed. The project owner connected Rojo to `localhost:34872`, and the four-module overlay reached the same open Habulan Rush Edit place. Read-only Studio inspection confirmed the new match camera, R15 arm-rig wait and load warning, eye-height target lock, and HUD without the view toggle. It also confirmed all 12 spawn regions, `SpawnSelector`, and the original enabled Map.Spawn at `(0, 0.5, 0)` remain. The owner still needs to save the place. No publish or agent Studio test was run.

## Owner test checklist

1. With two clients, start each of Classic Tag, Agawan ng Panyo, and Lihim na Target. Check first person from match entry through mode/map vote, countdown, live rounds, recaps, and match results; return to lobby and check the prior camera behavior. Repeat a shorter eight-client pass.
2. Press Z and DPadUp during a match and check that neither opens third person. On mobile, confirm the 1P/3P button is absent. Check respawn, target lock, target-lock release, Tsinelas aim and release, and camera/head visibility.
3. Use click, R2, and touch TAG, STEAL, or CAPTURE when each action is eligible. Check that the local punch is visible and that another player sees the replicated punch. Repeat after respawn and during walking, sprinting, and misses. The server must still reject invalid hits.
4. Check Studio Output for new animation permission errors or `[TagController]` rig/load warnings. Confirm the existing third-person animation plays after the reported access grant, and repeat the two-client animation check if any new denial appears.
