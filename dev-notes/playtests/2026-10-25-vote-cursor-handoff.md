---
title: Match SET button and vote cursor handoff
type: playtest
status: owner-review
owner: project-owner
task: vote-cursor-match-set
updated: 2026-10-25
source: owner-reported locked cursor during ballots and unwanted match SET button
---

## Source and preservation

The match HUD's SET button was removed from `UIController`. The lobby settings shortcut remains H on keyboard and Select on gamepad. `CameraDirector` now sets a free, visible mouse cursor during mode and map voting, settings, and other non-action match phases. Countdown and live play still lock the cursor to the center. The opening showcase still uses its existing cursor behavior.

Before editing, read-only Studio comparison found `CameraDirector` equal to source. Studio's `UIController` had owner-added logic suppressing its old chip cluster and timer when a mode HUD is active. Both changes were kept in repository source. Exact pre-edit Studio copies are in `C:/Users/Acer/AppData/Local/Temp/hrush-vote-cursor-20261025`. Workspace ID `59d929f7-2e07-8af6-0ad8-4a4c00000002` and Map ID `1ca2e3c5-9bf4-2060-0aeb-452500001e69` were recorded before sync. The two-script `studio-vote-cursor.project.json` overlay is restricted to the main place and contains no Workspace mapping.

Syntax, standalone Luau compilation, and main, tutorial, and targeted Rojo builds passed. Notes and whitespace checks passed. The owner connected and synced the targeted overlay. Read-only follow-up confirmed both complete Studio script sources equal the repository, the place is in Edit mode, and Workspace and Map retain their recorded IDs. Workspace still had 755 root children. Agents did not run Studio Play, execute Luau, or publish.

## Owner manual check

1. Save the synced main Edit place after review.
2. From a third-person lobby, start a match. Move the desktop mouse freely and click a mode card, then a map card. Repeat after selecting first-person view in the lobby before queueing.
3. Confirm the cursor re-locks for the countdown and live round, and returns to the chosen lobby view after the match. Check the same flow after a repeat match.
4. Confirm no SET button appears in the in-match HUD. Press H to open and close settings during live play; on gamepad use Select. Check that the settings cursor is usable.
5. Check phone touch voting and gamepad card selection on both ballots. Confirm the owner-added mode HUD chips and timer still suppress the older UIController equivalents.

Studio gameplay and input behavior remain owner-only validation.
