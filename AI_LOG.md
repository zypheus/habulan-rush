# AI Usage Log — Habulan Rush
_Form 03 Compliance: Required by Level Up 3.0 Esports Game Dev Challenge Rules_

## Schema
| Date | Tool | Area | Output | Extent | Reviewer |
|------|------|------|--------|--------|----------|
| Date of AI use | Tool name (e.g. Antigravity / Claude) | System or file affected | What was generated or changed | Full / Partial / Review only | Team member who reviewed |

---

## Log Entries

| Date | Tool | Area | Output | Extent | Reviewer |
|------|------|------|--------|--------|----------|
| 2026-10-07 | Antigravity (Claude Sonnet) | Project Setup | Read all md-doc/ documentation, established PLANNING.md and TASK.md tracking, installed agent skills (roblox-luau, roblox-architecture, roblox-networking, roblox-tooling, game-feel, camera-systems, level-design, find-skills), connected Roblox Studio MCP | Review only | — |
| 2026-10-07 | Antigravity (Claude Sonnet) | Design Lock (T01) | Created DESIGN_LOCK.md confirming all GDD System Review HIGH findings (F01–F18) with recommended defaults from the System Specification | Review only | — |
| 2026-10-07 | Antigravity (Claude Sonnet) | Repository Scaffolding (T02) | Created folder structure, default.project.json (Rojo), AI_LOG.md, ASSET_LOG.md | Full | — |
| 2026-10-07 | Antigravity (Claude Sonnet) | Config Module (T03/T04) | Created ReplicatedStorage/Config.lua with all gameplay constants, skill definitions, Diskarte values, match timing, network rewind parameters | Full | — |
| 2026-10-07 | Cline (Muse Spark) | MovementController T09 | Completed StarterPlayerScripts/MovementController.lua: post-tag +20% boost (F08 via TagEvent), linear wall-clamped dash (12st/0.2s/6s/F07), slide momentum + 50% hitbox (F09), MS_03 movement lock, UI/UX Spec §4 bindings (PC Shift/Q/C, gamepad L2-stick/B/R1, touch), HRush* attribute UI bridge, Rojo $className fixes (LocalScript/Script/ModuleScript) | Full | — |
| 2026-10-08 | Cline (Muse Spark) | Skill RS_01 enhance (code, vfx, audio) | RS_01 windup/landing recovery/direction lock, server-validated cast flow with SkillEvent broadcast, TagRules untouchable module for TM_05/TM_08, dust puff/ring/trail/preview VFX, sound and FOV/shake hooks, Config.Debug.AllowAnyRoleForSkills flag, circular skill chip with ready pulse | heavy | pending |
| 2026-10-08 | Cline (Muse Spark) | Skill RS_01 fix (code, vfx) | Diagnosed TweenInfo nil fovTime crash aborting launchSkill (log stack trace); rebuilt flow as server-validates/SkillApproved-to-caster/SkillVFX-to-all/SkillLanded report with IsAirborne attribute, ChangeState then next-heartbeat velocity leap, no-WalkSpeed steering lock, StateChanged landing + wall slow-end, ShowSkillDebug prints and airborne label | heavy | pending |
| 2026-10-08 | Antigravity | Match & Lobby System (T07) | Merged branch1 into main: integrated MatchService v1.1 (matchmaking queue, bot fill, ShuffleBag Taya selection, phase synchronization), LobbyUI with responsive layout, custom camera, panels, full-screen loading screen (DisplayOrder 100), and HUD gate (applyHudGate) on UIController | Full | pending |
| 2026-10-10 | OpenCode (Muse Spark) | Skill RS_03 Tsinelas Throw (T18) | Config.Skills.RS_03 params/vfx/sounds tunables + testGrant; SkillService.server.lua RS_03 branch with server-owned projectile sim, Taya lookup (ServerRole + TEMP debug fallback), HRushStunned stun apply/clear; MovementController.client.lua spinning slipper arc + impact star cosmetics + TEMP G test key; Rojo build passes; no assets imported | Full | pending |
