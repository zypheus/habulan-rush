---
title: First-person FOV setting handoff
type: handoff
status: owner-testing
owner: project-owner
task: first-person-fov-setting
updated: 2026-10-22
source: src/StarterPlayerScripts/CameraDirector.lua
---

## Implemented

- Settings has a first-person FOV slider from 50 to 95 degrees in 1-degree steps. Reset restores the current 72-degree default. The choice lasts for the current client session.
- The director uses the chosen base in first person and keeps the existing camera effects and smooth FOV catch-up. The final first-person target stops at 95 degrees. Third-person FOV is unchanged.
- The settings panel can open during matches from H, ButtonSelect, or the HUD gear. Lobby controls remain hidden, and the panel appears above the gameplay HUD.

## Owner test

Use at least two Studio clients. In first person, set 50, 72, and 95 degrees in the lobby and mid-match; confirm the view changes smoothly and independently for each player. Check movement and momentum FOV additions at 95 degrees stop at the cap, Reset to Defaults, switches between first and third person, and return from aim or target lock. Confirm third-person FOV is unchanged. Open and close Settings with H, ButtonSelect, the HUD gear, X, and the backdrop; confirm no lobby controls appear in a match and they return afterward. Check mouse drag, touch drag, gamepad row focus and left/right adjustment, and phone layouts.

## Validation

Source syntax, notes, and Rojo build passed. No Studio test was run by the agent. All visual, device, and two-player checks are pending project-owner testing.

The owner-requested 95-degree maximum was rebuilt after the original 120-degree implementation. Syntax, notes, and Rojo build passed again; Studio verification of the new cap remains pending.
