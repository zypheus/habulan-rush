---
title: Simple click-to-tag handoff
type: handoff
status: owner-testing
owner: project-owner
task: simple-click-tag
updated: 2026-10-18
source: src/ServerScriptService/TagService.server.lua
---

## Implemented

- Pounce and all of its runtime files, remotes, motion, cooldown, camera, VFX, attributes, and HUD were removed.
- Taya tags with left-click, R2, or the mobile TAG button.
- Tag attempts have no gameplay cooldown and require no movement. The server limits requests to 10 per second.
- The server validates the live match, Taya role, stun and skill state, target role, short forward volume, 6.5-stud distance, 70-degree arc, line of sight, safe window, dash immunity, and airborne immunity.
- First person plays `HRush_TagFirstPerson` (`rbxassetid://105436702082738`) on an isolated local arm rig. The rig is separate from the live Humanoid Animator so movement animations keep working.
- The server plays `HRush_TagThirdPerson` (`rbxassetid://139144393566205`) on the character Animator so all players see it. The local first-person track overrides that pose only for the tagging player.

## Owner test

Use two Studio clients. First confirm walk, sprint, jump, fall, landing, dash, slide, roll, and vault animations still play before and after tagging. Confirm tags work while standing, running, jumping, sliding, and vaulting; rapid clicks remain responsive; side, rear, wall-covered, safe-window, airborne-skill, and dashing Runners are rejected; exactly one role transfer occurs; the first-person clip is visible only to its owner; the third-person clip is visible to both players; and the mobile TAG button appears only for the live Taya.

## Validation

Rojo build passed and regenerated `HabulanRush.rbxlx`, per owner request. No syntax, notes, Studio, multiplayer, gamepad, or mobile test was run.
