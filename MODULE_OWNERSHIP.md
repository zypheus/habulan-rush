# Module Ownership

Updated: 2026-10-15
Human merge owner: **Project Owner**, sole maintainer
Primary coding agent: **Codex**, only for the currently approved item

`default.project.json` is the authority for runtime source paths. The paths below are canonical. Files with similar names outside this table are not production source unless the Rojo project is deliberately changed.

## Shared and replicated

| Module or area | Canonical source | Runtime role | Owner |
|---|---|---|---|
| Config | `src/ReplicatedStorage/Config.lua` | Immutable shared values; server and client read only | Project Owner |
| TagRules | `src/ReplicatedStorage/TagRules.lua` | Pure shared tag rules | Project Owner |
| TsinelasArc | `src/ReplicatedStorage/TsinelasArc.lua` | Pure shared RS_03 arc calculations | Project Owner |
| Dash VFX | `src/ReplicatedStorage/VFX/Dash.lua` | Replicated cosmetic helper | Project Owner |
| Run styles | `src/ReplicatedStorage/Cosmetics/RunStyles.lua` | Replicated cosmetic definitions | Project Owner |
| Remotes | `default.project.json`, `ReplicatedStorage.Remotes` | Client/server API instances; server validates client requests | Project Owner |

## Server

| Service | Canonical source | Authoritative state or responsibility | Owner |
|---|---|---|---|
| PartyService | `src/ServerScriptService/PartyService.lua` | Party membership, leader actions, and party locks | Project Owner |
| MatchService | `src/ServerScriptService/MatchService.server.lua` | Queue, match phases, participants, roles, timer, scoring, and temporary tag path | Project Owner |
| TagService | `src/ServerScriptService/TagService.server.lua` | Planned canonical tag, safe-window, pounce, and rewind authority | Project Owner |
| SkillService | `src/ServerScriptService/SkillService.server.lua` | Skill validation, cooldown ledger, RS_03 hit simulation, and stuns | Project Owner |
| EventService | `src/ServerScriptService/EventService.server.lua` | Planned round event authority | Project Owner |
| RunStyleService | `src/ServerScriptService/RunStyleService.server.lua` | Server-whitelisted cosmetic animation selection | Project Owner |
| Bootstrap | `src/ServerScriptService/Bootstrap.server.lua` | Kalsada greybox, lighting, and character defaults | Project Owner |

## Client

| Controller or module | Canonical source | Client-owned responsibility | Owner |
|---|---|---|---|
| MovementController | `src/StarterPlayerScripts/MovementController.client.lua` | Input, predicted movement, movement animation, ability presentation, and local camera effects | Project Owner |
| SprintVFX | `src/StarterPlayerScripts/SprintVFX.lua` | Sprint cosmetic state and instances | Project Owner |
| SprintVFX bootstrap | `src/StarterPlayerScripts/SprintVFX.client.lua` | Starts the SprintVFX module | Project Owner |
| TargetLockController | `src/StarterPlayerScripts/TargetLockController.lua` | Local target selection, reticle, and camera assist | Project Owner |
| TargetLock bootstrap | `src/StarterPlayerScripts/TargetLockController.client.lua` | Starts the target-lock module | Project Owner |
| UIController | `src/StarterPlayerScripts/UIController.client.lua` | Match HUD, cooldowns, draft presentation, and recaps | Project Owner |
| LobbyUI | `src/StarterPlayerScripts/LobbyUI.client.lua` | Lobby, party, queue, settings presentation, and lobby camera | Project Owner |
| MapVoteUI | `src/StarterPlayerScripts/MapVoteUI.client.lua` | Map-vote presentation and input | Project Owner |
| ClientSettings | `src/StarterPlayerScripts/ClientSettings.lua` | In-session presentation settings | Project Owner |
| AudioRouter | `src/StarterPlayerScripts/AudioRouter.lua` | Client SoundGroups and one-shot routing | Project Owner |
| MusicController | `src/StarterPlayerScripts/MusicController.lua` | Client match-state music playback and fades | Project Owner |
| VfxScale | `src/StarterPlayerScripts/VfxScale.lua` | Client cosmetic intensity and telegraph floor | Project Owner |

## Tools and world inputs

| Area | Canonical source | Responsibility | Owner |
|---|---|---|---|
| Animation authoring | `tools/AnimationDev/HRush_AnimDev.lua` | Original R15 sprint, slide, and dash source sequences | Project Owner |
| Workspace map input | `assets/Map.rbxmx` | Minimal Rojo Workspace map input; Bootstrap currently builds Kalsada | Project Owner |

## Rules

- The project owner is the only merge owner. Codex may modify a path only within an explicitly approved item.
- One behavior has one authoritative mutation owner. Client prediction and presentation never replace a server decision.
- Use direct dependencies and the current flat layout. Split a module only for a real authority, lifecycle, persistence, or test boundary.
- `Config` is read-only at runtime. Locked-value changes require project-owner approval.
- New client-to-server operations require type, bounds, state, role, membership, cooldown, and abuse validation.
- Every gameplay merge requires a Rojo build and a relevant live 2-player test before pushing.
- New assets require `ASSET_LOG.md`; AI-assisted work requires `AI_LOG.md`.
