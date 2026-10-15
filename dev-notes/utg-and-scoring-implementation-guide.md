---
title: untitled tag game and scoring implementation guide
type: seed
status: draft
owner: team
task: none
updated: 2026-10-14
source: research 2026-10-14 (tagging.wiki, roblox fandom UTG page, repo verification)
related:
  - ./00-index.md
  - ./pending-doc-updates.md
  - ../md-doc/Habulan Rush Game Design Document.md
---

Implementation guide from the Untitled Tag Game research and the scoring gap audit. Read this before implementing any item below. Nothing here is approved until its own sign-off.

## Part 1: what Untitled Tag Game does

Sources: the official wiki at https://tagging.wiki (Movement, Sliding, Swinging, Tech, Controls pages) and the Roblox wiki page for Create community untitled tag game. UTG is a parkour chase game by _create, recoded from the ground up, with 13+ modes and 12+ maps. Only mechanics were studied. Monetization (gamepasses, shop, coins) was reviewed and rejected for this project because competition rules forbid Robux transactions.

### Movement core

- C slides on the ground and rolls when landing. Jump (Space) near a ledge vaults, near a swing bar swings, near a zipline latches. W held runs (no Shift key). M opens settings. K mutes music.
- Rolling: pressing C before landing boosts walk speed for a short moment, +9 to +22 over base depending on airtime before landing. Longer falls earn bigger rolls.
- Sliding: locked direction, camera turns independently. Pressing C gets up early and carries momentum. Holding A or D curves the slide slightly. Sliding on slopes gives a temporary speed boost. Slide boosting (cancel slide then jump instantly) gives extra jump height from the recovery animation.
- Swinging: jumping while touching a swing bar pauses the character while the animation plays, then boosts in the facing direction. Falling speed converts into momentum. Boost scales with fall distance and stops mattering on the ground. Bars are marked with attributes on parts and exist on every map.
- Vaulting: jumping in front of a ledge boosts up and over. Rapid vaulting climbs fast. Lower vaults jump higher.
- Rails: touching a rail grinds with slight extra speed. Rolling on a rail railflings (launches) forward.
- Wallrun: running toward a wall starts it automatically. Jump exits.
- Ziplines: jump to latch onto a wire between two attributed parts. Auto dismount at either end, jump for early exit.
- Momentum stacking (the Tech page system): a momentum value adds on top of base walkspeed with a max of 31. Vaulting continuously without touching ground, pressing space on swing bars or stairs, fall swings, and chained swings all add momentum. Momentum decays 2 per second and resets to 0 when velocity drops near 0.
- Bunny hopping: repeated jumps without losing momentum gain speed. Pressure flinging (1 to 2 stud gaps plus roll end plus jump) launches the character and is engine physics, not intended design.
- Tag feedback: runners who try to tag only push the target back slightly. Taggers who leave transfer the role to someone else. Dead players become Oof spectators with night vision and no collision.

### Structure

- Each round offers 3 gamemodes to vote on. Map vote happens every 2 rounds. Misprints are rare variants of a map or mode with a new gimmick.
- Roles carry cosmetics (bomb head, slasher claws, night vision). Disconnects reassign the role to another player.
- Progression is XP, levels, coins (10+ per round win), a shop (trails, emotes, skins), achievements, and badges (Roll Expert, Gymnast, Dizzy). All of this is out of scope here except the lesson: reward movement skill visibly.
- Community-made music. Out of scope except the lesson that licensed or team-made audio is shippable.

## Part 2: adoptions for Habulan Rush (ranked)

### Item A: unified momentum model (selected first)

Replace the one-off boosts (slide 1.25x, planned air-roll multiplier) with one decaying value.

