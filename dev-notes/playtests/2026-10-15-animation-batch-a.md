---
title: 2026-10-15 animation batch A
type: playtest
status: passed
owner: project-owner
task: T09
updated: 2026-10-15
source: tools/AnimationDev/HRush_AnimDev.lua
related:
  - ../00-index.md
  - ../current-task.md
  - ../../docs/MOVEMENT_AUDIT.md
---

Animation Batch A authoring and local preview checks passed. This validates the six animation clips and authoring pipeline only. It is not the pending two-player gameplay test.

## Scope

- HRush_Walk
- HRush_Sprint
- HRush_JumpStart
- HRush_Fall
- HRush_Land
- HRush_LandHard

No animation was published. No runtime asset ID or gameplay mechanic changed.

## Studio setup

One local Studio Play session used a generated R15 preview rig and the canonical repository module copied into `Workspace.AnimationDevelopment.HRush_AnimDev`.

## Results

| Check | Result | Evidence |
|---|---|---|
| Validation | pass | `validateAll()` returned true |
| Build | pass | `buildAll(false)` produced exactly six production sequences |
| Walk | pass | Seven keyframes, 0.700 seconds, closed loop |
| Sprint | pass | Seven keyframes, 0.450 seconds, closed loop, visible airborne pose at 0.115 |
| JumpStart | pass | Five keyframes, 0.200 seconds, anticipation through extension |
| Fall | pass | Five keyframes, 0.600 seconds, closed loop |
| Land | pass | Five keyframes, 0.250 seconds, soft impact and recovery |
| LandHard | pass | Seven keyframes, 0.400 seconds, deep crouch and planted-hand hold at 0.160 |
| Markers | pass | FootstepL 0.000, FootstepR 0.225, LandImpact 0.080 and 0.100 |
| Normal playback | pass | All six tracks played at speed 1 with full preview weight |
| Quarter speed | pass | All six tracks played at speed 0.25 with full preview weight |
| Scrub | pass | All six tracks held their midpoint at speed 0 with full preview weight |

## Issue found and fixed

The scrub helper paused a track during its 0.08-second blend-in. In Edit mode this could leave the rig at weight 0 and display its rest pose. `scrub()` now sets preview weight to 1 immediately before returning. The final Play mode check reported full weight for every scrubbed clip.

## Remaining review

- [ ] Project owner reviews each clip in Studio from front, side, and gameplay camera angles.
- [ ] Project owner publishes only approved revisions under the same user or group that owns the experience.
- [ ] Published IDs are returned for `Config.Animations`, fallback removal, and `ASSET_LOG.md` entries.
- [ ] Separate two-player runtime validation checks local and remote animation replication after IDs are wired.
