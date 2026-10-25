---
title: Match opening handoff
type: playtest
status: owner-testing-pending
owner: project-owner
task: match-opening
updated: 2026-10-25
source: 2026-10-25 owner-approved Habulan Rush Match Opening plan
---

# Match opening handoff

Source implements five two-second Kalsada landmark clips, a 3.5-second group avatar lineup and a 0.5-second first-person handoff, followed by the five-second countdown. This runs once per match before round one in Classic Tag, Agawan ng Panyo, and Lihim na Target. Bato Bato Pick finishes before the opening. First-round preparation lasts 19 seconds in both Studio and live servers. Later rounds keep five seconds live and the existing three seconds in Studio.

## Presentation and ownership

| Time from preparation start | Presentation |
|---|---|
| 0 to 2 seconds | Wide Kalsada move and BARANGAY KALSADA title |
| 2 to 4 seconds | Barangay Hall and approach |
| 4 to 6 seconds | Multipurpose court and playground |
| 6 to 8 seconds | Fountain area |
| 8 to 10 seconds | Street and parked-car area |
| 10 to 13.5 seconds | Static participant copies, a fitted camera push, mode name and actual participant count |
| 13.5 to 14 seconds | Fade through black, remove the copies, restore real characters and first-person view |
| 14 to 19 seconds | Existing role or objective splash and 5, 4, 3, 2, 1 |
| 19 seconds | GO text and sound once as the server starts live gameplay |

- MatchService publishes `HRushShowcaseEndsAt` and `HRushPhaseEndsAt` before MS_03 reaches clients. Clients never acknowledge or delay the server start. A late client joins the current point in the timeline.
- Config owns timing, FOV, fit margin, title reservation and Kalsada shot positions. The lineup floor is the broad LIGHTGREEN ground at approximately (-124.3, 2.06, 26.25), derived from source XML. Neither map nor real spawn positions changed for this item.
- MatchShowcase returns a camera pose to CameraDirector. It never writes the camera itself. The existing first-person yaw and configured FOV resume under the fade.
- Copies are ordered by UserId, use current replicated appearances, and contain no scripts, interactive objects, tags, gameplay attributes, nameplates or cosmetic effects. Roblox-reserved `RBX` appearance attributes remain because client scripts cannot remove them. Parts are anchored and cannot collide, touch or be queried. Inert Humanoids retain avatar clothing with their name displays disabled. No new animation or audio asset is required.
- Normal HUD, action buttons, world nametags and feedback are suppressed during the scene. TouchGui's previous enabled state and real-character transparency values are restored. Camera look resumes with the countdown. The avatar-fit calculation includes the title area and oversized accessories.
- Reduced motion holds each of the five map clips and the lineup on a fixed frame with the same deadlines. Secret Hunt assignments stay in their existing private HUD path and never enter the lineup.
- Missing appearances are skipped. If no copy is available, the map shot continues. Leavers' copies are removed; remaining gaps are retained to avoid moving the lineup mid-shot. Phase exit and lobby return clean up immediately. Respawn and late character parts do not restart the timeline.
- If the selected Classic Taya leaves during preparation, the existing server fallback chooses a present replacement before live gameplay. No remaining participant aborts the match through the existing path.

## Preserved Studio changes and targeted sync

At the owner's sync request, read-only inspection of the open main Edit place found that Config, MatchService and CameraDirector had Studio-only changes. All ten existing target scripts were backed up before modifying the source, together with Workspace and script metadata. Backup directory: `C:/Users/Acer/AppData/Local/Temp/hrush-match-showcase-presync-1792908256815`. It contains the Studio source snapshot, per-script source copies, repository copies for the three differing scripts, and comparison diffs.

- Preserved the five-map lowercase ballot, two-second map reveal, map-name normalization, alternate vote request form, all-mode map voting, existing emergency spawn fallbacks, disabled skill-debug flag, first-person default and explicit saved third-person preference handling. Repository tutorial settings and queue validation were retained.
- Seven existing client scripts matched the pre-showcase repository version exactly. Their only sync changes are the approved showcase integration.
- The new `studio-showcase.project.json` maps exactly 11 scripts, has `servePlaceIds = [127422539599317]` and preserves unknown instances at every mapped boundary. Workspace, map, terrain, lighting, remotes and unrelated scripts are excluded. It does not apply the repository's unrelated pending tutorial work.
- The showcase keeps the inspected five-map ballot. Votes without their own authored shot rig reuse the current Kalsada camera rig. No additional map or map-switching implementation is claimed.
- The owner connected and synced the overlay at `localhost:34874`. Read-only verification confirmed all 11 complete script sources match the preserved repository source. The ten existing script instances retain their original unique IDs, classes and non-source properties. Only MatchShowcase was added; no client/server scripts were removed or duplicated. The place remains in Edit mode.
- Workspace retains its original unique ID. Both the Map model and the lowercase map Part retain identical metadata. No original root object count decreased. During the comparison one additional `Workspace.Rig` appeared, so root children changed from 677 to 678 and descendants from 4,375 to 4,680; the overlay contains no Workspace mapping and that Rig was left untouched. Detailed comparisons are saved as `sync-verification-final.json` beside the source backup. No broad project sync, Studio execution, test or publish was performed.

