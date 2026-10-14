---
title: 2026-10-14 obsidian setup complete
type: handoff
status: done
owner: team
task: none
updated: 2026-10-14
source: 29d4fd8
related:
  - ../00-index.md
  - ../obsidian-setup-guide.md
---

Obsidian notes workflow is built and green. Game code sits at 29d4fd8 with notes work uncommitted.

## Goal

Set up the Obsidian-friendly notes workflow and answer the setup questions.

## Current state

- `dev-notes/` holds the index, 5 templates, 8 seed notes, and the 1.14.4 setup guide.
- `scripts/check-notes.ps1` passes with NOTES OK.
- Game work (slide 1.25x reimplementation, Pixabay dash SFX) is committed at 29d4fd8.
- Uncommitted: `.gitignore`, `AGENTS.md`, `AI_LOG.md`, `dev-notes/`, `scripts/check-notes.ps1`. The `.obsidian/*.json` modifications are local UI state from opening the vault, covered by the new ignore entry.

## Done

- All 7 workflow steps plus the 1.14.4 guide note.
- AI_LOG.md has both rows.

## Next step

Commit the notes work (`dev-notes/`, `scripts/check-notes.ps1`, `.gitignore`, `AGENTS.md`, `AI_LOG.md`) in one docs commit, leaving `.obsidian/` untracked.

## Blockers

- None. Open sign-offs live on: slide 1.25x boost, Taya slide vs F09, SpeedScale 1.5, Pixabay row review.

## Commands to run

Run from the repo root: `powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\check-notes.ps1"` and expect NOTES OK. Build the game only when touching code: `rojo build default.project.json -o HabulanRush.rbxlx` with `%LOCALAPPDATA%\rojo-bin\rojo.exe`.

## Reminder

Rebuild with Rojo and reopen the place before testing. Never edit scripts inside Studio.
