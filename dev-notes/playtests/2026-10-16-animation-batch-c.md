---
title: 2026-10-16 animation and mechanic batch C
type: playtest
status: partial
owner: project-owner
task: T09
updated: 2026-10-16
source: tools/AnimationDev/HRush_AnimDev.lua
related:
  - ../00-index.md
  - ../current-task.md
  - ../../docs/MOVEMENT_AUDIT.md
---

Batch C authoring and fresh-build solo client/server checks passed. The required two-player, gamepad, mobile, and published-animation checks remain pending.

## Scope

- Original `HRush_Roll` R15 animation
- Landing input buffer
- Client Roll prediction and cleanup
- Server-authoritative Roll validation and state
- Placeholder-safe runtime animation loading

`HRush_Roll` is published as `rbxassetid://97323662606589`, wired into `Config.Animations.Roll`, and recorded in `ASSET_LOG.md`.

## Results

| Check | Result | Evidence |
|---|---|---|
| Animation validation | pass | `validateAll()` returned true |
| Animation build | pass | `buildAll(false)` produced Roll with seven keyframes over 0.45 seconds |
| Metadata | pass | Action priority, non-looping, `RollImpact` at 0.14 seconds |
| Normal playback | pass | Track advanced at speed 1 with full preview weight |
| Quarter speed | pass | Track advanced at speed 0.25 with full preview weight |
| Scrub | pass | Impact, tucked rotation, recovery, and 0.449-second handoff poses held at speed 0 |
| Visual review | pass | Full forward rotation remained readable and recovered into the Sprint opening pose |
| Placeholder safety | pass | Roll placeholder was rejected before preload and `LoadAnimation` |
| Published asset | pass | ID `97323662606589` loaded and played at 0.45 seconds, Action priority, non-looping |
| Client landing buffer | pass | Existing C input was consumed inside the configured 0.15-second pre-landing window |
| Client state | pass | `HRushRolling` entered and cleared after the configured 0.45-second duration |
| Server authority | pass | Server independently observed the prompt landing, entered Roll, returned to Walk, and recorded zero violations |
| Landing replication race | pass after fix | Server queues the request briefly until its own `FloorMaterial` becomes grounded; client also consumes a live buffer when grounded state and `FloorMaterial` settle in either order |
| Repository syntax | pass | `scripts/check-syntax.ps1` |
| Rojo build | pass | Fresh place generated and opened in Studio |

## Remaining checks

- [x] Publish `HRush_Roll` under the same owner as the experience and return the real asset ID.
- [x] Wire the real ID into `Config.Animations.Roll` and add the original asset to `ASSET_LOG.md`.
- [ ] Run a two-player Clients and Servers test and confirm remote animation replication.
- [ ] Confirm Runner and Taya both roll and preserve their incoming momentum.
- [ ] Confirm normal touch tagging and pounce interaction remain unchanged during Roll.
- [ ] Test C, ButtonR1, and the existing touch slide action.
- [ ] Test death, respawn, stun, role swap, round end, and Roll to Fall cancellation with two players.
- [ ] Check intended avatar proportions for ground clipping and limb intersections.

## Known boundary

The current game has no normal hard-landing penalty. Batch C leaves that behavior unchanged. A hard-landing penalty needs a separately approved landing-system implementation.
