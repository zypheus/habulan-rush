# Module Ownership

Updated: 2026-10-23
Human merge owner: **Project Owner**, sole maintainer
Primary coding agent: **Codex**, only for the currently approved item

`default.project.json` is the authority for runtime source paths. The paths below are canonical. Files with similar names outside this table are not production source unless the Rojo project is deliberately changed.

## Shared and replicated

| Module or area | Canonical source | Runtime role | Owner |
|---|---|---|---|
| Config | `src/ReplicatedStorage/Config.lua` | Immutable shared values; server and client read only | Project Owner |
| TagRules | `src/ReplicatedStorage/TagRules.lua` | Pure shared tag rules | Project Owner |
| RpsRules | `src/ReplicatedStorage/RpsRules.lua` | Pure bato bato pick stage resolution | Project Owner |
| MomentumRules | `src/ReplicatedStorage/MomentumRules.lua` | Shared pure momentum gain, decay, tier, and speed math | Project Owner |
| TsinelasArc | `src/ReplicatedStorage/TsinelasArc.lua` | Pure shared RS_03 arc calculations | Project Owner |
| Dash VFX | `src/ReplicatedStorage/VFX/Dash.lua` | Replicated cosmetic helper | Project Owner |
| Run styles | `src/ReplicatedStorage/Cosmetics/RunStyles.lua` | Replicated cosmetic definitions | Project Owner |
| Remotes | `default.project.json`, `ReplicatedStorage.Remotes` | Client/server API instances; server validates client requests | Project Owner |
| MomentumUpdate remote | `default.project.json`, `ReplicatedStorage.Remotes` | Server-to-owner momentum snapshots and accepted action gains | Project Owner |
| DashVFXEvent remote | `default.project.json`, `ReplicatedStorage.Remotes` | Server-accepted dash cosmetic broadcast; clients make no gameplay decision | Project Owner |
| RPS remotes | `default.project.json`, `ReplicatedStorage.Remotes` | StageStart, Reveal, Result server presentation and validated SubmitSign request | Project Owner |
| ModeVoteEvent remote | `default.project.json`, `ReplicatedStorage.Remotes` | Validated mode ballot requests and server vote presentation | Project Owner |
| PanyoEvent remote | `default.project.json`, `ReplicatedStorage.Remotes` | Server-only Panyo pickup, steal, drop, phase, reveal, and final cue presentation | Project Owner |

## Server

| Service | Canonical source | Authoritative state or responsibility | Owner |
|---|---|---|---|
| PartyService | `src/ServerScriptService/PartyService.lua` | Party membership, leader actions, and party locks | Project Owner |
| MatchService | `src/ServerScriptService/MatchService.server.lua` | Queue, match phases, participants, roles, timer, scoring, and server-only tag commit | Project Owner |
| PanyoMode | `src/ServerScriptService/PanyoMode.lua` | One panyo instance, server-observed pickup, Carrier ownership, steal protection, recovery, and possession clock | Project Owner |
| PanyoEvents | `src/ServerScriptService/PanyoEvents.lua` | Panyo phase transitions, periodic reveals, and final-second cues | Project Owner |
| MovementAuthority | `src/ServerScriptService/MovementAuthority.lua` | Server movement state, request validation, cooldowns, and passive speed/displacement observation | Project Owner |
| MovementAuthority bootstrap | `src/ServerScriptService/MovementAuthority.server.lua` | Starts the MovementAuthority lifecycle | Project Owner |
| TagService | `src/ServerScriptService/TagService.server.lua` | Click tag rate guard, target selection, spatial/arc/LOS validation, and replicated third-person tag animation | Project Owner |
| SkillService | `src/ServerScriptService/SkillService.server.lua` | Skill validation, cooldown ledger, RS_03 hit simulation, and stuns | Project Owner |
| EventService | `src/ServerScriptService/EventService.server.lua` | Planned round event authority | Project Owner |
| RunStyleService | `src/ServerScriptService/RunStyleService.server.lua` | Server-whitelisted cosmetic animation selection | Project Owner |
| Bootstrap | `src/ServerScriptService/Bootstrap.server.lua` | Kalsada greybox, lighting, and character defaults | Project Owner |

## Client

