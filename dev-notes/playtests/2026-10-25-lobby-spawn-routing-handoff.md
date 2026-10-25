---
title: Lobby island and Kalsada spawn routing handoff
type: playtest
status: owner-testing-pending
owner: project-owner
task: lobby-spawn-routing
updated: 2026-10-25
source: owner-approved lobby island spawn routing plan
---

# Lobby island and Kalsada spawn routing

The server now assigns `Player.RespawnLocation` to `Workspace.BarangayMaligayaLobby.CentralPlaza.PlazaSpawn` on join and before a post-match character reload. Players remain on that island through queueing and mode/map voting. After the map vote, match participants switch to `Workspace.Map.Spawn` for ordinary respawns; existing `SpawnSelector` positions still place them for the round and showcase. The repository's embedded tutorial path now returns an existing character to the island and restores its lobby respawn destination. A missing or disabled island spawn falls back to the Kalsada spawn with one tagged warning.

The owner chose to keep the island model only in the open main Edit place. `default.project.json` does not map the island. A fresh repository build therefore uses the Kalsada fallback until the island is exported and added to source. The currently open main place has the older separate-place tutorial gateway and no embedded `TutorialService`; the targeted sync preserves that setup. Returning from the separate tutorial place enters the main place through its join route and should use the island.

## Sync and source checks

- Before editing, complete Studio Config and MatchService sources matched the repository. The island model, island spawn, Kalsada Map model and Map spawn were inspected in Edit mode. Studio had no embedded TutorialService. Matching scripts, the repository TutorialService and the old overlay were backed up to `C:/Users/Acer/AppData/Local/Temp/hrush-spawn-routing-20261025-193636`; the previous Rojo process was paused.
- `studio-spawn-routing.project.json` targets only main place `127422539599317`, maps Config, MatchService and the new SpawnRouting module, ignores unknown instances, and has no Workspace path.
- Offline source checks cover join correction, voting, match entry, ordinary match respawns, lobby return, embedded tutorial return, and missing/disabled island fallback. Syntax, compilation, notes, diff whitespace and main/tutorial/targeted Rojo builds passed.
- The owner reconnected the place-restricted Rojo server on localhost:34874 and reported Connected and synced. Read-only comparison confirmed complete Studio Config, MatchService and SpawnRouting sources equal the repository. The place stayed in Edit mode. Workspace ID `59d929f7-2e07-8af6-0ad8-4a4c00000002`, Kalsada Map ID `1ca2e3c5-9bf4-2060-0aeb-452500001e69`, island ID `3c333ee6-bc58-bd90-0aef-333d00001e1b`, and both spawn IDs are unchanged. Workspace retained 722 root children and the island retained 583 descendants. Owner place save and Studio gameplay review remain pending.

## Owner checklist

1. Save the open main Edit place after the targeted sync. Start solo and with two players. New players should appear at the plaza on the simplified island and freely walk and jump there.
2. Die or reset in the lobby, then queue, cancel, and vote. Respawns during lobby and voting should stay on the island. Confirm the menu and view switch still work.
3. After voting, check each player moves to a distinct Kalsada round spawn. Check the showcase, countdown lock, GO, and a death/reset during live play: respawn must be on Kalsada, never the island.
4. Finish or abort a match and verify every returning player respawns on the island. Repeat a second match. Check all three modes.
5. Return from the separate tutorial place and verify the player arrives on the island. In a future full source build, verify the embedded tutorial exit also returns there.

Agents did not run Studio gameplay tests or publish the place.
