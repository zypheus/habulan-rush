---
title: Clear arcade feedback handoff
type: playtest
status: awaiting-owner-save-and-test
owner: project-owner
task: clear-arcade-match-feedback
updated: 2026-10-24
source: 2026-10-24 owner-approved clear arcade feedback plan
related:
  - ../current-task.md
  - ../../studio-feedback.project.json
---

# Clear arcade feedback

## Source and Edit handoff

- Repository source now uses one `MatchFeedback` module for a short, safe-area, two-line local action notice. Confirmed local outcomes outrank other notices. Hunt's changed-target notice waits behind capture or caught feedback. The queue clears on round, mode, or match exit.
- Classic Tag uses the existing server-owned `TagEvent`. The tagger and new Taya get distinct Filipino messages, a restrained supported-gamepad vibration, and the existing slap sound. Bystanders retain the small feed. Feed names now resolve from event user IDs, which are the fields the server actually sends.
- Panyo pickup and steal messages distinguish new Carrier, robbed Carrier, and bystanders. Hunt capture and caught messages remain private, with a new-target follow-up. Its existing capture flash now honors reduced motion. The shared notice remains readable when VFX is set to zero. No gameplay rule, server remote, or asset was changed.
- `studio-feedback.project.json` is restricted to place `127422539599317` and maps Config plus the five touched/new client scripts. It includes no Workspace objects. The owner reported `HabulanRushFeedbackSync` connected and synced on `localhost:34872`. Read-only Studio inspection confirmed `MatchFeedback`, the Classic, Panyo, and Hunt message handlers, the removal of the all-client slap, and the 12 spawn regions and origin spawn preserved. No Studio test, Luau execution, or publish was run by the agent.
- Panyo and Hunt original local WAV cues remain pending owner upload and approval. Their empty runtime IDs intentionally stay silent. The existing Classic slap asset still has provenance review pending in `ASSET_LOG.md`.

## Owner test checklist

1. Save the same open Habulan Rush Edit place. Do not publish for this handoff.
2. With two and eight players in Classic Tag, tag repeatedly from click, R2, and touch. Confirm only the two involved players get the large local result and slap sound, the new Taya sees the correct role, bystanders get only the small feed, and names are correct. A miss or rejected tag must not show success.
3. In Panyo, pick up, steal, lose, and drop the cloth. Confirm the Carrier and robbed player get different messages, other players get compact updates, and rapid steals show the latest result without a stale queued notice. Verify the existing carrier highlight, score, reveal, and final cues still work.
4. In Secret Hunt, capture and be caught. Confirm `HULI! +1` or `NAHULI KA` appears first, then a changed `BAGONG TARGET` notice. Verify no target identity is shown to other players, danger stays readable, and the capture flash is absent with reduced motion or VFX zero.
5. Check countdown, round end, respawn, and mode transitions for stale feedback. On desktop, phone landscape, and gamepad, check safe-area placement and that the reticle, target card, timer, and controls remain usable. Test VFX zero, reduced motion, mute, and supported gamepad rumble. Report the first failure with mode, player role, client count, device size, steps, and a screenshot or Studio Output excerpt.

## Acceptance

- Source syntax, notes, diff whitespace, and full and targeted Rojo builds: passed before handoff.
- Studio script inspection after accepting the new Rojo project: passed by read-only inspection of the mapped feedback paths; runtime behavior remains untested.
- Owner save, two-player/eight-player, and device gameplay results: pending.
