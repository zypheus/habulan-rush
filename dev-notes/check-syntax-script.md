---
title: check syntax script
type: seed
status: approved
owner: team
task: none
updated: 2026-10-14
source: scripts/check-syntax.ps1:1-33
related:
  - ./00-index.md
  - ./rebuild-and-test-rule.md
---

Verified reference for the syntax gate script.

## Verified facts

- `scripts/check-syntax.ps1` runs StyLua check on `src/` and fails only on parse errors. Formatting-only differences are ignored.
- StyLua lives outside the repo at `%LOCALAPPDATA%\luau-bin\stylua.exe`, with install steps in the script header.
- Run from the repo root. Exit 0 prints SYNTAX OK.
- A passing check does not replace testing in Studio.
- The notes link checker (`scripts/check-notes.ps1`) follows this script's style.