## Validation

- Owner-reported first playtest found a map-only shot and no countdown. Read-only Studio Output showed `MatchShowcase.copyAvatar` crashing when removing protected `RBXRefinementScale`. The repair preserves reserved attributes, isolates each failed copy, restores `Archivable`, and drives entry/exit cleanup from the deadline even if camera rendering fails. Countdown digits now use only the five valid remaining seconds; GO is presented only on the server's MS_04 transition. Existing timing and map voting remain as before.
- The already verified post-sync source snapshot was copied to `pre-repair-sources` beside the original backup. The connected targeted Rojo server mirrored the two repaired scripts automatically. A fresh read-only comparison found all 11 overlay script sources equal to the repository, with the same Workspace unique ID and 678 root children. No Studio execution or publication was performed by the agent.
- `python scripts/check-showcase-recovery.py` passed using the actual copy and countdown functions with mocked protected attributes, copy failure, missing avatar, repeat entry/exit, partial cleanup, five ticks, one GO, and missing deadline. This is an offline logic check; it does not verify rendering or replication.
- The owner requested five distinct map clips and a longer opening. Before editing, the two affected Studio sources matched the repository exactly and were copied to `C:/Users/Acer/AppData/Local/Temp/hrush-five-clips-20261025-143735`; targeted Rojo was paused. The five shot paths use authored Map.rbxmx landmark positions. Offline checks cover all five two-second cuts, reduced motion and the empty-lineup hold. Visual framing remains owner testing.
- The owner reconnected the targeted Rojo server on localhost:34874 and synced the two changed scripts. Read-only Studio inspection then confirmed all 11 complete overlay script sources match the repository, with one MatchShowcase and one UIController. The same Workspace and Map instance IDs remain in the open Edit place. Workspace currently has 704 root children after other concurrent place work; this overlay has no Workspace or map path. Save this Edit place and test the new sequence there.

- Luau syntax check passed.
- Standalone Luau 0.744 compilation passed, including the touched large client scripts. This verifies bytecode generation as well as parsing.
- [Framing assertions](../../tests/MatchShowcase.spec.lua) passed outside Studio using the actual module and Config showcase values in a minimal service harness. All eight bounding-box corners stay on screen and above the title for one-player, eight-player and oversized bounds on desktop, landscape phone and portrait viewports, at both ends of the camera push. A zero-size initial viewport stays finite.
- Mock-clock assertions passed for first-round activation, the six-second boundary, later rounds, phase exit, lobby membership, missing timestamps, repeated matches and late clients. These checks do not simulate Roblox rendering, animation or replication.
- Notes check, main and tutorial Rojo builds, and showcase diff whitespace check passed. Both generated places contain the shared module once.
- Initial implementation used no Studio MCP or sync. The follow-up above used owner-requested read-only Studio inspection. No Studio test, Luau execution or publication was performed. Existing unrelated tutorial edits in the working tree were preserved.

## Owner manual checklist

1. Use the same main Edit place for review so its current scenery and owner additions are included. Run two clients through each mode. Confirm five distinct map views at 0, 2, 4, 6 and 8 seconds, the visible avatar lineup at 10 seconds, first person at 14 seconds, five countdown numbers with five ticks, and one GO cue when movement unlocks at 19 seconds. Confirm normal HUD and touch controls stay hidden during the scene and return afterward. Check Output for any `HRUSH_MatchShowcase` warning or render callback error.
2. Run eight clients. Review the broad Kalsada shot and lineup angle for terrain or building obstruction. Check all avatars, asymmetric accessories, feet on the ground, clothing, no duplicate real bodies and readable mode text on a small landscape phone. Repeat with large text, portrait, tablet and gamepad.
3. In Classic, confirm Bato Bato Pick finishes first. Confirm later rounds have no showcase and a second match plays a fresh opening. Solo practice in Panyo and Hunt should still show one avatar and the correct mode.
4. Respawn, remove a participant, and remove the selected Taya during preparation. Confirm no stale copy or camera lock remains, the replacement Taya is shown correctly, and existing practice/competitive mode rules still apply.
5. Join or load slowly during the opening and countdown. Confirm the client follows the remaining time instead of replaying six seconds or holding the server. Return to the lobby during a scene and check that `HRUSH_MatchShowcaseScene` and `HRUSH_MatchShowcase` are gone locally.
6. Check reduced motion, muted audio and first-person FOV settings at 50, 72 and 95. Confirm the scene uses fixed shots with reduced motion, muted sounds stay silent, the gameplay FOV returns, and two Hunt clients never see each other's target assignment in the opening.

Visual shot composition, device controls and multiplayer behavior remain unverified until the project owner completes this checklist.
