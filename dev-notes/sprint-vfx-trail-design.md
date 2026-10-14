---
title: sprint vfx trail design
type: seed
status: approved
owner: team
task: T09
updated: 2026-10-14
source: src/ReplicatedStorage/Config.lua (Config.SprintVFX.Trail table)
related:
  - ./00-index.md
  - ../src/StarterPlayerScripts/SprintVFX.lua
---

Verified reference for the sprint trail effect design.

## Verified facts

- One smoothed intensity value from real horizontal speed drives every sprint effect.
- Leg trail segments live 1.0 s with a needle taper, and arm trails run at about half width and lifetime.
- Sprint effects suppress on dash, slide (`HRushSliding`), RS_01 flight, Tsinelas aim, stun, non-Runner roles, and outside MS_04 (`src/StarterPlayerScripts/SprintVFX.lua:139-162`).
- Suppression reads existing attributes only, so no new plumbing was added.
- All trail numbers live in the `Config.SprintVFX.Trail` table. Exact line numbers shift with Config edits, so cite the table name.
