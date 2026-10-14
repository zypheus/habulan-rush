---
title: dev notes index
type: index
status: approved
owner: team
task: none
updated: 2026-10-14
source: AGENTS.md
related:
  - ../AGENTS.md
  - ../.gemini/TASK.md
---

Start here. This folder holds working notes. The repo stays the single source of truth. New to Obsidian here? Read [obsidian-setup-guide](./obsidian-setup-guide.md) first.

## Root files

- [AGENTS.md](../AGENTS.md): agent operating rules.
- [DESIGN_LOCK.md](../DESIGN_LOCK.md): locked findings F01 to F18. Read only.
- [MODULE_OWNERSHIP.md](../MODULE_OWNERSHIP.md): module owners and merge rules.
- [AI_LOG.md](../AI_LOG.md): Form 03 AI usage log. Append only, never duplicate it here.
- [ASSET_LOG.md](../ASSET_LOG.md): Rule B.6 asset log. Link only, never duplicate it here.

## Design baseline (read only, never edit from notes)

- [Game Design Document](../md-doc/Habulan%20Rush%20Game%20Design%20Document.md)
- [System Specification](../md-doc/Habulan_Rush_System_Specification.md)
- [Technical Design Document](../md-doc/Habulan_Rush_Technical_Design_Document.md)
- [Balance Workbook](../md-doc/Habulan_Rush_Balance_Workbook.md)
- [GDD System Review](../md-doc/Habulan_Rush_GDD_System_Review.md)
- [Production and Launch Plan](../md-doc/Habulan_Rush_Production_and_Launch_Plan.md)
- [Production Tracker](../md-doc/Habulan_Rush_Production_Tracker.md)
- [UI/UX Specification](../md-doc/Habulan_Rush_UI_UX_Specification.md)
- [Art and Audio Bible](../md-doc/Habulan_Rush_Art_and_Audio_Bible.md)

## Live tracker

The live task tracker is `.gemini/TASK.md`. There is no second tracker. Obsidian hides dot-folders, so the tracker is edited in the code editor, never in Obsidian. Open it by path: `.gemini/TASK.md`. Architecture notes live next to it at `.gemini/PLANNING.md`.

## Subfolders
- [decisions](./decisions/): one note per decision, with approver and affected values.
- [playtests](./playtests/): one note per test session, with build, players, and results.
- [handoffs](./handoffs/): one note per session boundary. The next session reads the latest handoff first.
- [prompts](./prompts/): reusable step-gated agent prompts.
- [templates](./templates/): blank templates for the notes above plus bug reports.

## How we work

1. Read `.gemini/TASK.md` and the latest note in [handoffs](./handoffs/).
2. Edit code under `src/`. Never edit scripts inside Studio.
3. Rebuild with Rojo and reopen the place before testing.
4. Test in Studio. Record results in a [playtests](./playtests/) note.
5. Log AI work in [AI_LOG.md](../AI_LOG.md) and assets in [ASSET_LOG.md](../ASSET_LOG.md).
6. End the session with a [handoffs](./handoffs/) note.
