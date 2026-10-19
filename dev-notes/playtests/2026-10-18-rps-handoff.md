---
title: MS_RPS Studio handoff
type: playtest
status: pending
owner: project-owner
task: rps-first-taya
updated: 2026-10-18
source: src/ServerScriptService/MatchService.server.lua
---

# MS_RPS Studio handoff

Repository implementation is ready for owner review. The owner subsequently requested a Rojo build, and `HabulanRush.rbxlx` built successfully. No publish or Studio gameplay run was performed. Open the rebuilt place before testing. The two sound IDs in `Config.Match.Rps` are empty placeholders, so reveal and result are silent until approved assets are supplied.

## Manual cases

1. **One player:** Queue solo and let search time out. After map vote, confirm MS_RPS is skipped, MS_03 begins, and the solo player is Taya. Repeat the next round; there must be no RPS screen or stuck input.
2. **Two players:** In round one choose Rock against Scissors. Both cards show `?` until reveal, then both signs appear together. Rock moves to SAFE and Scissors becomes starting Taya. In round two the remaining eligible player should become Taya without MS_RPS. In another match, choose identical signs for five stages and confirm ties replay, then SUDDEN PICK selects exactly one Taya.
3. **Eight players:** Confirm eight cards fit on PC, a mobile safe area, and gamepad. Use two signs so winners move to the SAFE row and only losers pick again. Use all three signs in one stage and confirm a tie. Leave one player AFK to check the server reveals a random sign. Disconnect an active picker during a stage and check the remaining pool resolves or the shuffle bag fallback is used when the stage pool empties. Complete three rounds and confirm no player starts as Taya twice until the eligible pool refills.
4. **Input and authority:** Use 1/2/3, click, touch, D-pad left/up/right, and X/Y/B. During pick, submit Rock and immediately send Paper through `RpsSubmitSign`; reveal must still show Rock. Submit before the pick opens and after the deadline; neither should affect the reveal. A SAFE spectator must see no usable buttons. Confirm the RPS screen and input action disappear at MS_03 and after leaving the match.

Paste the assertions from `tests/RpsRules.spec.lua` into a Studio command bar after syncing `RpsRules` to check one-sign tie, three-sign tie, and a two-sign win. Record the 2-player, gamepad, and mobile results before pushing the gameplay change.
