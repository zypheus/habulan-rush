---
title: 2026-10-15 animation batch 0
type: playtest
status: passed
owner: project-owner
task: T09
updated: 2026-10-15
source: working tree built to HabulanRush.rbxlx
related:
  - ../00-index.md
  - ../current-task.md
  - ../../docs/MOVEMENT_AUDIT.md
---

Animation Batch 0 pipeline, validator, R15 hierarchy, and preview checks passed. This was a tool validation, not the pending two-player gameplay test.

## Build and date

Repository working tree built to `HabulanRush.rbxlx` on 2026-10-15.

## Players

One local Studio Play session. The preview animation ran on a generated R15 test rig. No multiplayer gameplay claim was made.

## Checklist

- [x] Confirm generated R15 joint names and connected body parts.
- [x] Build the development-only pipeline sequence.
- [x] Confirm marker and full hand and foot Pose nesting.
- [x] Reject an empty production placeholder.
- [x] Detect loop mismatch, rotation jump over 120 degrees, and marker outside duration.
- [x] Remove stale generated HRush sequences before rebuild.
- [x] Play at normal speed and 0.25 speed.
- [x] Scrub and hold a requested time.
- [x] Remove temporary Studio validation objects.

## Results

| Check | Pass or fail | Notes |
|-------|--------------|-------|
| R15 hierarchy | pass | Generated rig exposed Root, Waist, Neck, shoulders, elbows, wrists, hips, knees, and ankles as AnimationConstraints |
| Sequence build | pass | Three keyframes, full nested Pose tree, and PipelineMidpoint marker |
| Placeholder guard | pass | HRush_Walk returned placeholder has no keyframes |
| Validator branches | pass | Loop mismatch, 150-degree rotation jump, and out-of-range marker were detected |
| Output cleanup | pass | buildAll removed a stale HRush KeyframeSequence |
| Normal preview | pass | TimePosition reached 0.150 seconds |
| Quarter-speed preview | pass | TimePosition reached 0.033 seconds over the same sample |
| Scrub | pass | TimePosition held at 0.250 seconds |

## Bugs found

None in the Batch 0 pipeline. Existing Studio UIBlox warnings were unrelated.

## Follow-ups

- [ ] Project owner reviews Batch 0 and approves or rejects Batch A.
- [ ] Open the fresh generated place for the separate Step 1 two-player movement-authority test.
