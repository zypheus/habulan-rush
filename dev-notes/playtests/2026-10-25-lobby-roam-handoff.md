---
title: Lobby free roam handoff
type: playtest
status: owner-testing-pending
owner: project-owner
task: lobby-free-roam
updated: 2026-10-25
source: 2026-10-25 owner-approved free-roaming lobby plan
---

# Lobby free roam handoff

The source now lets players walk and jump around the current Kalsada lobby while its menu stays visible. The lobby starts in third person at 10 studs and 70 degrees. Z, gamepad Y, and the touch VIEW button switch between first and third person. The first-person view uses the player's FOV setting. Gamepad DPad Down focuses Find Match from roaming; B releases menu focus. A choice lasts for the session and returns after a match. Matches remain first person, and dash, slide, roll, vault, skills and match actions remain live-round-only.

MusicController routes the lobby loop through the Music SoundGroup. The later match-only BGM change keeps the earlier ID in the lobby and uses a separate owner-supplied ID in match phases. Both audio assets remain Pending Review in ASSET_LOG.

## Sync and source checks

- Before editing, the open main Edit place's Config, LobbyUI, MovementController and MusicController each matched the repository. Workspace ID was `59d929f7-2e07-8af6-0ad8-4a4c00000002`, Map model ID was `1ca2e3c5-9bf4-2060-0aeb-452500001e69`, and Workspace had 725 root children after owner changes. The four scripts and old showcase overlay were copied to `C:/Users/Acer/AppData/Local/Temp/hrush-lobby-roam-20261025-183250`; the showcase Rojo process was paused before source edits.
- `studio-lobby-roam.project.json` targets the same main place and maps only the four affected scripts. It has no Workspace path and preserves unknown instances. The existing showcase overlay remains separate.
- Offline checks exercised the production lobby camera functions, FOV and respawn handling, phase gating, lobby BGM fallback, live-only ability gates, and reuse of the playing track. Syntax, compilation, notes, whitespace, and main/tutorial/targeted Rojo builds passed after the final source edit.
- The owner reconnected the place-restricted Rojo overlay on localhost:34874 and reported Connected and synced. Read-only comparison confirmed the complete Config, LobbyUI, MovementController, and MusicController Studio sources equal the repository. The place stayed in Edit mode; Workspace ID `59d929f7-2e07-8af6-0ad8-4a4c00000002`, Map model ID `1ca2e3c5-9bf4-2060-0aeb-452500001e69`, lowercase map Part ID `59d929f7-2e07-8af6-0ad8-4a4c000003e2`, and the 725 Workspace root children matched the pre-sync inspection. Place save and owner visual/gameplay testing remain pending.

## Owner checklist

1. Save the same open main Edit place after targeted sync. Start in lobby on desktop, walk and jump around Kalsada, rotate the third-person camera, press Z twice, and confirm first-person FOV and 10-stud third-person framing. Check the avatar and camera after a respawn.
2. On phone, use the joystick and jump control while the lobby menu remains visible. Tap VIEW in portrait and landscape. Check that the button stays clear of the joystick, menu, and safe-area insets.
3. On gamepad, move with the left stick and look with the right stick. Use Y to switch views, DPad Down to focus Find Match, and B to return to roaming. Check Find Match, cancel, party, settings, and tutorial menu access.
4. Try dash, slide, roll, vault, skills and tag in the lobby; none should activate. Queue and cancel, then confirm movement locks during the showcase countdown and controls release together at GO. Match camera must remain first person. Return to lobby and confirm the previously selected lobby view and controls recover.
5. With music enabled, listen in the lobby, while searching, through match entry, and on return. The lobby loop should change to the match track at voting, then return to the lobby loop after the match. Set Music and Master volume to zero, then raise them, and confirm both tracks follow the settings.

Studio execution and device acceptance belong to the project owner. Agents have not run Studio gameplay tests or published the place.
