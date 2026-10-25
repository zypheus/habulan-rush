---
title: Classic Tag tutorial handoff
type: playtest
status: owner-testing-pending
owner: project-owner
task: classic-tag-tutorial
updated: 2026-10-25
source: 2026-10-25 owner-approved Classic Tag tutorial plan
---

# Classic Tag tutorial handoff

Repository source now contains a separate `tutorial.project.json` that maps the tutorial-only anchored Kalsada copy, Terrain, `TutorialScene` markers, live movement and first-person camera modules, and tutorial-only lesson code. The main place has a first-join Start/Later prompt and a Learn to Play lobby button. No Studio test or publish was run by the agent.

The Rojo builds are local files. They do not publish either place automatically. The currently open main Studio Edit place has the tutorial entry code and the updated gateway explanation for Studio teleport attempts, but still needs an owner save and behavior check.

The owner reported the button missing in the currently open place and Find Match cancellation failing. Source now keeps the Find Match button active during search, makes a second press send Cancel on desktop, phone, and gamepad, and places Learn to Play inside the desktop action group's bounds. In the open Edit place, Rojo created a second `LobbyUI` and `Remotes` instead of adopting the older objects. The older `LobbyUI` was temporarily made to return before making its menu, while the synced client owned the visible menu. Canonical `TutorialProgress` and `TutorialGateway` were mirrored into `ServerScriptService`, and the original `MatchService` received the queue guard. The later owner-requested cleanup removed the temporary duplicates. No Studio play or gameplay test was run by the agent.

At the owner's explicit request, the stale `LobbyUI`, old `MomentumHUD`, and extra Rojo-created `Remotes` folder were removed from the open main Edit place. `TutorialEvent` was added to the surviving `Remotes` folder containing `QueueEvent`. Read-only inspection confirmed one active copy of each. The tutorial subplace initially opened as a blank baseplate. The owner connected it to the place-restricted Rojo server on localhost:34872; read-only Studio inspection then confirmed Kalsada, all seven named waypoints, lesson scripts, and `TutorialEvent`. The blank-template root `Baseplate` and `SpawnLocation` were later confirmed absent. Neither place has been published with these changes. Live-client behavior remains unverified by the agent.

After the owner reported that map parts were falling, source inspection found 280 unanchored BaseParts among 2,273 Kalsada BaseParts. `assets/TutorialMap.rbxmx` is a tutorial-only copy with those 280 parts anchored; `assets/Map.rbxmx` remains unchanged for the main place. The tutorial Rojo project now maps the anchored copy. The open Tutorial Edit place was corrected directly and inspection confirmed zero unanchored BaseParts among its 2,274 current map BaseParts. The Edit copy has one additional already-anchored part relative to the source asset; its origin is unverified. Owner visual/play checks remain pending.

## Publish setup

1. Roblox's public place lookup resolved tutorial Place ID `90963168543860` and main Place ID `127422539599317` to the same universe `10769817230`. The owner prefers the existing Studio places. The Tutorial Edit window now has anchored Kalsada scenery and no root blank-template `Baseplate` or `SpawnLocation`; `Workspace.Map.Baseplate`, `Workspace.Map.Spawn`, Kalsada, and `TutorialScene` remain. Use File > Publish to Roblox in that window.
2. `Config.Tutorial.PlaceId` in `src/ReplicatedStorage/Config.lua` is now `90963168543860`. The main Edit window has already been cleaned: one new `LobbyUI`, one new `MomentumHUD`, and one `Remotes` folder with both `QueueEvent` and `TutorialEvent` remain. Publish the main place from that window. The generated builds remain a fallback if the Studio copies cannot be published.
3. Ensure both places use the same experience and `Config.Tutorial.MainPlaceId` still points to the main lobby place (`127422539599317`). A future map replaces `assets/TutorialMap.rbxmx`, `assets/Terrain.rbxmx`, and `assets/TutorialScene.rbxmx` in the tutorial project, keeping marker names `Start`, `MoveGoal`, `DashGoal`, `SlideStart`, `SlideEnd`, `TagPathA`, and `TagPathB`.

## Owner checks

- In the currently open Studio place, save Edit changes and check that the lobby shows Learn to Play and a second Find Match press cancels search before match entry.
- Studio Play cannot open the tutorial through TeleportService. The gateway now explains this instead of showing the generic teleport error. A real round trip requires the Roblox app after publishing both places. Published-server teleport failures log the engine error or `TeleportInitFailed` result under `[TutorialGateway]`.
- In a **published Roblox client**, join as a new account. Confirm Start and Later, Later persistence on rejoin, and lobby replay. TeleportService round trips cannot be validated in Studio play mode.
- Check that Start is rejected during queue, match, and multiplayer party states. Confirm a failed teleport leaves the player in the lobby and shows an error.
- Complete move plus jump, accepted dash to the gate, two accepted slides and earned sprint, then tag the moving practice Runner. Confirm one instruction at a time, no timeout, device-specific retry hints, and no match points or competitive bots.
- Confirm the tutorial Kalsada scenery stays in place during Play, especially door frames, lights, signs, and decorative meshes that were previously unanchored. Check that no intended moving prop was frozen by the tutorial-only anchoring.
- Check PC mouse/keyboard, phone touch, and gamepad inputs and UI focus. Confirm first-person camera and live movement feel, respawn during each step, L/Y or touch Leave during a step, free cursor on finish, replay after completion, and return to lobby.
- Check completion on a later join. Simulate an unavailable DataStore if possible: failed save should offer Retry Save or return with completion unconfirmed. Return stays blocked while a save is in progress.
- Run a normal two-player Classic match in the main place to verify the tutorial gateway and new lobby button did not affect queue, movement, or tagging.

## Open blockers

- The project owner supplied tutorial Place ID `90963168543860`; its same-universe membership is verified. Neither place has been published with the tutorial builds. Published content and the live round trip remain unverified. Source-only builds cannot publish the places.
- No Studio, published-client, mobile, or gamepad validation has been run by the agent. The reused Kalsada asset rights review remains pending before release.
