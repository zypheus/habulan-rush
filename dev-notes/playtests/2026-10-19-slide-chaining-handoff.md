---
title: slide chaining handoff
type: playtest
date: 2026-10-19
status: pending
owner: project-owner
task: slide-chaining
updated: 2026-10-19
source: owner-pasted slide chaining task
---

# Slide chaining handoff

## Source change and evidence

The owner saw the missing gain and text in the generated `HabulanRush.rbxlx` place. That place contains the momentum scripts, but it predates this source fix. The source client entered Slide and predicted a gain for any moving character. The server rejected a Runner unless its ledger already said Sprint and rejected slides below the old movement speed threshold. `MomentumHUD` shows action text, chain, and gain sound only for confirmed server action snapshots, so a rejected slide produced none. The earlier removal of `SlideSpeedMult` and `RollSpeedBonus` did not remove the gain call, HUD, or remote.

The server now accepts a valid moving grounded slide from Walk or Sprint. `MomentumRules.slideEligible` gates momentum at 80% of role sprint speed on both sides. The client sends its pre-burst eligibility as a veto, and the server independently checks observed horizontal speed. The server sends a correction with no action when a slow slide receives no gain, so it cannot make a popup or advance the chain. The server still owns the actual gain, diminishing count, and value. It sends accepted action snapshots to the owner only.

`SlideCooldown` begins at entry and is now 1.25 seconds. `SlideDuration` remains 1.0 second; `isSliding` and the entry cooldown prevent overlapping slide animations. `ChainWindow` is 2.5 seconds. `DiminishWindow` remains 2.0 seconds and repeats use 1.0, 0.6, then 0.3 of the slide gain. `Config.Movement.SlideMinSpeedPct = 0.85` remains as a dormant legacy value; only `Config.Momentum.SlideMinSpeedPct = 0.8` controls gain eligibility.

The `Config.Momentum.Debug` flag defaults false. Enable it temporarily to inspect `[Momentum]` logs for client slide detection, server slide detection, gain award, popup request, popup visibility, and chain count. Restore false afterward.

## Studio checklist for the newly built place

1. Run `tests/MomentumRules.spec.lua` in a Studio Command Bar. Confirm the boundary, diminishing, chain, reconciliation, and duplicate-popup assertions pass. Run `tests/MomentumClient.spec.lua` in a Runner client Command Bar. Check Output for runtime compile errors.
2. Start a live round with at least two players. Sprint to full speed, then slide. Confirm exactly one `SLIDE +1.5` popup, a bar increase and `Sfx_GainTick` for the owning player, and a server log of one gain if Debug is enabled. The other player should see only the `MomentumTier` attribute.
3. Press slide while standing still. The current input gate should leave the character standing and produce no gain or text. Move slowly below 80% of sprint speed, then slide. The slide animation and hitbox should work, with no gain, popup, chain increment, or gain tick.
4. Slide at speed, then land a roll inside 2.5 seconds. Confirm `x2 CHAIN` and one popup per confirmed action. Repeat slide to slide at about 1.25 seconds; the second slide animation must not overlap the first, and accepted gains should diminish to 0.9 then 0.45 before cap and decay.
5. Spam the slide input during the one-second animation and the remaining 0.25-second cooldown. Confirm one slide and one award. After cooldown, another slide can start. Slow slides must not consume a gain count or advance the chain.
6. In the lobby, turn Show Popups off, then enter a round and slide at full speed. The bar and gain sound should still work, but no action text should appear. Repeat with Show Popups on and Reduce Motion on: slide text and chain should still appear; only the camera motion changes. The Momentum Bar toggle controls the bar and chain label independently of action popup visibility.
7. Repeat slide input and HUD checks with gamepad and mobile controls. Confirm the existing binding, animation, and popup position; inspect portrait and landscape touch layouts.

## Validation and blockers

Source syntax passed. After the source handoff, the owner requested a local Rojo build; `HabulanRush.rbxlx` built successfully at 708545 bytes. The updated pure Studio assertions were parsed but have not been executed. No new two-player Studio, mobile, gamepad, sound, or visual result exists for this change. The place has not been published. Do not push gameplay changes until the repository's two-player validation requirement is met.
