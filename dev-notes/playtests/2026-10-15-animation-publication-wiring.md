---
title: 2026-10-15 animation publication wiring
type: playtest
status: passed
owner: project-owner
task: T09
updated: 2026-10-15
source: src/ReplicatedStorage/Config.lua
related:
  - ../00-index.md
  - ../current-task.md
  - ../../docs/MOVEMENT_AUDIT.md
---

Batch A and B publication wiring passed repository validation and loaded in a fresh Rojo-built Studio place. Ten assets matched the authored clip metadata. The project owner confirmed the Fall ID is correct despite different published metadata.

## Scope

- Verify the 11 project-owner-supplied IDs in `Config.Animations`.
- Confirm the legacy Sprint, combined slide, and Dash fallbacks are absent.
- Load and play every supplied ID through an `Animator`.
- Compare published duration, loop flag, priority, and keyframe count with the canonical authoring data.

This was a single-player asset and configuration check. It was not a two-player replication or movement transition test.

## Results

| Check | Result | Evidence |
|---|---|---|
| Syntax | pass | `scripts/check-syntax.ps1` returned `SYNTAX OK` |
| Notes | pass | `scripts/check-notes.ps1` returned `NOTES OK` |
| Rojo build | pass | Fresh `HabulanRush.rbxlx` generated successfully |
| Config IDs | pass | All 11 supplied IDs matched the values in `Config.Animations` |
| Fallback removal | pass | Sprint and Dash have no `FallbackId`; `SlideLegacy` is absent |
| Asset loading | pass | All 11 IDs loaded and played through a fresh-build Studio server `Animator` |
| Published metadata | observation | Ten assets matched source duration, loop flag, priority, and keyframe count |
| Fall | confirmed | `rbxassetid://106234834891508` returned 0.25 seconds, Action priority, non-looping, and five keyframes; project owner confirmed the ID is correct |

## Fall metadata observation

The canonical `HRush_Fall` source is 0.60 seconds, Movement priority, looping, and five keyframes. The supplied ID was tested twice. Its loaded track remained 0.25 seconds, and its published sequence metadata reported Action priority and non-looping.

The project owner confirmed this is the correct Fall ID. Fall remains metadata-only, so preserve the observation for transition testing when an approved state owner integrates it.

## Remaining review

- [ ] Run a two-player local and remote playback check for Sprint, Dash, and SlideLoop.
- [ ] Approve a client movement-state owner before integrating the other published clips.
