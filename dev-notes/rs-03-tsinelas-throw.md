---
title: rs-03 tsinelas throw reference
type: seed
status: approved
owner: team
task: T18
updated: 2026-10-14
source: src/ReplicatedStorage/Config.lua:304-321
related:
  - ./00-index.md
  - ./pending-doc-updates.md
  - ../src/ReplicatedStorage/TsinelasArc.lua
---

Verified reference for RS_03 Tsinelas Throw tuning and behavior.

## Verified facts

- Range is 40 studs (`src/ReplicatedStorage/Config.lua:311`). The design docs still say 25; see pending-doc-updates.
- Arc gravity is 80 (`src/ReplicatedStorage/Config.lua:316`).
- The arc is a fixed 45 degree launch solved from distance (`src/ReplicatedStorage/TsinelasArc.lua:8`, `:24`, `:52`).
- Hold-to-aim runs on a held-key state machine in MovementController (`tsinelasHeld`, `tsinelasAiming`), with max hold 3.0 s (`src/ReplicatedStorage/Config.lua:320`).
- The aim camera eases into first person and restores on exit (`src/ReplicatedStorage/Config.lua:419-427`, `Config.UI.TsinelasCam`).
- The "raised from 25 to 40" history is unverified from git; only the current 40 and the stale doc 25 are confirmed.