| Controller or module | Canonical source | Client-owned responsibility | Owner |
|---|---|---|---|
| MovementController | `src/StarterPlayerScripts/MovementController.client.lua` | Input, predicted movement, movement animation, ability presentation, and local camera effects | Project Owner |
| MomentumController | `src/StarterPlayerScripts/MomentumController.lua` | Local momentum prediction, reconciliation, and local change events | Project Owner |
| MomentumHUD | `src/StarterPlayerScripts/MomentumHUD.client.lua` | Local momentum bar, popups, chain, loss feedback, and sound cues | Project Owner |
| AirMovement | `src/StarterPlayerScripts/AirMovement.lua` | Normal jump grace windows, character-only falling force, air control, momentum preservation, and air-speed cap | Project Owner |
| LandingController | `src/StarterPlayerScripts/LandingController.lua` | Local landing classification, landing animation and impact events, and hard-landing penalty lifetime | Project Owner |
| TagController | `src/StarterPlayerScripts/TagController.lua` | Click, R2, and touch input plus an isolated local first-person arm rig | Project Owner |
| Tag bootstrap | `src/StarterPlayerScripts/TagController.client.lua` | Starts TagController once | Project Owner |
| SprintVFX | `src/StarterPlayerScripts/SprintVFX.lua` | Sprint cosmetic state and instances | Project Owner |
| SprintVFX bootstrap | `src/StarterPlayerScripts/SprintVFX.client.lua` | Starts the SprintVFX module | Project Owner |
| TargetLockController | `src/StarterPlayerScripts/TargetLockController.lua` | Local target selection, reticle, and camera assist | Project Owner |
| TargetLock bootstrap | `src/StarterPlayerScripts/TargetLockController.client.lua` | Starts the target-lock module | Project Owner |
| UIController | `src/StarterPlayerScripts/UIController.client.lua` | Match HUD, cooldowns, draft presentation, and recaps | Project Owner |
| LobbyUI | `src/StarterPlayerScripts/LobbyUI.client.lua` | Lobby, party, queue, settings presentation, and lobby camera | Project Owner |
| RpsUI | `src/StarterPlayerScripts/RpsUI.client.lua` | MS_RPS cards, sign input, local timer, and reveal presentation | Project Owner |
| MapVoteUI | `src/StarterPlayerScripts/MapVoteUI.client.lua` | Map-vote presentation and input | Project Owner |
| ModeVoteUI | `src/StarterPlayerScripts/ModeVoteUI.client.lua` | Match mode ballot presentation and input | Project Owner |
| PanyoHUD | `src/StarterPlayerScripts/PanyoHUD.client.lua` | Possession timer, ranking, Carrier marker, reveal highlight, and local cues | Project Owner |
| ClientSettings | `src/StarterPlayerScripts/ClientSettings.lua` | In-session presentation settings | Project Owner |
| AudioRouter | `src/StarterPlayerScripts/AudioRouter.lua` | Client SoundGroups and one-shot routing | Project Owner |
| MusicController | `src/StarterPlayerScripts/MusicController.lua` | Client match-state music playback and fades | Project Owner |
| VfxScale | `src/StarterPlayerScripts/VfxScale.lua` | Client cosmetic intensity and telegraph floor | Project Owner |
| CameraDirector | `src/StarterPlayerScripts/CameraDirector.lua` | In-match base third-person shoulder camera: pose, look input, collision, shoulder swap, cursor state, saved-state handoff around aim and target lock, the centralized movement camera effects (sprint, falling, landing, dash, slide, vault, roll), and the Phase 3 chase awareness set (role profiles, hold-to-look-back with movement assist, chase FOV, tag-transfer feedback) | Project Owner |
| CameraDirector bootstrap | `src/StarterPlayerScripts/CameraDirector.client.lua` | Starts CameraDirector once | Project Owner |
| ChaseState | `src/StarterPlayerScripts/ChaseState.lua` | Client-only chase awareness state: active Taya resolution (players and bots), distance, closing speed, visibility, and one smoothed chase intensity shared by camera and HUD | Project Owner |
| ChaseHUD | `src/StarterPlayerScripts/ChaseHUD.lua` | Phase 3 chase HUD: Runner edge chevron, Taya advisory tag-target marker, tag-transfer edge pulse, and the mobile hold-to-look-back button | Project Owner |
| ChaseHUD bootstrap | `src/StarterPlayerScripts/ChaseHUD.client.lua` | Starts ChaseHUD once | Project Owner |

## Tools and world inputs

| Area | Canonical source | Responsibility | Owner |
|---|---|---|---|
| Animation authoring | `tools/AnimationDev/HRush_AnimDev.lua`, `tools/AnimationDev/HRush_AnimPreview.lua` | Data-driven original R15 animation definitions, validation, building, and local preview | Project Owner |
| Workspace map input | `assets/Map.rbxmx` | Minimal Rojo Workspace map input; Bootstrap currently builds Kalsada | Project Owner |

## Rules

- The project owner is the only merge owner. Codex may modify a path only within an explicitly approved item.
- One behavior has one authoritative mutation owner. Client prediction and presentation never replace a server decision.
- Use direct dependencies and the current flat layout. Split a module only for a real authority, lifecycle, persistence, or test boundary.
- `Config` is read-only at runtime. Locked-value changes require project-owner approval.
- New client-to-server operations require type, bounds, state, role, membership, cooldown, and abuse validation.
- Every gameplay merge requires a Rojo build and a relevant live 2-player test before pushing.
- New assets require `ASSET_LOG.md`; AI-assisted work requires `AI_LOG.md`.
