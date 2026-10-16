---
title: animation and mechanic batch d playtest
type: playtest
status: partial
owner: project-owner
task: movement-animation-batch-d
updated: 2026-10-16
source: ../../docs/MOVEMENT_AUDIT.md
---

# Batch D Vault validation

## Passed

- Repository syntax check passed.
- Rojo build to `HabulanRush.rbxlx` passed.
- `validateAll()` returned true.
- `buildAll(false)` produced 13 completed production sequences.
- `HRush_Vault` built with seven keyframes, 0.40-second duration, Action priority, non-looping metadata, `VaultPlant` at 0.10, and `VaultClear` at 0.26.
- Normal preview advanced to 0.171 seconds.
- Quarter-speed preview advanced to 0.104 seconds after 0.40 seconds and reported a 0.400-second track length.
- Plant, tucked swing, and clear silhouettes were reviewed on the current AnimationConstraint R15 rig.
- Fresh runtime testing found the Luau 200-register limit in `MovementController`, then confirmed the grouped Vault state fix loaded and attached the controller.
- Automatic local contact cleared a Kalsada crate measuring exactly 3.5 studs. The observed move started near z=25 and finished near z=36.14 with Vault cooldown active.
- Project-owner-supplied Vault ID `rbxassetid://88476053772200` is wired in `Config.Animations.Vault` and recorded in `ASSET_LOG.md`.
- Studio loaded the published asset as a seven-keyframe KeyframeSequence with 0.40-second duration, Action priority, and non-looping metadata.

## Issues found and fixed

- Avatar HipHeight placed the estimated feet below the map and made the exact 3.5-stud crate measure too tall. Client and server now measure obstacle height from ground raycasts.
- Client prediction zeroed velocity before the server handled the Vault request. The first live-round attempt predicted locally but the server rejected `vault_speed` at zero. `MovementAuthority` now keeps a short recent server-observed horizontal velocity window instead of trusting any client speed claim.

## Pending

- Reopen the fresh build and confirm client `HRushVaulting` and server `HRushServerVaulting` become true on the same crate pass with zero new movement violations.
- Run the required two-player Clients and Servers crate test.
- Test Runner and Taya entry from walk, sprint, dash, jump or fall, and slide states.
- Confirm Roll never enters Vault.
- Confirm 4-stud jeepneys reject at the current 3.5-stud cap.
- Confirm low overhead clearance, no landing, excessive travel, low speed, reverse direction, cooldown, stun, role change, round end, death, and respawn reject or cancel cleanly.
- Test gamepad and touch movement into a crate. No Vault button exists because contact is automatic.
- Verify local or remote Vault animation replication.

## Blocker

Roblox Studio closed before the final server-acceptance retest. The source and build contain the velocity-window fix, but that exact authority result is not yet claimed as passed.
