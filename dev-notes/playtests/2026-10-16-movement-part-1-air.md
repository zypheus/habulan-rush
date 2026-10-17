---
title: movement part 1 air physics
type: playtest
status: complete
owner: project-owner
task: movement-upgrade-part-1-air
updated: 2026-10-16
source: ../../docs/MOVEMENT_AUDIT.md
related:
  - ../current-task.md
  - ../../docs/MOVEMENT_AUDIT.md
---

# Movement Part 1 Air Physics

## Scope

Solo Studio validation of the approved Part 1 jump, fall, air-control, momentum, cap, and server-observation changes. Parts 2, 3, and 4 were not started.

## Flat jump measurements

| Fall gravity | Speed | Apex studs | Air time seconds | Horizontal studs |
|---:|---|---:|---:|---:|
| 1.4 | Walk 19.2 | 6.40 | 0.50 | 9.60 |
| 1.4 | Sprint 25.2 | 6.40 | 0.50 | 12.50 |
| 1.6 | Walk 19.2 | 6.40 | 0.49 | 9.36 |
| 1.6 | Sprint 25.2 | 6.40 | 0.48 | 12.18 |
| 1.8 | Walk 19.2 | 6.41 | 0.47 | 8.96 |
| 1.8 | Sprint 25.2 | 6.40 | 0.47 | 11.76 |

## Runtime evidence

- Coyote input fired 68.6 ms after leaving a narrow test ledge and produced a normal Humanoid jump.
- A jump pressed 115.8 ms before landing fired once, 15.0 ms after touchdown.
- Air control produced 19.20 studs/s with the Studio override at 1.0 and 13.44 studs/s at 0.7.
- An injected 100 studs/s horizontal air velocity was capped at 28.98 studs/s.
- A slide jump left Slide and took off at 26.775 studs/s, matching 31.5 times `SlideJumpKeepPct = 0.85`.
- A long drop reached a render-sampled minimum of -100.00 studs/s.
- A clean flat jump produced zero server movement violations. Server correction remained false.
- The generated place loaded AirMovement and MovementAuthority without a Part 1 runtime error.

## Pending

- Required two-player validation.
- Mobile jump and touch-control validation.
- Gamepad jump and movement validation.
- Owner feel review before any later movement part.
