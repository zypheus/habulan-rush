---
title: animation builders
type: seed
status: approved
owner: team
task: T09
updated: 2026-10-14
source: tools/AnimationDev/HRush_AnimDev.lua:113-141
related:
  - ./00-index.md
  - ./rs-03-tsinelas-throw.md
---

Verified reference for the HRush animation authoring tool.

## Verified facts

- `tools/AnimationDev/HRush_AnimDev.lua` builds the sprint, slide, and dash keyframe sequences from tunable params.
- Slide v4 is a 5-key tactical slide with target duration 1.0 s (`SlideParams.Duration`, line 114). The live clip length comes from `Config.Movement.SlideDuration`, fallback 1.0 (lines 141, 435-445).
- Published IDs live in `Config.Movement` as `SprintAnimId`, `SlideAnimId` (v4), and `DashAnimId`.
- Backup copies (`HRush_AnimDev.backup.lua`, `HRush_AnimDev.v2backup.lua`) sit next to the live file. The live file is the only one that matters.