- State: `momentum` number in MovementController, range 0 to `MomentumCap`.
- Effective speed: `(roleBase * SpeedScale * roleMult) + momentum`. Role multipliers (ex-Taya 1.20 from DESIGN_LOCK.md F08, Hatak 1.35) apply to base first and are never converted.
- Gainers: ground slide entry `SlideGain = 4`, air-roll landing `+6` to `+12` scaled by airtime (UTG +9 to +22 rescaled), vault mantle `VaultGain = 4`, swing bar fall-scaled when the prop ships.
- Decay `4` per second while moving. Zero on velocity near 0, stun entry, round end, death, standstill.
- Excluded v1: dash (fixed-travel glide), RS_01 flight and landing (no skill synergy exploits), ex-Taya and Hatak multipliers (locked design).
- Config table `Config.Momentum = { Cap = 12, Decay = 4, SlideGain = 4, AirRollMin = 6, AirRollMax = 12, VaultGain = 4, ZeroSpeed = 0.5 }`, all [SD]. Retire `SlideSpeedMult` in the same diff.
- Integration point: `applySpeed` in `src/StarterPlayerScripts/MovementController.client.lua` adds momentum to the target. Slide entry captures the current total as sustained speed. Zero through existing respawn, death, and round-end cleanup.
- Risks: combo loops pinning the cap (verify decay outruns roll-slide-vault chains in a 2-player chase), pounce-band compression (retest 40 to 60 percent with momentum on and off).
- Verify: decay timing, cap clamp, all zeroing cases, chase parity, HUD pip if added.

### Item B: airtime-scaled air-roll (selected with the momentum model)

- C while airborne tucks for the slide window. Boost scales with fall time like UTG, minimum for apex taps so jump peaks cannot farm it.
- Shares the 3s slide cooldown so ground and air cannot double-dip. No HipHeight change (already airborne). Reduced air control during the tuck.
- Gates: blocked during RS_01 flight and windup (`skillFlightLeft > 0`), blocked while stunned, ends on landing through the existing landing hook. No tag immunity; TagService treats rollers as normal airborne targets.
- Lands as a momentum gain (see Item A) instead of a multiplier, so the selected model and this item are one implementation.
- Verify: solo lobby run-jump-C (tuck, surge, anim), no RS_01 interaction, cooldown shared with ground slide on the HUD.

### Item C: vault mantle (selected third)

- Jump pressed airborne plus a solid ledge within about 3 studs ahead or above plus off cooldown snaps to the ledge top with kept momentum. Caps: height 4 studs (matches vault-height jeepneys and crates), distance 6, cooldown 4s. Smaller than RS_01 in every dimension so the skill keeps its identity.
- New `performMantle` next to `performSlide`, reusing the heartbeat-sustain pattern and the dash wall-raycast idiom (anchored parts only, floors and ceilings excluded by normal).
- No untouchable window. Ledge contact counts as a landing for tag purposes. RS_01 airborne immunity untouched.
- Config: `MantleRange = 3`, `MantleMaxHeight = 4`, `MantleDistance = 6`, `MantleCooldown = 4`, `MantleAnimId = ""` (ships anim-less with the slide crouch fallback; no new asset).
- Risks: wall clipping, mantle spam up the 14-stud boundary walls (blocked by the height cap), ladder-style spam (no ladders exist).
- Verify: jeepney-side double jump snaps to roof, spam test shows no climb chains, boundary walls reject, 2-player crate chase.

### Item D: Taya marker plus tag knockback (selected, third batch)

- Floating marker above the Taya (neon chevron plus point light), spawned from the same role broadcasts MovementController consumes, destroyed on role loss, round end, and respawn. Zero server change. Color must coordinate with the colorblind palette (orange, distinct from Runner blue and Taya red).
- Tag knockback in the existing `TagEvent.OnClientEvent` handler: brief horizontal impulse away from the tagger, single raycast wall clamp like dash, never vertical. Tiny magnitude (separation, not launch). Ex-Taya boost math untouched.
- Config: `TayaMarkerSize`, `TayaMarkerColor`, `TagKnockbackSpeed`, `TagKnockbackTime` around 0.15s, all [SD].
- Verify: marker swaps instantly on tag, no vertical pop, a spectator names the new Taya immediately (supports the T28 readability test).

### Item E: slide curve with A/D (new finding, unranked)

- UTG lets A or D curve a locked slide slightly and C stand up early keeping momentum. Our steer lock could allow a small curve instead of a full lock. Cheap change inside the slide sustain (blend a fraction of MoveDirection per frame). Needs sign-off because the team chose full lock.
- Slide boosting (cancel plus jump for height) should be tested after implementation and either kept as tech or closed deliberately, never left accidental.

