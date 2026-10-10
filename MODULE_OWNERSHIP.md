# Module Ownership — Habulan Rush
_T05 [Management/P0] • Assigned: 2026-10-07_

## Module Assignments

| Module | Location | Owner | Task Ref |
|--------|----------|-------|---------|
| Config | `ReplicatedStorage/Config.lua` | Designer + Programmer (shared) | T03, T04 |
| TsinelasArc | `ReplicatedStorage/TsinelasArc.lua` | **Programmer B** | T18 |
| MatchService | `ServerScriptService/MatchService.lua` | **Programmer A** | T07, T10 |
| TagService | `ServerScriptService/TagService.lua` | **Programmer A** | T11, T12, T13 |
| SkillService | `ServerScriptService/SkillService.lua` | **Programmer B** | T18, T19, T21, T22 |
| EventService | `ServerScriptService/EventService.lua` | **Programmer B** | T24, T25 |
| MovementController | `StarterPlayerScripts/MovementController.lua` | **Programmer A** | T09 |
| TargetLockController | `StarterPlayerScripts/TargetLockController.lua` | **Programmer B** | T16 |
| UIController | `StarterPlayerScripts/UIController.lua` | **UI Dev** | T14, T17, T26, T27 |
| Remotes | `ReplicatedStorage/Remotes/` | **Shared** | T02 |

## Rules

- One ModuleScript/Script per service — no monolith files.
- Only the assigned owner merges changes to their module.
- Every merge must pass a live 2-player test before pushing.
- Config is the only file all modules may read; no module may write to Config at runtime.
- Logging: tagged `[ServiceName]` prints only in private lobby / debug mode.
