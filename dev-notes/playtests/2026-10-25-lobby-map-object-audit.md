---
title: Open-place lobby and map object audit
type: playtest
status: read-only-audit
owner: project-owner
task: lobby-free-roam
updated: 2026-10-25
source: owner screenshots and read-only main Edit place inspection
---

# Lobby and map object audit

The owner's first screenshot shows the detailed Kalsada match area. The second shows the separate simplified lobby island. Both are present in the same open main Edit place (`127422539599317`). This inspection did not execute Studio tests or change any instance.

## Objects found

- `Workspace.BarangayMaligayaLobby` is the simplified island in the second screenshot. It is a Model with 52 direct children and 583 descendants at roughly `(-1246, -231, 0)`. It contains island terrain, roads, a barangay hall, central plaza, entrance pier and shop models. The grass floor is anchored and collidable. No BaseScript was found under this model.
- `Workspace.BarangayMaligayaLobby.CentralPlaza.PlazaSpawn` is an enabled, neutral SpawnLocation at `(-1306.1, -232.17, 74)`.
- `Workspace.Map.Spawn` is another enabled, neutral SpawnLocation at `(0, 0.5, 0)`. The `Map` Model has four direct children and 16 descendants in this Edit place; the detailed Kalsada scenery visible in the first screenshot is spread across other Workspace objects. The separate lowercase `Workspace.lobby` Folder holds sign art and is not the simplified lobby island.

## Integration findings

1. Both spawn locations are eligible for ordinary character spawns. `MatchService.initPlayer` sets lobby state but does not set `Player.RespawnLocation` or move the character to `PlazaSpawn`. `returnToLobby` calls `LoadCharacter()` without setting a destination. Roblox chooses randomly among multiple eligible spawns, so initial lobby entry and post-match return can land in either scene. Match rounds separately use `SpawnSelector` to place participants in Kalsada.
2. `TutorialService` explicitly returns players to `Workspace.Map.Spawn` at the Kalsada origin, not to the simplified lobby island.
3. `BarangayMaligayaLobby` and `PlazaSpawn` are absent from `default.project.json` and repository assets. A fresh Rojo build from this repository therefore lacks the simplified lobby scene. `assets/Map.rbxmx` contains the Kalsada scene under its `Map` model, while the open Edit place has much of that scenery at Workspace root. Preserve the open place and avoid a broad replacement sync until the scene ownership and layout are reconciled.

## Next decision

The owner should choose which scene should serve as the playable lobby. If the simplified island is intended, capture it as a competition-safe source asset, then make lobby spawn and tutorial return target it deterministically while retaining Kalsada round spawns. If Kalsada is intended, disable or otherwise exclude the plaza spawn from ordinary respawning. No scene or script was changed in this audit.
