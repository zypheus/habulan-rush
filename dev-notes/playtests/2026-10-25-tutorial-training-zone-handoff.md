---
title: Tutorial training zone handoff
type: playtest
status: owner-testing-pending
owner: project-owner
task: classic-tag-tutorial
updated: 2026-10-25
source: 2026-10-25 owner-approved Classic Tag training strip design
---

# Tutorial training zone handoff

The Classic Tag tutorial place now has a generated flat training strip. `scripts/build-tutorial-zone.ps1` deterministically emits `assets/TutorialTrainingZone.rbxmx` with 181 referents, and `tutorial.project.json` maps it in Workspace beside `TutorialScene`. The seven `TutorialScene` waypoint markers moved onto the strip with names, classes, and sizes unchanged, so `TutorialService` needed no edit. No Luau changed for that asset-only pass, no Studio execution, play, or publish was run by the agent.

On the same day the owner re-scoped the tutorial to run entirely in the main place, so the strip, scene, lesson module, and bootstrap are also mapped in `default.project.json` and the lobby Start button now admits players in place instead of teleporting.

## How it runs in the main place now

- `TutorialService.server.lua` is a thin bootstrap for the new `TutorialService.lua` module, following the `MovementAuthority` pattern.
- The module detects the main place by finding `MatchService` in `ServerScriptService`. It sends validation strictly through the existing gateway path and never writes match-owned global attributes at startup.
- Gateway Start, after the same rate limit, idle, and solo party checks, calls the module `Admit` and marks "later" only after admission succeeds.
- On admission the player is pivoted to the strip Start marker and gets lesson attributes (`HRushInMatch`, `HRushState`, `HRushRole`) that a 0.1-second heartbeat re-asserts against MatchService broadcast sweeps.
- Global round attributes are pinned to MS_04/ClassicTag only while at least one session runs, so movement request validation accepts lesson motion. Release happens when no session is active and no external write or non-lesson player exists (PlayerRemoving includes retry); otherwise MatchService keeps owning the timeline.
- Leave or Finish pivots the character back to `Workspace.Map.Spawn` in Kalsada and restores the lobby attributes.
- The standalone tutorial subplace (`tutorial.project.json`, place 90963168543860) keeps its reserved-teleport flow through the same module; that path is now optional and unchanged.

## Zone contents

- Founder strip: walls on four sides with gold caps, an arched entry with welcome board, and two plaza rule boards. Ground is split into khaki filler tiles so no void shows between pads.
- Lane 1 Move: blue MoveGoal disc, navy hurdle with a gold stripe, sign 1.
- Lane 2 Dash: gold dash gate (two columns plus a top beam) with dash disc and sign 2.
- Lane 3 Sprint: two cream slide rails, blue slide discs at both ends, navy arrows with gold chevrons, sign 3.
- Lane 4 Tag: cream tag court with a red band, rail ring, and sign 4. TagPathA and TagPathB stay 6 studs apart.
- Side lanes: roll tower with a TrussPart ladder, 13-stud roll platform with rails, and hard-landing pad; vault lane with a 3.5-stud crate, gold approach stripe, and gold chain arrows.
- Batch F props: `SwingBar` model (bar, posts, noncolliding GrabVolume, Pivot and ReleaseDirection attachments) tagged `SwingBar`; `Zipline` model (two towers, ladders, platforms, sloped cable with Start and End attachments, noncolliding GrabVolume) tagged `Zipline`.
- Dressing: three pole lights, three trees, two tire stacks. Sign text uses the Roblox built-in GothamBold family only.

Markers (all at ground level, Y 0.5): Start Z 5000, MoveGoal Z 5050, DashGoal Z 5078, SlideStart Z 5108, SlideEnd Z 5160, TagPathA X -3 Z 5186, TagPathB X 3 Z 5186.

Verification already passed in source: the XML parses, zero unanchored parts, tags decode to `SwingBar` and `Zipline`, 10 cylinders, 3 anchored TrussParts, 11 sign GUIs, the zipline cable CFrame, and the tutorial Rojo build contains the zone, both tags, and all seven markers.

## Owner checks

1. In the main place, sync the open Edit place from `rojo serve default.project.json` (or open the fresh generated build, which already passed). Confirm `Workspace.TutorialTrainingZone`, `Workspace.TutorialScene` with the seven markers, `ServerScriptService.TutorialService` plus its bootstrap, and `StarterPlayerScripts.TutorialHUD` arrive. The strip is at Z 5000 to 5200, far south of the Kalsada street.
2. Walk the strip from the arch: confirm the floor is continuous with no mirror seams or gaps, walls have no open corners, and the free path from Start to the tag court reads left to right: move, dash, sprint, tag.
3. Read all sign boards. Source text: 1 MOVE + JUMP, 2 DASH THROUGH THE GATE, 3 SLIDE x2 FOR SPRINT, 4 TAG THE RUNNER, ROLLOFF: HARD LANDING ROLL, VAULT: CHAIN 2 SLIDES FOR SPEED, SWING BAR, ZIPLINE, plus the welcome and plaza boards. Text should be readable from the walking direction (row boards face south, yard boards face north).
4. Confirm the four lane discs: MoveGoal and DashGoal diameters (10 and 20 studs) match the Config radii that the lesson currently requires, and the tag court band sits between TagPathA and TagPathB.
5. Jump under the SwingBar and confirm the grab volume sits in jump reach. Climb both zipline ladders and confirm the Start and End platforms clear the cable ends; the cable slopes from Stud 16 at the start to Stud 11 at the end with a soft landing pad below the 12-stud hard threshold.
6. Check the roll tower: ladder reaches the platform, rails block the sides, and the landing pad gives the roll setup room clear of the tag court.
7. Studio Play now works for the whole lesson because there is no teleport. Play the main place with at least one player, have a fresh account take Start on the prompt, and confirm each check: character pivots from Kalsada to the strip Start, beacon guides the Move lane, jump plus goal switches to Dash, dash through the gate switches to Sprint, two chained slides then a sprint switch to Tag, clicking the moving RUNNER prop finishes, and SaveState reads Saved (Failed in Studio is expected; DataStores are unavailable there). Leave pivots back to Kalsada spawn and the queue prompt is usable again.
8. Repeat check 7 with a second player standing in the lobby: confirm the second player stays in normal lobby state while the lesson runs, cannot queue the first player (queue guard), and no round starts for either. If a real match runs for other players during a lesson, report any client HUD flicker for the lesson player.
9. Confirm the dressing (trees, lampposts, tire stacks) does not intersect walls or walk paths and no prop floats.

## Open blockers

- Swing, zipline, roll, and vault interactions are static geometry only. MOVEMENT_AUDIT Batch F movement mechanics are not implemented yet; heights and grab volumes were placed for that spec.
- The zone asset and generator script are agent-authored and await owner review before release.
- The embedded global pin is best-effort by design: if another player starts a real round while a lesson runs, MatchService writes lead and the pin release skips to let that match own the timeline; a lesson player may then fail movement requests until the match ends. Report client HUD flicker and rejected dashes in that window with the round state.
- No Studio inspection, Play, or publish was run by the agent per AGENTS.md. Actual feel, sightlines, sign readability, and the embedded lesson flow remain owner checks.
