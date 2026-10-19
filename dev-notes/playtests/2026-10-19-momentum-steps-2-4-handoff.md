---
title: momentum steps 2 to 4 handoff
type: playtest
date: 2026-10-19
status: pending
owner: project-owner
task: momentum-steps-2-4
updated: 2026-10-19
source: owner-pasted momentum steps 2 to 4 task
---

# Momentum steps 2 to 4 handoff

Follow-up: the owner-reported slide gain and text bug, shorter cooldown, longer chain window, and 80% gain threshold are covered by the [slide chaining handoff](2026-10-19-slide-chaining-handoff.md). The owner subsequently requested a local build, which passed. The 3-second cooldown notes below describe the earlier version.

## Source change

Step 2 predicts slide and roll gains with the same `MomentumRules` module used by the server. The server still validates each action and sends the final value only to its owner. A rejected slide or roll immediately sends a correcting snapshot. `RollIntent` is sent when the existing slide/roll button is pressed in air. The server validates its timestamp and airborne state, then compares server receipt times for intent and roll request within `PerfectRollWindow`. It waits for its own grounded observation before awarding anything. The old one-off speed boosts are gone. Client and server compose role speed, ex-Taya and landing modifiers, and momentum through `MomentumRules.speed`, with the 30 studs/s ordinary movement ceiling. Scripted dash travel retains its existing exception.

Step 3 adds one local HUD with a bottom-center bar, tier flash, MAX glow, four falling crack frames, three pooled action popup labels, merged gains, chain text, and loss text. Confirmed server gains drive the popup amount, chain, and sounds. Sound IDs are converted to `rbxassetid://` only when nonempty and numeric. The existing settings model stores the three new booleans for this session, the same lifetime as its other settings. The settings panel is currently hidden during matches by the pre-existing lobby GUI gate; set these toggles in the lobby before the round.

Step 4 adds tier FOV and a confirmed perfect-roll kick to the existing camera writer. `reducedCamera` (shown as Reduce Motion) disables both. The server sets `MomentumTier` on each character at spawn and only when its tier changes. No remote value is sent to observers and no observer effect is drawn.

## Config update and tuning

| Change | Keys | Meaning and tuning |
|---|---|---|
| Removed | `Config.Movement.SlideSpeedMult`, `Config.Movement.RollSpeedBonus` | Old one-off boosts. Momentum gain and decay now govern extra speed; these keys have no replacement multiplier. |
| Added | `Config.Momentum.Fx.BarWidth`, `BarHeight`, `BarBottom` | Bar dimensions and bottom offset in pixels. Adjust `BarBottom` only after mobile HUD overlap review. |
| Added | `Config.Momentum.Fx.TierFlashTime`, `CrackTime`, `PopupRisePx`, `PopupTime`, `LostTime`, `ChainPopTime` | Cosmetic flash, crack, popup travel/lifetime, loss text, and chain bounce timing. |
| Added later | `Config.Momentum.Fx.RollPopupTime` | Total normal and perfect roll popup visibility. Set to 3 seconds; the existing 0.6-second rise and fade follows a 2.4-second hold. Slide popups remain 0.6 seconds. |
| Added | `Config.Momentum.Fx.GainPitchStep`, `GainPitchCap`, `TierPitchStep`, `SoundVolume` | Local sound pitch rise and capped gain pitch; SFX group volume still applies. |
| Added | `Config.Momentum.Fx.FovInTime`, `FovOutTime`, `PerfectFovKick`, `PerfectFovKickTime` | Tier FOV rise/fall and confirmed perfect-roll kick. `FovBonus` remains the previously supplied 2/5/8 values. |
| Added | `Config.MomentumAssets.Sfx_GainTick`, `Sfx_TierUp`, `Sfx_PerfectRoll` | Exact owner-supplied numeric strings `114295533790228`, `112103056657102`, `125907380174659`. Set to empty string to silence a cue. |
| Added | `Config.MomentumAssets.Sfx_WindLoop`, `Sfx_MomentumLost`, `Tex_Trail`, `Tex_Spark`, `Tex_Dust`, `Tex_SpeedLine` | Empty strings reserved for later work. None are used here. |
| Added | `Config.Settings.ShowPopupsDefault`, `MomentumBarDefault`, `MomentumSoundsDefault` | Default states for the three new in-session settings. All start true. |

