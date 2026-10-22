---
title: Agawan ng Panyo full-mode handoff
type: playtest
status: pending-owner-validation
owner: project-owner
task: agawan-ng-panyo-all-phases
updated: 2026-10-23
source: owner approval to implement all phases on 2026-10-23
---

# Agawan ng Panyo full-mode handoff

## Built in source

- Mode vote offers Classic Tag and Agawan ng Panyo. Ties default to Classic.
- Panyo uses the playable Kalsada greybox. It skips map vote and MS_RPS, keeps all players on the Runner movement profile, and runs three 120-second rounds. Solo play runs one practice round without match points or an MVP.
- The server owns one panyo, a 0.4-second continuous proximity pickup, tag-validated steals, 1-second new Carrier protection, a 2-second previous Carrier block, possession time, and death, reset, disconnect, or arena-exit recovery.
- Hold points are whole seconds of valid possession. Round rank uses hold time, then steals. Existing match points reward ranked players with positive hold time. Match MVP uses total hold time, then steals, then match points. Exact ties share rank. Zero-possession players receive no round points or MVP.
- Simula, Barangay Rush, and Huling Habol are server-timed. Short reveals and final-second notices are client presentation only.
- The Panyo HUD shows the timer, Carrier, personal time, steals, and live leaderboard. A local overhead marker and persistent Highlight track the Carrier.
- The owner-approved follow-up refreshes the mobile STEAL button every 0.1 seconds if Roblox recreates or hides the touch control. One local gold Carrier Highlight and waist trail follow possession; timed reveals strengthen the Highlight and show it through walls. The trail turns off at VFX 0, while the outline stays visible. A local Carrier in first person keeps the HUD but hides their own world effects.
- Five original WAV cues are in `assets/sfx/panyo/`. `Config.Panyo.Sounds` has blank IDs until the project owner uploads and approves them. Panyo-specific audio is silent meanwhile.

## Source validation

- `scripts/check-syntax.ps1`: passed.
- `scripts/check-notes.ps1`: passed.
- `git diff --check`: passed.
- Rojo 7.7.1 build to `HabulanRush.rbxlx`: passed.
- No Roblox Studio execution or gameplay test was run by the agent.
- After the Phase 3 invalid-round total fix, syntax, notes, `git diff --check`, and the Rojo build passed again.
- Mobile STEAL and Carrier visual follow-up: syntax, notes, `git diff --check`, and Rojo build passed. No agent Studio gameplay or visual test was run.

## Phase 3 source review

- The scoring path previously added hold time and steals from a competitive round after the roster fell below two players, even though that round awarded zero match points. Source review reproduced the path: complete one valid round, leave one player during the next round, then reach the final MVP calculation. The totals now include only valid rounds. This is a source-level fix; Studio confirmation remains pending.

## Owner Studio matrix

**Mobile steal and Carrier feedback follow-up:** With two mobile clients, repeat A to B to A possession changes. STEAL should reappear after each loss. Try an early return attempt, then a valid tag after 2 seconds. The new Carrier should have exactly one gold outline and trail, and the former Carrier none. Check the stronger 2-second reveal, third-person self view, first-person self HUD without world effects, VFX 0 and 100, drop/respawn/round-end cleanup, PC click, R2, and one Classic match.

1. **Solo practice:** Queue alone, select Panyo, check the Kalsada spawn, visible neutral cloth, countdown, 0.4-second pickup, one 120-second round, possession count, no competitive points, and lobby return without MVP.
2. **Two players:** Check simultaneous arrival at the cloth, both PC and R2 or mobile STEAL, front/side/rear and wall rejection, 1-second new Carrier safety, 2-second return block, and a valid steal that immediately changes the visual and scores. Confirm the previous Carrier's time stops and the new Carrier's time starts once.
3. **Recovery:** Reset, die, disconnect, leave the arena, and return after respawn. Verify exactly one panyo appears at safe ground, old score is retained, the dropped player's pickup block works, and the round continues. Repeat during and after the final seconds.
4. **Four players:** Check fair pickup selection, live leaderboard ordering, round ranks including ties and zero-hold players, all three recaps, match MVP, periodic reveals, and final cues. Leave one player mid-round and confirm no stale Carrier or duplicate points. In a later round, reduce the roster below two players and confirm that invalid round's hold time and steals do not change the final MVP totals.
5. **Eight players:** Watch replication and visual clarity, overhead marker distance, reveal lifetime, rapid alternating steals, scoring at the round deadline, and recap rows. Check performance on a lower-end device.
6. **Classic regression:** Select Classic and verify map vote, MS_RPS, normal Taya roles, tag safe window, three 150-second rounds, original recap, and MVP.
7. **Devices and camera:** Test Panyo HUD and STEAL input on PC, gamepad, and mobile in third and first person. Check first-person local panyo visibility, marker visibility to others, responsive UI, VFX setting at 0 and 100, and no overlap with movement controls.
8. **Abuse checks:** Spam RequestTag and SkillService remotes, attempt false roles, target claims, wall tags, out-of-range tags, duplicate pickup, out-of-bounds movement, and reset cycling. Check that the server remains authoritative and score never duplicates.
9. **Audio:** Upload the five WAV files through the project account, confirm each asset is competition-safe and accessible to the place, enter its ID in `Config.Panyo.Sounds`, rebuild, then listen for pickup, steal, drop, reveal, and final cues at different SFX volume settings.

## Known limits

- Kalsada is the only Panyo map because Binaha has no playable authored geometry. Classic map vote remains as before.
- Panyo-specific runtime sound IDs are blank until owner upload. Source includes cue files and playback hooks.
- Source parse and Rojo packaging do not prove runtime Luau compilation or multiplayer behavior. The owner matrix is required before release.
