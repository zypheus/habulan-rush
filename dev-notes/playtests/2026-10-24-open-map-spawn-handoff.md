---
title: Open map random spawn handoff
type: playtest
status: pending-owner-validation
owner: project-owner
task: open-map-random-spawns
updated: 2026-10-24
source: owner-approved open Studio random spawn plan and Hrush.rbxl export
---

# Open map random spawn handoff

## Implemented

- Imported the owner-provided `Hrush.rbxl` into `assets/Map.rbxmx` and `assets/Terrain.rbxmx`, keeping the authored scene layout and the original enabled origin SpawnLocation. The source file SHA-256 and 58 referenced Roblox IDs are in `docs/OPEN_MAP_ASSET_INVENTORY.md`.
- Marked 150 authored ground Parts, added 12 invisible sampling regions spanning the broad connected walking surfaces, and placed the Panyo marker at `(-10, 10, 0)` above clear central ground. Water, roofs, small edges, and enclosed spaces have no eligible ground tags. The server also marks the same existing Workspace surfaces at runtime for the targeted sync into the open place.
- `SpawnSelector` checks tagged ground, slope, four-corner support, clearance, authored map bounds, and 20-stud separation. Match entry receives distinct positions; later rounds reroll. Ordinary joins and respawns keep the origin SpawnLocation.
- Classic Tag, Panyo, and Secret Hunt use the same round positions. Secret Hunt recovery rerolls away from live players when possible. Panyo pickup and recovery require tagged walkable ground. Bootstrap no longer creates eight fixed round pads when the authored map is present. The Classic map vote now offers Kalsada only because Binaha has no authored playable geometry.
- `studio-spawn.project.json` maps only the new regions, Panyo marker, Config, and the touched server modules. Its unknown-instance guards preserve the open place's authored Workspace objects and all unrelated scripts. It is restricted to place ID `127422539599317`. The full default project remains the canonical future build.
- The targeted Rojo sync was accepted in the same open Habulan Rush Edit place. Read-only inspection confirmed all 12 regions, the marker at `(-10, 10, 0)`, the new SpawnSelector module, MatchService round-sampling calls, and the original enabled origin SpawnLocation with its unchanged UniqueId. No publish was run.

## Owner Studio checklist

1. In the **same open Habulan Rush Edit place**, inspect `Workspace.Map.SpawnRegions` (12 invisible, noncolliding Parts), `Workspace.Map.PanyoSpawn`, `ServerScriptService.SpawnSelector`, and updated touched scripts. Confirm existing authored Workspace objects and the origin SpawnLocation remain. Save the place.
2. Run repeated 2-player and 8-player matches in Classic Tag, Agawan ng Panyo, and Lihim na Target. Record every player's starting position for match entry and each later round. Confirm no shared position and at least 20 studs of horizontal separation at each round assignment.
3. Check central plaza, paths, street, and outer connected walkable surfaces. Check water, roofs, enclosed interiors, narrow edges, slopes, and nearby obstacles. Report any invalid spawn with position and a screenshot.
4. Reset or die in each mode and confirm normal respawns use the origin SpawnLocation. In Secret Hunt, leave the arena or fall, then confirm recovery reaches safe ground without overlapping another player. In Panyo, confirm the cloth appears on central safe ground and returns there after an invalid drop.
5. Check map boundary behavior at the outer walking edges in Panyo and Hunt. Verify Classic tag, scores, Panyo steals, Hunt captures, and round transitions still work. Include one mobile and one gamepad pass.

Agents did not start play, execute Luau, or run Studio tests. Gameplay acceptance belongs to the project owner. The imported mesh and texture rights remain pending owner review before release; see the inventory and `ASSET_LOG.md`.
