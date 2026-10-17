---
title: Moving and airborne pounce with pounce-only tags
type: handoff
status: owner-testing
owner: project-owner
task: pounce-tag-ability
updated: 2026-10-17
source: src/ServerScriptService/TagService.server.lua
---

## Latest midair fix and cooldown revision

The owner reported that pounce still failed in the air. Source inspection found that AirMovement intentionally calls Humanoid:Move(Vector3.zero) to preserve committed jump movement. Pounce eligibility incorrectly required the resulting MoveDirection to remain nonzero. Pounce now reads horizontal velocity while airborne and captures that direction before windup, preserving the same direction at launch. Grounded activation still uses movement input.

Cooldowns are reduced by half: hit 0.8 seconds, miss 1.05 seconds, measured from launch. Existing recovery must also finish before another attempt. Check a moving jump during ascent, at the apex and on descent; also check releasing movement midair while momentum continues. A stationary jump without horizontal movement must not pounce. No tests were run for this change.

## Approved change

The owner confirmed that pounce requires movement but may start while walking, sprinting, or jumping. Only a successful pounce hit may transfer Taya, including interactions with bots. Standing-still activation remains disabled. Testing belongs to the owner; no tests were run for this revision.

## Implementation

- Removed sprint and grounded activation requirements on client and server. Ordinary jumping is allowed; incompatible skill-flight, stun, slide, roll, vault, dash, recovery and cooldown gates remain.
- Removed both player and bot proximity-touch tag paths. MatchService transfers Taya only through its validated active-pounce commit boundary. Initial round assignment and disconnect replacement remain match lifecycle actions.
- Included registered match bots in server hit queries, client aim assistance, and observer effects. Safe windows, cone, distance, line of sight and one-hit rules apply to both players and bots.
- Bot Tayas request the same authoritative pounce lifecycle. The server moves and animates their pounces, then restores normal AI movement after recovery. Bots cannot tag by merely touching a Runner.
- Exact supplied animation IDs, launch velocity, and camera settings are unchanged. Cooldowns follow the latest revision above.

## Owner checklist

Open the fresh `HabulanRush.rbxlx` and queue a live match. Use two real clients for player-to-player checks; bot fill can cover bot interactions.

1. As Taya, walk forward without Shift and left-click. Check pounce starts.
2. Jump while moving and left-click during ascent, near the apex, and while falling. Check each attempt starts when cooldown is ready.
3. Stand still and click. No pounce should start.
4. Walk into or stand against a Runner without pouncing. Neither player nor bot contact should transfer Taya.
5. Pounce into a real Runner, then a bot Runner. Check exactly one role transfer, Tag animation and impact feedback.
6. Let a bot become Taya. Check it visibly pounces to tag and cannot tag through simple contact, cooldown or walls.
7. Miss, spam clicks, and try beside/behind/wall-covered targets. Check no extra hit or cooldown bypass.
8. Hold sprint through recovery, then repeat with sprint released. Check movement resumes correctly.
9. Die or end the round during pounce. Check movement, camera, animations and trails clean up.

## Validation

Rojo build passed and regenerated `HabulanRush.rbxlx`. Gameplay, syntax, notes and device tests were intentionally not run at the owner's request. Earlier evidence belongs to the prior rules and does not validate this revision. No new asset IDs were added.
