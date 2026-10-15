---
title: 2026-10-15 animation batch B
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

Animation Batch B authoring and local preview checks passed. This validates the five animation clips and authoring pipeline only. It is not a slide or dash gameplay test.

## Scope

- HRush_Dash
- HRush_SlideEnter
- HRush_SlideLoop
- HRush_SlideExit
- HRush_SlideJump

No animation was published. No runtime asset ID, movement value, state machine, collision profile, or gameplay mechanic changed.

## Studio setup

One local Studio Play session used a generated R15 preview rig and the canonical repository module copied into `Workspace.AnimationDevelopment.HRush_AnimDev`.

## Results

| Check | Result | Evidence |
|---|---|---|
| Validation | pass | `validateAll()` returned true |
| Build | pass | `buildAll(false)` produced 11 completed production sequences, including all five Batch B clips |
| Dash | pass | Six keyframes, 0.250 seconds, stretched lean and sprint-ready recovery |
| SlideEnter | pass | Four keyframes, 0.120 seconds, sprint handoff through fast drop |
| SlideLoop | pass | Five keyframes, 0.450 seconds, closed hold loop |
| SlideExit | pass | Four keyframes, 0.150 seconds, direct handoff into Sprint's opposite contact pose |
| SlideJump | pass | Five keyframes, 0.300 seconds, preload through airborne tuck and fall release |
| Normal playback | pass | All five tracks played at speed 1 with full preview weight |
| Quarter speed | pass | All five tracks played at speed 0.25 with full preview weight |
| Scrub | pass | All five tracks held their midpoint at speed 0 with full preview weight |
| Slide silhouette | pass | Rear and side samples showed a reclined torso, extended lead leg, tucked trailing leg, and wide braced arms |

## Test correction

The first SlideEnter normal-speed assertion sampled at 0.054 seconds, before the standard 0.08-second blend reached full weight. The test was corrected to sample at 0.096 seconds. The clip then passed without changing its duration, poses, or blend time.

## Remaining review

- [ ] Project owner reviews all five clips from front, side, rear, and gameplay camera angles on the intended avatar proportions.
- [ ] Check SlideLoop against low-gap geometry after the future authoritative slide profile is implemented.
- [ ] Publish only approved revisions under the same user or group that owns the experience.
- [ ] Return the real IDs for `Config.Animations`, fallback removal, and `ASSET_LOG.md` entries.
- [ ] Run a separate two-player replication and transition test after the new IDs are wired.
