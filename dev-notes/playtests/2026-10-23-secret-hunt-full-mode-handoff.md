---
title: Lihim na Target full-mode handoff
type: playtest
status: pending-owner-validation
owner: project-owner
task: lihim-na-target-all-phases
updated: 2026-10-23
source: owner-approved Lihim na Target all-phases plan
---

# Lihim na Target full-mode handoff

## Verified baseline and source implementation

- Phase 0 inspected repository architecture and the connected `HabulanRush.rbxlx` in read-only Studio Edit mode. No agent Studio playtest or Luau execution occurred. Kalsada is built by Bootstrap at runtime; Binaha has configuration but no verified playable arena.
- The mode vote now offers Classic Tag, Agawan ng Panyo, and Lihim na Target. Secret Hunt uses Kalsada, skips MS_RPS, assigns all participants the Runner movement profile, and preserves Classic and Panyo match branches.
- Four to eight players play three 120-second competitive rounds. One to three players get one practice round with no points or MVP; solo has no target or capture action. A competitive round continues with three after departures, ends and scores earned captures at two, and starts no later round below four.
- `SecretHuntMode` owns a server-only directed target cycle, per-player captures and streaks, two-second target and respawn protection, a one-second Hunter capture cooldown, a four-second pair cooldown, disconnect reassignment, and arena recovery. Captures are blocked outside arena bounds and as soon as a competitive round falls below three players. The existing `RequestTag` hitbox, range, facing, line-of-sight, immunity, and rate checks are reused. No client sends a target ID or capture claim.
- Each participant receives only their own target through `SecretHuntEvent`. The remote also carries approximate distance and an eight-direction pulse at 5/3/2-second intervals, generic nearby-Hunter danger, phase cues, and a final-phase capture leaderboard. Only captures, streaks, phase, and protection are public attributes; the cycle is never replicated.
- Round rank is captures then best untagged streak to 0.1 second. Equal results share rank and rank points. Zero-capture players earn zero points. Final MVP uses total captures, best streak, then match points; no captures means no MVP.
- The client shows a target portrait, name, distance, own captures, countdown, timed direction, danger, notices, and final-phase leaderboard. Click, R2, and mobile CAPTURE use the same server request. Target lock and Tsinelas are disabled in Hunt; Luksong Baka and Runner movement remain available. Capture and assignment sound hooks are silent until approved IDs are supplied.

## Source validation

- `scripts/check-syntax.ps1`: passed.
- `scripts/check-notes.ps1`: passed.
- `git diff --check`: passed for the scoped source and notes.
- Rojo 7.7.1 built `HabulanRush.rbxlx` from `default.project.json`.
- Studio gameplay, mobile, gamepad, visual, and sound acceptance: **pending owner test**. The agent did not run Studio tests.

## Owner Studio checklist

1. Open the fresh `HabulanRush.rbxlx`. Queue and vote **Lihim na Target**. Check all three vote cards fit and work by touch and gamepad. Confirm Hunt loads Kalsada without MS_RPS; Classic still reaches map vote and MS_RPS.
2. **Solo:** Run one practice round. Confirm no target, no CAPTURE action, no points or MVP, and a clean lobby return.
3. **Two clients:** Confirm reciprocal private targets and one practice round. Use click, R2, and mobile CAPTURE. An assigned-target hit counts once; a repeat during the two-second target protection or four-second pair cooldown fails. Reset a character and confirm its assignment persists, its streak ends, and it cannot be captured for two seconds after respawn. No match points or MVP appear.
4. **Four clients:** Confirm everyone has one target and is hunted by one player, with no self-target. Each client sees only its own target. Tag a wrong player inside the valid tag volume: animation may play, but no capture or role change occurs. Capture the assigned target, check exactly one increment and a new private assignment, then immediately retry the old target. Check a fresh valid target after cooldown, death and respawn, reset, disconnect, and arena exit. Confirm three 120-second rounds and phase boundaries at 80 and 40 seconds left.
5. **Population loss:** In a competitive round, leave with one client and confirm the remaining three continue and keep earned scores. Leave with another and confirm the round ends promptly, existing captures are ranked, and no later competitive round starts below four. Repeat a departure during countdown and between rounds.
6. **Eight clients:** Confirm a single directed cycle, no duplicate credit on near-simultaneous attempts, timely 5/3/2-second hint cadence, readable final-phase leaderboard, and complete recaps. Check that no client receives another player's assignment through a public attribute or broadcast payload.
7. **Ranking:** Compare captures, 0.1-second streak ties, shared ranks, match points, and final MVP. Run a zero-capture round and confirm no points; a full zero-capture match shows no MVP. Death, reset, and arena recovery end the current streak.
8. **Devices and visuals:** Check PC, two mobile clients, gamepad, first and third person, VFX 0 and 100, portrait loading, short direction pulses, danger notice, capture flash, and CAPTURE button after repeated reassignment. Tsinelas and target lock must be unavailable without a misleading toast. Sprint, slide, jump, dash, and Luksong Baka must still work.
9. **Regressions:** Run one Classic Tag match through map vote, MS_RPS, tag flow, scoring, and recaps. Run Panyo pickup and repeated A-to-B-to-A stealing, including the mobile STEAL button and Carrier highlight/trail check.

For each failure, record client count, steps, server time, affected player, relevant `HRushHunt*` attributes, expected versus observed behavior, and whether it reproduced in Classic or Panyo. Source completion does not establish Studio gameplay acceptance.

## Release gates

- Secret Hunt sound IDs are blank. Add only original or competition-safe approved Roblox asset IDs and update `ASSET_LOG.md` before expecting capture, assignment, danger, or final cues.
- Panyo's earlier owner Studio matrix is still pending. No game was published by this handoff.
