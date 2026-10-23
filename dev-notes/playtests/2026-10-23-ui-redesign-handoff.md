---
title: UI redesign source handoff
type: playtest
status: pending-owner-validation
owner: project-owner
task: ui-redesign-all-phases
updated: 2026-10-23
source: owner-approved Habulan Rush UI/UX audit and redesign proposal
---

# UI redesign source handoff

## Implemented in repository source

- Shared `Config.UI.Theme` palette, safe-area layers, focus styling, responsive breakpoints, text size and high contrast preferences, and a measured touch-action dock. Existing input and server gameplay remain authoritative.
- Lobby cards explain all three playable modes and state that the server ballot chooses the match. FIND MATCH and CANCEL SEARCH are separate actions. Fake balances and shop entry points are absent from the primary lobby. Profile uses actual Roblox identity; Help describes current controls.
- Mode and Classic map ballots have desktop cards and phone carousels with vote, focus, winner, and timer states. Classic RPS uses a compact eight-player grid and large sign actions on phones.
- One match timer stays top center in all three modes. Classic role and Taya time, Panyo carrier and hold, and Hunt private target move to top-left cards. Live standings occupy the top right on desktop and the gap between the objective and touch dock on compact screens. Retired MS_02 draft presentation is hidden.
- Results use scrollable rows and compact phone layouts. Practice and no-MVP wording follows the server recap. Settings reflow to the safe area and expose Text Size and High Contrast.
- One local nametag per visible other player replaces Panyo's separate carrier label. The server suppresses built-in Humanoid names. Hunt target badges use only the existing private assignment event; target IDs are not published as attributes. Panyo's highlight and trail remain.
- No new remote, sound, image, or gameplay value was introduced. No asset log change is needed.

## Source validation

- `scripts/check-syntax.ps1`: passed.
- `scripts/check-notes.ps1`: passed.
- `git diff --check`: passed on approved source and notes.
- Rojo 7.7.1 rebuilt `HabulanRush.rbxlx` from `default.project.json`.
- No agent Studio playtest, device simulation, or rendered screenshot review was run. Phase 0 desktop and phone screenshots remain an owner acceptance item.

## Owner Studio acceptance

1. Open the fresh `HabulanRush.rbxlx`. Capture the lobby, mode ballot, Classic map ballot, RPS, countdown, each live HUD, settings, round recap, and final results at 1920x1080 and an entry phone around 667x375. Check 1366x768, a wider notched phone, 1024x768 tablet, and TV/gamepad where available.
2. Confirm FIND MATCH and separate CANCEL SEARCH work; all three lobby mode cards describe the real ballot; no fake balance or usable shop action appears. Open Help, Profile, and Settings repeatedly. Confirm one modal/focus owner and no duplicate listeners.
3. Vote Classic, Panyo, and Hunt with mouse, touch, and gamepad. In Classic, vote a server-offered map and complete RPS; confirm hidden choices until reveal, focus and Back behavior, and no leftover vote or RPS screen in MS_03/MS_04.
4. Use 1, 2, 4, and 8 clients across the three modes. Check top-center timer, top-left objective, standings, safe-area edges, thumbstick/jump clearance, action labels, respawn notice, first/third person, and VFX 0/100. Check the touch dock after button recreation and mode transitions. Verify the existing TAG, STEAL, and CAPTURE gates still work.
5. With two or more players, inspect nameplates at 0-70 studs, through walls, long DisplayNames, death/respawn, disconnect, and eight-player overlap. Check one Panyo carrier badge plus highlight/trail, no former-carrier badge, and a Hunt TARGET badge visible only to the assigned Hunter.
6. Complete Classic, Panyo, and Hunt practice and competitive recaps. Check scroll, own row, ties, no-capture/no-MVP, countdown, settings during live play, Text Size 80/100/130, High Contrast, and reduced motion. Reopen screens rapidly and confirm focus leaves gameplay clear.

Record a failure with screen size/device, client count, state/mode, exact steps, expected and observed bounds or behavior, and a screenshot. Repository fixes should follow only reproducible findings.
