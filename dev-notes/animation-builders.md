---
title: animation builders
type: seed
status: active
owner: project-owner
task: T09
updated: 2026-10-15
source: tools/AnimationDev/HRush_AnimDev.lua
related:
  - ./00-index.md
  - ./rs-03-tsinelas-throw.md
  - ./current-task.md
  - ../docs/MOVEMENT_AUDIT.md
---

Verified reference for the HRush animation authoring tool.

## Verified facts

- Batch 0 replaced the live authoring tool with one `AnimationSpecs` data table.
- Every requested movement animation has a name, loop flag, priority, duration, keyframes list, and marker list.
- Batch A authors Walk, Sprint, JumpStart, Fall, Land, and LandHard from original pose data.
- Batch B authors Dash, SlideEnter, SlideLoop, SlideExit, and SlideJump from original pose data.
- Batch D authors Vault from original pose data. The other eight unpublished production keyframe lists remain empty until their approved animation batch.
- `HRush_PipelineSelfTest` is development-only and proves build, marker, preview, quarter-speed, and scrub paths.
- The builder uses the verified R15 body-part Pose hierarchy from `HumanoidRootPart` through hands and feet.
- The current generated R15 rig uses `AnimationConstraint` joints. Names and connected body parts match the standard 15-joint R15 hierarchy.
- Preview registration uses current `AnimationClipProvider:RegisterAnimationClip()`, not deprecated `KeyframeSequenceProvider`.
- The 12 Batch A through C IDs supplied by the project owner are wired into `Config.Animations`. The other nine entries use `REPLACE_ME_HRush_*` placeholders, which runtime loading rejects.
- Existing backup files are historical only. Do not copy or lightly edit their pose data for the new animation set.
- Batch A Studio validation built six production sequences and passed normal-speed, 0.25-speed, and scrub checks for every clip.
- Sprint contains `FootstepL` at 0.000 and `FootstepR` at 0.225. Land contains `LandImpact` at 0.080. LandHard contains `LandImpact` at 0.100.
- All six Batch A asset IDs are published, wired, and recorded as original project-owned assets.
- Batch B Studio validation built all five new sequences and passed normal-speed, 0.25-speed, and midpoint scrub checks for every clip.
- SlideEnter ends on the exact SlideLoop opening pose. SlideExit and SlideJump start on that same pose. SlideExit ends on Sprint's opposite contact pose so the state transition does not reset to neutral.
- All five Batch B asset IDs are published, wired, and recorded as original project-owned assets. The legacy sprint, combined slide, and dash fallbacks are removed.
- Batch C Roll uses seven keyframes over 0.45 seconds, is Action priority and non-looping, and places `RollImpact` at 0.14 seconds. Studio validation, normal speed, 0.25 speed, and scrub checks passed.
- Roll mechanic playback uses published ID `rbxassetid://97323662606589`. Studio verified 0.45-second, Action, non-looping metadata.
- Batch D Vault uses seven keyframes over 0.40 seconds, is Action priority and non-looping, and places `VaultPlant` at 0.10 seconds plus `VaultClear` at 0.26 seconds. Studio validation, normal speed, 0.25 speed, and sampled silhouette checks passed.
- Vault mechanic playback uses published ID `rbxassetid://88476053772200`. Studio verified seven keyframes, 0.40-second duration, Action priority, and non-looping metadata. Replication checks remain pending.
- Current published runtime playback uses Sprint, Dash, SlideLoop, Roll, and Vault. Walk, JumpStart, Fall, Land, LandHard, SlideEnter, SlideExit, and SlideJump remain metadata until an approved movement-state owner integrates them.
