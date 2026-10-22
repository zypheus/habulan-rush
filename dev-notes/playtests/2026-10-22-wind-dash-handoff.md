---
title: wind dash VFX handoff
type: playtest
date: 2026-10-22
status: pending
owner: project-owner
task: wind-dash-runtime-replacement
updated: 2026-10-22
source: owner-approved runtime dash VFX plan
---

# Wind dash VFX handoff

## What is built

Repository source now owns the dash effect. `ReplicatedStorage/VFX/WindDash` creates one foot burst and sparse air flecks from the existing wind streak texture, one Beam, and three Trails. It follows the character cosmetically, stops generating ribbons at about 0.22 seconds, and destroys the rig at 0.35 seconds. At most 14 particles are emitted per full-intensity replay. The old inline `DashTrail` and sparkle emitter are removed. A server-accepted live dash broadcasts direction, start position, and time for observer rendering; lobby warm-up dashes remain local. Dash motion and controls are unchanged. The original Studio-only `FOOT PULSE` was not replaced in the imported comparison folder; the Rojo place uses source VFX.

The runtime uses `rbxassetid://12402893521`. The two other imported textures remain logged as original Studio comparison assets. No texture was uploaded. The working tree already contained unrelated EquipmentGlide edits in Config, MovementAuthority, and AirMovement; this item preserves them.

## Owner validation in the rebuilt place

1. Open the latest `HabulanRush.rbxlx` and start a live round with two players. Dash forward and sideways from both players. Confirm exactly one burst and four visible wind ribbons per dash, all flowing behind the actual travel direction. Confirm the observer sees the accepted dash, and neither player sees the legacy sparkle or `DashTrail`.
2. Inspect close and player-like views at roughly 0.03, 0.13, 0.22, and 0.35 seconds against the reference: sharp white/pale-cyan foot pulse, readable icy ribbons at peak, sparse backward flecks, then a clean fade. Check ribbon thickness and overdraw on a mobile screen.
3. Dash into a wall, interrupt a dash, repeat rapidly, die during a dash, and respawn. Confirm no `WindDashFX` rigs or visible particles linger and no dash movement changes. The base dash remains 12 studs over 0.2 seconds; the existing live speed scale can affect observed travel.
4. Set VFX intensity to 0, 50, then 100 before dashing. Zero should create no rig; 50 should reduce width and opacity; 100 should show the full effect. Repeat with gamepad ButtonB and the mobile DASH touch action. Verify both local and observer views.

## Evidence and limits

Source syntax, diff whitespace, and Rojo build passed after the final source patch. An earlier two-client Studio run saw one local and one observer rig for an accepted dash, matching sideways direction, cleanup after the fade, a gamepad ButtonB observer rig, and 0/50/100 VFX scaling. A later direct module probe saw immediate cleanup on death and zero rigs after respawn. The owner will conduct final visual and device acceptance. Mobile touch, wall stops, and repeated-dash residue are not yet accepted. The generated place has not been published.
