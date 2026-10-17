---
name: habulan-rush
description: >
  Work in the Habulan Rush Roblox repository using its live task state,
  ownership boundaries, and validation workflow. Use for repository changes,
  reviews, and handoffs in this project.
---

# Habulan Rush

Use this skill for work in the Habulan Rush repository. It complements general coding and response-style skills such as Ponytail and Caveman; it does not replace them.

## Start with project state

- Read `dev-notes/current-task.md` for the approved item, next step, blockers, and validation status.
- Before editing a service or controller, read `MODULE_OWNERSHIP.md` and confirm the file is canonical in `default.project.json`.
- Read only the relevant locked design sections and project notes. Treat `.gemini/TASK.md` as historical, not live state.
- If the requested change is outside the approved item, do not modify game code. Explain the scope mismatch and identify what needs project-owner approval.

## Preserve project boundaries

- Follow `AGENTS.md` and the relevant owner or reviewer boundaries in `MODULE_OWNERSHIP.md`.
- Do not change locked values without project-owner sign-off. Keep `Config.lua` as the read-only runtime source of truth.
- Preserve server authority for game state and validation. Keep client code to input, prediction, UI, audio, camera, and cosmetic effects.
- Do not edit `.agents/skills/` or the generated `HabulanRush.rbxlx`.
- Keep changes limited to the approved item. Do not start the next item as part of a handoff.

## Finish the item

- Update `dev-notes/current-task.md` with completed work, the exact next step, blockers, and validation. Preserve unrelated live task state.
- Append an AI use entry to `AI_LOG.md`. Update `ASSET_LOG.md` when assets are involved.
- Run the checks relevant to the change from `AGENTS.md`. Do not claim Studio, multiplayer, mobile, or gamepad validation unless it was actually performed; record missing validation as a blocker.
- Add a playtest or handoff note when the work produces relevant evidence or remains unfinished.
- Summarize the files changed, checks run, unverified behavior, and next step.
