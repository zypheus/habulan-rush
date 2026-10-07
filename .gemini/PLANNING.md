# Project Planning: Habulan Rush

## 1. Project Overview & Target Event
- **Project Name:** Habulan Rush
- **Target Event:** Level Up 3.0 Esports Game Dev Challenge (Student Category)
- **Target Deadline:** October 25, 2026 (Internal target: October 24, 2026)
- **Core Concept:** A competitive Filipino playground chase game ("habulan" / tag) where players draft skills, the tagged player becomes the "Taya" (chaser), and the player with the lowest cumulative Taya time wins.

## 2. Tech Stack & Platform
- **Engine:** Roblox (PC, mobile, console)
- **Language:** Luau
- **Architecture Pattern:** Server-authoritative architecture with client-side prediction and presentation.
- **Data-Driven Configuration:** All gameplay numbers, movement constants, skill definitions, and timing values live strictly inside `ReplicatedStorage.Config`.

## 3. Core Architecture
- **Config** (`ReplicatedStorage/Config`): Single source of truth for numeric balance, skill specifications, movement speeds, timings.
- **MatchService** (`ServerScriptService/MatchService`): State machine (MS_01 to MS_06: Lobby -> Skill Draft -> Countdown -> Round Live -> Round End -> Match End), shuffle bag first-taya picker, round & match scoring.
- **TagService** (`ServerScriptService/TagService`): Server-authoritative tag validation, pounce resolution with lag rewind (0.12s default, cap 0.2s), safe windows, speed boosts, and lock delay.
- **SkillService** (`ServerScriptService/SkillService`): Skill drafting, cooldown tracking, role-specific execution (Runner vs Taya), Diskarte meter logic.
- **EventService** (`ServerScriptService/EventService`): Match phase timeline management (Simula 150-100s, Barangay Rush 100-50s, Huling Habol 50-0s).
- **MovementController** (`StarterPlayerScripts/MovementController`): Local character controls (sprint, stamina bar, dash with invulnerability, slide).
- **TargetLockController** (`StarterPlayerScripts/TargetLockController`): Soft lock camera steering and targeting reticle for Taya.
- **UIController** (`StarterPlayerScripts/UIController`): HUD, role banners, skill bar, scoreboard, clutch event popups, spectator views.
- **Remotes** (`ReplicatedStorage/Remotes`): Strongly typed and rate-limited RemoteEvents/RemoteFunctions.

## 4. Design Pillars & Competition Compliance
- **Design Pillars:** Easy to learn, skill over luck, spectator-friendly, proudly Filipino culture.
- **Themes Covered:** Philippine Games and Sports, Disaster Risk Reduction and Management (DRRM), Circular Economy, Education.
- **Compliance Requirements:**
  - 100% original code and assets (no unauthorized toolbox models/audio).
  - Maintained `AI_LOG.md` for AI disclosure (Form 03).
  - No monetization (no Robux transactions allowed).
  - Private lobby codes and spectator tools for esports tournament play.