The existing `Config.Momentum` gain, cap, decay, diminishing, ceiling, and tier values were not retuned. All new presentation values are `[SD]` and should be adjusted only after the chase and device review. The three sounds are `Pending Review` in `ASSET_LOG.md` until competition-safe provenance is confirmed.

## Two-player chase checklist

1. Open the freshly built `HabulanRush.rbxlx`. Run `tests/MomentumRules.spec.lua` in a Command Bar and `tests/MomentumClient.spec.lua` in a Runner client Command Bar outside a live round. Confirm no runtime compile errors in Output. The Rojo build passed; Studio has not run this place yet.
2. Start a live two-player round. Runner sprint-slide and roll. Confirm one gain per accepted action, the predicted speed settles to the server value, idle and moving decay differ, and the bar tier follows 25/50/85 percent of cap. Try rejected airborne/slow/cooldown slides and invalid rolls; the local value should correct promptly. Ordinary walk, sprint, slide, and roll stay at or below 30 studs/s. Record any honest `horizontal_speed`, `horizontal_displacement`, or `hard_landing_speed` warnings.
3. Press roll in the final 0.05 seconds before landing and again earlier in the 0.15-second buffer. The first should receive a confirmed perfect gain of 3.5 before diminishing/cap; the second a normal 2.5. Under network delay, compare the server-received intent-to-roll-request interval. Send late, far-future, nonnumber, NaN, and grounded `RollIntent` messages in a private Studio test; none should mint a perfect gain. Flood requests to confirm the existing rate guard. A forged timestamp alone must not change the server receipt interval.
4. Build a Runner slide/roll chain, then let the Taya chase and click-tag within the existing 6.5-stud, 70-degree forward volume. Record Runner chain duration and peak speed, Taya catch rate, and tag success at 0, middle, and full momentum. Check the side/rear/wall miss cases as regressions. Repeat with `TayaBuildsMomentum = true` and in a separate temporary Studio test with it false, then restore true in repository Config. Compare whether Taya gains make chases too short. Record winner by least cumulative Taya time, with no movement currency.
5. With positive momentum, stun, tag/role-change, die, end the round, and respawn. Each path must clear the client value, server value, bar, and `MomentumTier` to 0. Observe `GetAttributeChangedSignal("MomentumTier")`: it should fire on threshold crossings, not every heartbeat within one tier. An observer sees that attribute only, with no momentum HUD, sound, or FOV effect from the other player.
6. Repeat input and UI checks on gamepad and mobile. The old bindings and animations must still work. In portrait and landscape, check the bar above the Taya badge and away from thumb controls; popups stay near the owned character without blocking the path.

## Presentation checklist

- From the lobby, toggle Momentum Bar, Show Popups, Momentum Sounds, and Reduce Motion, then enter a round. Verify each independent effect and the existing SFX volume slider. Rejoining resets settings as it does for other client settings.
- Reach a new tier and MAX. Confirm the bar color, one flash per tier change, MAX glow, `xN CHAIN` timing, `MAX` at cap, gray diminished gain, and four-piece red crack plus 0.8-second `MOMENTUM LOST` on hard zero.
- Land slide and roll confirmations within `PopupMergeWindow` and verify one merged popup; keep more than three close actions and verify at most three visible labels. Confirm slide popups rise 40 pixels and fade over 0.6 seconds. Normal, perfect, and merged roll popups hold for 2.4 seconds, then rise and fade over 0.6 seconds.
- Check 2/5/8 FOV additions, the short +3 perfect-roll kick, 0.25-second rise, 0.5-second fall, and exact return to the camera's own FOV after loss. Reduce Motion must remove both momentum FOV effects. Check first person and third person.
- In a temporary Studio-only Config copy, blank each of the three sound IDs separately and confirm no broken sound or error. Restore the supplied strings. The unused six IDs stay empty and silent.

## Pending evidence

The earlier Rojo place build passed. The pure assertions and client smoke test have only been parsed, not executed in Studio. The fresh-place runtime compile, two-player chase, gamepad/mobile layout, sound playback/rights, and FOV restore remain untested. `ServerCorrectionEnabled` stays off and speed violations remain log-only. This earlier version used a 3-second slide cooldown; the slide chaining follow-up changes it to 1.25 seconds in source.
