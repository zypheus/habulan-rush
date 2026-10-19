---
title: momentum slice 1 handoff
type: playtest
date: 2026-10-19
status: pending
owner: project-owner
task: momentum-slice-1
updated: 2026-10-19
source: owner-pasted momentum task, 2026-10-19
---

# Momentum slice 1 handoff

The server now stores momentum per player. Accepted slide entries and landing rolls add to it. A validated `RollIntent` received while airborne within 0.05 seconds of a successful roll grants the perfect gain. The existing client sends `Roll` only at landing, so it cannot get a perfect gain until slice 2 sends the button intent earlier. Momentum decays after grace, clears on the existing stun, tag role change, death, and round reset paths, and is sent only to its owning client through `MomentumUpdate`. The client still uses the old slide and roll boosts until slice 2, so this is a staged implementation and the speed ceiling has not been approved in live play.

## Two-player Studio checklist, after source sync

1. Start a live round with two players. In each client Command Bar, connect `game.ReplicatedStorage.Remotes.MomentumUpdate.OnClientEvent:Connect(print)` before moving. Confirm only that player's accepted actions and corrections print there. The other client gets no value snapshots.
2. Sprint and slide as Runner. Expect one `Slide` gain of 1.5. Rejected slides while airborne, slow, stunned, outside the round, or on cooldown must give no gain. The current 3-second slide cooldown exceeds the 2-second diminishing window, so repeated slide gains of 0.9 and 0.45 are pure-math test cases until a later approved tuning change.
3. Land a normal roll. Expect a `Roll` gain of 2.5. The 3.5 perfect gain needs slice 2 to send `RollIntent` when the button is pressed. Repeat a roll within 2 seconds to check diminishing. Check the pending-landing path under network delay.
4. Stop after a gain. Expect 0.75 seconds with no decay, then 6 studs/s of bonus drain while idle. Repeat while moving for 1.5 studs/s drain. Check a capped action returns zero actual gain.
5. Build momentum on both roles. Use the existing instant click tag with a target inside the 6.5-stud forward volume and 70-degree arc. Confirm the tag still succeeds, both players' momentum clears on the role transfer, the former Taya still gets the 2-second 20 percent boost, and the 0.15 speed tolerance does not log an honest movement violation. Also test a miss, side/rear target, wall, and safe target to confirm no new tag behavior.
6. Stun a player, kill a character, and end a round. Each must send a `Lost` snapshot if momentum was positive. Confirm no momentum carries into the next round or respawn.
7. Check server-observed walk, sprint, slide, roll, and hard landing with momentum. Ordinary allowed speed must stay at or below 30. Dash remains a separate scripted travel action. Record any false `horizontal_speed`, `horizontal_displacement`, or `hard_landing_speed` warning.

Run `tests/MomentumRules.spec.lua` in Studio after syncing the module. It checks gain math, diminishing returns, cap, grace and decay, tiers, and composed speed. Client prediction matching and perfect-roll input delivery remain for slice 2. The 30 studs/s cap needs this two-player chase test before approval. Gamepad and mobile input and UI checks remain for later slices.
