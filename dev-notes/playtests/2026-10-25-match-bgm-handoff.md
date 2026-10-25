---
title: Match-only BGM replacement handoff
type: playtest
status: owner-testing-pending
owner: project-owner
task: match-bgm-replacement
updated: 2026-10-25
source: owner-supplied audio ID 106317705738449
---

# Match-only BGM replacement

The lobby (`MS_01`) keeps `rbxassetid://94984747143473`. Voting, RPS, countdown, live rounds and results use the owner-supplied `rbxassetid://106317705738449` through the existing MusicController and Music SoundGroup. The Music and Master sliders and mute setting still apply. No audio file was imported or changed by this item; the separately present `assets/sfx/ingamebgmusic.MP3` was left untouched because its relationship to the supplied asset ID has not been verified.

The new ID and the earlier lobby ID are recorded in `ASSET_LOG.md` as Pending Review until access and competition-safe provenance are confirmed.

## Sync and validation

- Before editing, the complete Config and MusicController sources in the open main Edit place matched the repository. Both were backed up to `C:/Users/Acer/AppData/Local/Temp/hrush-match-bgm-20261025-195524`; the previous spawn-routing Rojo process was paused. Workspace, Kalsada Map and lobby island IDs were inspected.
- `studio-match-bgm.project.json` is restricted to the same main place and maps only Config and MusicController, with no Workspace path.
- The offline music check confirms the lobby ID stays old and all match phases resolve to the new ID. Syntax, Luau compilation, notes, diff whitespace and main/tutorial/targeted Rojo builds passed.
- The owner reconnected the place-restricted Rojo server on localhost:34874 and reported Connected and synced. Read-only comparison confirmed the complete Studio Config and MusicController sources equal the repository. The place remained in Edit mode, with unchanged Workspace ID `59d929f7-2e07-8af6-0ad8-4a4c00000002`, Kalsada Map ID `1ca2e3c5-9bf4-2060-0aeb-452500001e69`, lobby island ID `3c333ee6-bc58-bd90-0aef-333d00001e1b`, both spawn IDs, and 719 Workspace root children. Owner save and Studio audio review remain pending.

## Owner checklist

1. Save the same open main Edit place after the targeted sync. Join the lobby and confirm only the earlier loop plays there and while searching.
2. Start a match. Confirm the new ID plays from voting through RPS, countdown, live play and results in all three modes; return to lobby and confirm the earlier loop resumes.
3. Check repeat matches, Music and Master volume sliders, mute, and that countdown or gameplay sounds are still audible at their selected levels.

Studio playback, asset access, licensing and publication remain with the project owner.

## Playback repair after owner report

The owner heard lobby music but no match music and saw no audio error in Output. `MusicController` now starts each changed ID on a fresh Sound after it loads. The old Sound fades out, so a lobby Sound cannot interfere with the match Sound. A pending load is discarded if the state changes. If audio `106317705738449` is still unloaded after ten seconds, Output reports `[MusicController] Music did not load` with the ID and an experience-permission hint.

The offline check exercises same-track reuse, lobby-to-match replacement, late loading, cancellation and the load warning. Syntax, Luau compilation, notes and main/tutorial/targeted Rojo builds pass. The existing targeted Rojo server remained connected to the open Studio process during this source edit; complete Studio source equality, audible playback and place save await owner confirmation. The server overlay still maps only Config and MusicController, with no Workspace path. No Studio gameplay test was run by an agent.

The owner retested and Studio Output reported `User is not authorized to access Asset` for `106317705738449`, followed by `The experience doesn't have access permission to use asset id 106317705738449. Click to share access`. The new `[MusicController] Music did not load` warning then appeared. This confirms an experience asset-permission blocker. The separate `203785492` asset-type error is unrelated to the match BGM.

Permission resolution: Studio Output's share-access line grants this experience access to `106317705738449`. The equivalent Creator Dashboard path is Development Items > Audio > this asset > Permissions > Experiences, then add this experience's universe ID. [Roblox's asset-permission guide](https://create.roblox.com/docs/projects/assets/privacy) describes this flow.

The owner then granted experience access through Studio and confirmed that match music plays. The playback blocker is resolved. A full state-by-state, volume, mute and repeat-match audio pass remains on the checklist above; place save and full Studio script-source comparison have not been confirmed. Asset licensing remains Pending Review in `ASSET_LOG.md`.