### Item F: swing bars via part attributes (new finding, unranked)

- Mark lintel bars with an attribute so the grab code finds them without a hardcoded list, exactly like UTG. Fall-scaled boost per the Swinging page. Ships with the prop, with its gains feeding Item A.

### Deferred or rejected

- Misprint variant rounds: fits the Rush event dice (MatchService and EventService roll), no new simulation. Good spectacle backlog item, not movement work.
- Wallrun, rails, ziplines, cannons, bounce pads, lava, water, breakables, windboxes: map toybox for after the Oct 21 freeze, except single cheap picks by owner decision.
- W-hold sprint, M settings key, emote wheel, XP, levels, coins, shop, badges-as-inventory: rejected or backlog. Our bindings follow UI/UX Spec section 4 and our settings key is already H. Achievements map to existing clutch callouts and MVP titles (T27).
- K mute shortcut: five-line addition, suggest any time.

## Part 3: scoring mechanics audit (verified 2026-10-14)

### How scoring works today

- Round (MS_05): the server adds 0.1s per tick to whoever holds Taya during MS_04 (`src/ServerScriptService/MatchService.server.lua:972-974`), mirrored to `HRushTayaTime`. At round end participants sort ascending and take `Config.Match.RoundPoints` 8-6-5-4-3-2-1-0, top-N slots for small lobbies (F05). A recap payload (rank, name, bot flag, times, points) fires to all clients.
- Match (MS_06): totals over 3 rounds sort points descending, tie-break total Taya time ascending (lines 1055-1060). Rank 1 is MVP. Podium payload fires. All server-side.
- Spec basis: GDD section 3.4 (rank by lowest Taya time, points table, match winner by points with total-time tie-break), DESIGN_LOCK.md F04 (ties share rank and points), System Specification section 2.2 (leavers last, sub-4 pause with no points), UI/UX Spec (scoreboard top right, round and match recap contents).

### Gap 1: round ties do not share (F04 violated)

- Code assigns sequential ranks by sort order, so tied or near-tied times pay different points.
- Fix: group equal round times (exact equality on the floored tenth values already published) into shared rank and shared points, then skip the consumed table slots. About 15 lines in the MS_05 ranking block. Owner: Programmer A.
- Verify: 2-player test with forced equal times shows shared rank and points in the recap.

### Gap 2: tie-break chain incomplete (GDD section 3.4)

- GDD wants Taya time, then fewer times tagged, then more escapes. Tag and escape counters do not exist yet.
- Fix: TagService T11/T13 owns two per-player counters (`timesTagged`, `escapes`, with pounce-dodge defining escape). The MS_05 and MS_06 sorts become three-key: time asc, tags asc, escapes desc. Owner: Programmer A, after T11/T13.
- Verify: tied-time round breaks toward the less-tagged player in the recap.

### Gap 3: leavers vanish instead of ranking last (Spec section 2.2, F18)

- Disconnects are removed from participants and disappear from the board.
- Fix: snapshot leavers per round with their frozen round time and append them below all finishers before points assignment. Owner: Programmer A.
- Verify: 2-player test with a mid-round leave shows the leaver last.

### Gap 4: no below-minimum pause (Spec section 2.2)

- Spec wants a 10s pause then round end with no points below 4 players. Code only aborts on zero real players and otherwise awards full points to tiny remainders.
- Fix: participant-count watch in the MS_04 loop. Below 4 starts a 10s pause (freeze input, banner), recovery resumes, expiry ends the round with no points awarded. Owner: Programmer A.
- Verify: drop to 3 players mid-round, confirm pause banner, recovery, and the no-points path.

### Gap 5: bots can win and hold MVP

- Fine for testing. Before judged matches, exclude `IsBot` participants from titles (or mark the podium unofficial) and confirm the recap UI shows the bot flag it already receives. Owner: UI Dev for the recap, Programmer A for eligibility.

## Suggested build order across both threads

Momentum model plus air-roll landing gain, then vault mantle, then Taya marker plus knockback, then scoring gaps 1 and 3, then gap 4, then gap 2 with TagService counters. Slide curve, swing bars, misprints, and the map toybox stay backlog. Every item needs its [SD] sign-off and the 2-player test before merge per repo rules.
