---
title: Pounce and Tag integration playtest
type: playtest
status: owner-testing
owner: project-owner
task: pounce-tag-ability
updated: 2026-10-17
source: tools/PounceDev/README.md
---

## Scope and approval

The project owner requested the complete third-person Pounce / Tag implementation and approved replacing locked pounce timing values. They also approved Taya sprint at 21 base, 25.2 effective studs/s. See [design revision](../../DESIGN_LOCK.md).

## Implementation

- `PounceController` owns conditional MouseButton1/ButtonR2/touch input, predicted states, launch velocity, limited steering, the exact four supplied animation IDs, and hit/miss recovery.
- `TagService` owns IDs, request rate limits, state/cooldown checks, recent grounded observation, travel limits, collision, forward spatial queries, cone checks, and line of sight. It invokes the server-only MatchService commit boundary. Clients cannot submit a hit or target claim.
- `PounceCamera` adds and removes its own FOV and CFrame contribution around the existing camera pipeline. `PounceEffects` creates original dust, trails, streaks, flash and ring primitives for the actor and observers. The six sound hooks remain empty.
- Movement, normal air and landing owners yield to pounce. Held sprint survives tag role changes. The existing HUD displays the pounce cooldown.

## Runtime evidence

Studio MCP ran two real clients through `StudioTestService`, with the actual queue, match, role and tag services. The [fixtures](../../tools/PounceDev/README.md) are stored outside the Rojo production map.

- Startup: R15, correct CAS binding, existing-HUD chip, and lobby activation rejection confirmed.
- First run exposed a server FloorMaterial delay: accepted short hops were classified as misses before replicated flight reached the server. Replaced that landing check with ground distance and vertical motion, plus a bounded 0.20-second recent-ground observation for predicted requests.
- Subsequent run confirmed server Hit events on both players, exactly one Hit per ID, Action Tag playback only on hits, all intended client state transitions, and held sprint after the role swap.
- Misses reached 55 studs/s, about 0.40 studs of rise, recovered to Taya sprint at 25.2, and restored FOV to 70. Released sprint returned to 21.6 walk speed.
- A 100-stud teleport during flight received Cancel. Duplicate, old and malformed IDs produced no extra launch or hit.
- Camera and trail cleanup passed in recorded hit/miss/teleport/death cases. No supplied animation was edited or republished.

## Build and handoff, 2026-10-17

The project owner requested no further agent testing. Rojo successfully built `HabulanRush.rbxlx`. No Studio instances were connected at handoff. Open the freshly built file instead of an older unsaved Studio session; development fixtures are not Rojo mapped.

The last asserted multiplayer run stopped because an expected hit received Denied. Earlier runs passed confirmed hits, repeat hits, miss recovery and teleport rejection. This inconsistency remains unresolved; gameplay validation is not complete. Final wall, respawn, fresh-ID cooldown, mobile and gamepad checks remain pending.

## Owner checklist

1. Open the rebuilt place. Use Test, Clients and Servers, with at least two players. Queue a live match and become Taya. Pounce targets must be real players, not test bots.
2. Hold Shift and move forward, then left-click while grounded. Check quick Windup, forward Leap, small upward hop, and one attempt despite rapid clicks. Taya sprint should be 25.2 studs/s.
3. Aim at a Runner in front. Check one role transfer, Tag animation, impact effects, then Recovery. Check both clients see the result. Report grounded sprint attempts that do nothing or cancel immediately.
4. Miss deliberately. Check no Tag animation, heavier Recovery, and 2.1-second cooldown from launch. A confirmed hit uses 1.6 seconds.
5. Keep sprint held through Recovery. Sprint should resume without repressing Shift. Release sprint during flight and check return to normal movement.
6. Try stationary, airborne, sliding, vaulting, stunned, Runner-role, and cooldown clicks. Pounce must not start. Ordinary UI clicks must still work.
7. Try targets beside, behind, and behind a wall. Check no pounce tag through cover and no wall clipping or stuck movement.
8. Die, respawn, and finish a round during pounce. Check restored movement, camera and FOV, with no lingering trails. Repeat several attempts to catch accumulating camera offsets.
9. On gamepad, check L2 sprint and R2 pounce. On mobile, check Sprint plus POUNCE, button spacing, and the bottom-center cooldown indicator.
10. Sound hooks are intentionally empty. Missing new pounce audio is expected until original sound IDs are supplied.

## Limits and follow-up

- Studio fixtures use a local server. Real network latency and owner gameplay feel review remain follow-up checks.
- The exact supplied animation IDs load in Studio. Their competition provenance is recorded as pending owner confirmation in [ASSET_LOG](../../ASSET_LOG.md).
- Existing unrelated Studio plugin-icon moderation and CoreGui warnings appeared during startup. Test setup teleports produce expected log-only MovementAuthority warnings.
- Earlier movement Part 2 owner review and separate movement device/replication checks remain pending. This pounce session does not close those items.
