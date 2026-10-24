---
title: Earned sprint movement balance handoff
type: playtest
status: awaiting-owner-test
owner: project-owner
task: earned-sprint-movement-balance
updated: 2026-10-24
source: 2026-10-24 owner-approved earned sprint and movement balance plan
related:
  - ../current-task.md
  - ../../DESIGN_LOCK.md
  - ../../studio-earned-sprint.project.json
---

# Earned sprint movement balance

## Source and Edit handoff

- Owner-approved source changes remove stamina and held sprint. Both roles earn a three-second sprint from two server-accepted slides or landing rolls within 2.5 seconds. A slide counts when server-observed speed is at least half that role's walking speed, including when it earns no momentum. Dash does not count. Further actions in the chain refresh the sprint window after that action ends.
- The server owns chain credit, the sprint timer, role/stun/death/respawn/round-end resets, and sprint request validation. The existing owner-only `MomentumUpdate` carries chain and timing data. The HUD shows chain progress and the active timer; keyboard, gamepad, and touch manual sprint controls and the stamina bar are removed.
- Runner dash cooldown is five seconds and remains Runner-only. Taya base sprint is 22, giving 26.4 studs/s with the existing speed scale; Runner sprint is 25.2 studs/s. Lobby movement remains walking speed.
- The source of truth is the repository. `studio-earned-sprint.project.json` serves only Config and eight touched movement, HUD, camera, and lobby modules to place `127422539599317`; it includes no Workspace map assets. After a Rojo server reconnect, read-only Studio inspection confirmed all nine mapped scripts in the same open Edit place. Studio Config now has Taya sprint 22 and dash cooldown 5; script search found the new chain tuning and no stamina or touch sprint references. The 12 spawn regions, Panyo marker, and original lobby Spawn remain in Studio.
- Syntax, notes, diff whitespace, and full and targeted Rojo builds passed before this handoff. No Studio gameplay test, Luau execution, or publish was run by the agent. No new asset was introduced.

## Owner test checklist

1. Save the same open Habulan Rush Edit place. The agent confirmed the targeted sync read-only. Do not publish for this handoff.
2. Run repeated 2-player and 8-player rounds in Classic Tag, Agawan ng Panyo, and Lihim na Target. From ordinary walking, do two slides or landing rolls within 2.5 seconds and confirm sprint starts after the second action ends, lasts three seconds, and refreshes from another accepted chain action. A dash must not count. After a longer gap, the next action starts a new 1/2 chain.
3. Confirm a slide near walking speed counts for the chain even when momentum gain is zero, while a slide below half walking speed does not count. Check the HUD chain and sprint timer against actual movement.
4. Confirm Runner sprint is 25.2 studs/s and Taya sprint is 26.4 studs/s before momentum or temporary boosts. Runner dash must be available again after five seconds and Taya must never dash. Neither dash nor sprint should require stamina.
5. Confirm role transfer, stun, death, respawn, and round end clear the chain and sprint. Lobby movement stays walking speed. Check first-person camera, sprint animation, VFX, target lock, Tsinelas aim, and round recap transitions.
6. On keyboard, gamepad, and touch, confirm Shift/L2/full-stick/touch sprint controls are absent, the stamina bar is absent, and Dash/Slide/Skill/Tsinelas controls remain visible and usable. Report any clipping, stale timer, unexpected sprint, or movement rejection with mode, role, action timing, device, and Studio Output excerpt.

## Acceptance

- Studio sync: confirmed by read-only inspection in the same open Edit place.
- Owner save: pending.
- Owner 2-player, 8-player, and device gameplay results: pending.
