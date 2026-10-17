---
title: movement part 0 audit measurements
type: playtest
status: complete
owner: project-owner
task: movement-upgrade-part-0-audit
updated: 2026-10-16
source: ../../docs/MOVEMENT_AUDIT.md
related:
  - ../current-task.md
  - ../../docs/MOVEMENT_AUDIT.md
---

# Movement Part 0 Audit Measurements

## Scope

Read-only runtime measurement of current jump, gravity, Vault configuration, and camera defaults in the generated `HabulanRush.rbxlx`.

## Setup

- Solo Studio Play session.
- Temporary 200 by 200 stud flat platform at runtime only.
- Jump cases used the live W, Shift, and Space input paths after a transient live-round state was enabled.
- The temporary platform was destroyed. Play stopped without saving.

## Output evidence

- Gravity: 196.2 studs/s squared.
- Humanoid: `UseJumpPower = true`, JumpPower 50, inactive JumpHeight 7.2.
- Stationary jump: 50.55 studs/s takeoff vertical speed, 6.40-stud apex, 0.53-second air time.
- Walk jump: 19.20 studs/s horizontal takeoff, 6.40-stud apex, 0.53-second air time, 10.24-stud reach.
- Sprint jump: 25.20 studs/s horizontal takeoff, 6.40-stud apex, 0.53-second air time, 13.44-stud reach.
- Lobby camera: Scriptable, FOV 42.
- Live-match camera: Custom, FOV 70.
- Camera render priority: 200. Min zoom: 0.5. Max zoom: 400.
- Vault minimum speed: 15.12 studs/s. Max height: 3.5 studs. Knee probe: 1.0 stud. Waist probe: 3.75 studs. Ground probe depth: 8 studs.

## Result

Part 0 audit evidence is complete. No gameplay code, Config value, asset, or saved Studio object changed. Part 1 remains blocked on project-owner approval.
