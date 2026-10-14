---
title: pending doc updates
type: meta
status: draft
owner: team
task: none
updated: 2026-10-14
source: repo-wide verification 2026-10-14
related:
  - ./00-index.md
  - ./rs-03-tsinelas-throw.md
  - ./decisions/speed-scale-experiment.md
---

Stale canonical doc lines found by checking docs against Config. Do not edit those docs from here. Each entry needs owner review.

## Entries

| Doc file and line | Stale wording | Live value | Notes |
|------|-----|-----|-------|
| `md-doc/Habulan_Rush_System_Specification.md:98` | RS_03 projectile up to 25 studs | `Config.lua:311` range 40 | Range raised, doc never updated. |
| `md-doc/Habulan Rush Game Design Document.md:249` | RS_03 range 25 studs | `Config.lua:311` range 40 | Same range drift as above. |
| `md-doc/Habulan_Rush_System_Specification.md:43` | Stamina regen 12/s after 1 s | `Config.lua:13-14` regen 16 after 0.6 s | Economy retune, doc never updated. |
| `md-doc/Habulan Rush Game Design Document.md:156` | Stamina regen 12/s after 1 s | `Config.lua:13-14` regen 16 after 0.6 s | Same retune drift as above. |
| `md-doc/Habulan_Rush_System_Specification.md:45` | Slide 0.6 s with reduced speed | `Config.lua:23` duration 1.0, `Config.lua:26` 1.25x boost | Duration and boost changed, doc never updated. |
| `md-doc/Habulan Rush Game Design Document.md:159` | Slide 0.6 s | `Config.lua:23` duration 1.0 | Same duration drift as above. |
| `md-doc/Habulan_Rush_System_Specification.md:42`, `md-doc/Habulan Rush Game Design Document.md:154-155` | Walk 16, sprint 21 | Locked bases still true, but `Config.lua:10` SpeedScale 1.5 makes live speeds 24 and 31.5 | Needs a scale note after team sign-off. |
| `Config.Skills.RS_03.weakness` | Wording "Linear projectile" | `TsinelasArc.lua:8` fixed 45 degree arc sim | Review whether the weakness wording still fits the arc. Config change needs owner sign-off. |

## Unverified claims

- The brief mentioned a "Linear projectile" wording in md-doc. A repo-wide search found that wording only in `Config.Skills.RS_03.weakness`, not in any design doc. Marked here instead of asserted.
