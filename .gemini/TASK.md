# Habulan Rush — Master Production Task Tracker

Generated from `md-doc/Habulan_Rush_Production_Tracker.md`, `Habulan_Rush_Production_and_Launch_Plan.md`, `Habulan_Rush_System_Specification.md`, and `Habulan_Rush_Technical_Design_Document.md`.

---

## Phase 1: Design Lock & Workspace Setup (Days 1–2: Oct 7–8)

- [x] (2026-10-07) Read and understand all documentation files in `md-doc/` and establish initial workspace tracking.
- [x] (2026-10-07) Install skill `find-skills` from `https://github.com/vercel-labs/skills` into `.agents/skills/find-skills`.
- [x] (2026-10-07) Install specialized game dev skills: `roblox-luau`, `roblox-architecture`, `roblox-networking`, `roblox-tooling`, `game-feel`, `camera-systems`, `level-design` into `.agents/skills/`.
- [x] (2026-10-07) **T01 [Design/P0] Design Lock Sign-off & Gap Resolution**
  - [x] Approve GDD v2.0 baseline and resolve GDD System Review findings (F01–F18). → `DESIGN_LOCK.md`
  - [x] Confirm F01: Skill Draft runs every round (adds 24s; target match duration = 9.0 min).
  - [x] Confirm F06: Safe Window non-stacking rule (longest window applies).
  - [x] Confirm F07: Dash pounce invulnerability duration = 0.15s (vs pounce only).
  - [x] Confirm F11: Close chase distance = 10 studs for Diskarte reward.
  - [x] Confirm F12: Counter table definitions for Diskarte reward. → See `DESIGN_LOCK.md §Counter Table`
  - [x] Confirm F16: Esports 40–60% metric defined as pounce success rate (hits / attempts).
  - [x] Confirm F18: Disconnect & minimum 4-player rules.
- [x] (2026-10-07) **T02 [Tech/P0] Repository Scaffolding, Rojo & Disclosure Setup**
  - [x] Create folder structure matching TDD §2 (`src/ReplicatedStorage`, `src/ServerScriptService`, `src/StarterPlayerScripts`).
  - [x] Initialize `AI_LOG.md` with required schema (Date, Tool, Area, Output, Extent, Reviewer) for Form 03 compliance.
  - [x] Setup `ASSET_LOG.md` tracking all models, textures, audio licenses (Rule B.6 compliance).
  - [x] Setup Rojo project configuration (`default.project.json`).
- [x] (2026-10-07) **T03 [Tech/P0] Config Module Skeleton**
  - [x] Create `src/ReplicatedStorage/Config.lua` with zero hardcoding principle.
  - [x] Define schemas for `Config.Movement`, `Config.Taya`, `Config.Tag`, `Config.Skills`, `Config.Diskarte`, `Config.Match`, `Config.Events`.
- [x] (2026-10-07) **T04 [Design/P0] Config Baseline Balance Finalization** _(completed same day)_
  - [x] Populate `Config` values directly from Balance Workbook and System Specification.
  - [x] Set network rewind parameters (`RewindDefault = 0.12s`, `RewindMax = 0.20s`).
- [x] (2026-10-07) **T05 [Management/P0] Module Ownership & Team Assignments**
  - [x] Assign module leads across MatchService, TagService, SkillService, UIController, MovementController. → `MODULE_OWNERSHIP.md`
- [x] (2026-10-07) **T06 [Management/P0] Asset Sourcing & License Protocol**
  - [x] Establish asset review protocol in `ASSET_LOG.md` to ensure no unlicensed Toolbox models or audio are imported.

---

## Phase 2: Core Gameplay Loop (Days 3–6: Oct 9–12)

- [ ] (2026-10-09) **T07 [Code/P0] MatchService State Machine (MS_01 to MS_06) & Shuffle Bag**
  - [ ] Implement state machine: MS_01 Lobby, MS_02 Draft (12s), MS_03 Countdown (5s), MS_04 Round Live (150s), MS_05 Round End (8s), MS_06 Match End (15s).
  - [ ] Implement Shuffle Bag for initial Taya selection (persists across match rounds).
  - [ ] Implement player disconnect handling (nearest runner becomes Taya if Taya leaves; minimum 4 players check).
- [ ] (2026-10-09) **T08 [Level/P0] Barangay Kalsada Map Greybox**
  - [ ] Construct 150x150 stud arena with 8 equidistant spawn points.
  - [ ] Block out central basketball court, sari-sari store obstacles, vault-height jeepneys (<=4 studs), low gaps for sliding.
  - [ ] Verify no dead ends under 10 studs to prevent corner trapping.
- [ ] (2026-10-10) **T09 [Code/P0] MovementController (Client Movement & Stamina)** — 🟡 **PARTIAL** (code complete: walk/sprint/stamina/dash/slide/bindings + dash VFX + stamina HUD built & shipped in Studio; pending T07 MatchService state machine integration — currently runs on a temporary MS_04 auto-unlock in Bootstrap — and T15 playtest sign-off)
  - [x] Implement Runner walk (16 studs/s) and sprint (21 studs/s).
  - [x] Implement stamina depletion (20/s) and regen (12/s after 1s delay; walk enforced until >=10 if fully depleted).
  - [x] Implement Dash (12 studs in 0.2s, 6s cooldown, sends `RequestDash`).
  - [x] Implement Slide (0.6s, 3s cooldown, 50% hitbox height).
  - [x] Implement control bindings for PC, Touch/Mobile, and Gamepad.
- [ ] (2026-10-10) **T10 [Code/P0] Taya Timer & Scoreboard Replication**
  - [ ] Implement server-authoritative tenths-of-a-second Taya Time accumulator.
  - [ ] Replicate round timer and player rankings via `StateChanged`.
  - [ ] Implement round scoring: 8-6-5-4-3-2-1-0 points table; match tie-break by total Taya time.
- [ ] (2026-10-11) **T11 [Code/P0] TagService Server Validation & Tag Transfer**
  - [ ] Implement touch tag check (within 3 studs while moving).
  - [ ] Implement lag-aware rewind buffer (0.5s ring buffer of runner positions, rewound by ping up to 0.2s).
  - [ ] Replicate instantaneous tag swap across clients via `TagEvent`.
- [ ] (2026-10-11) **T12 [Code/P0] Safe Window, Speed Boost & Lock Delay**
  - [ ] Apply 2.0s Safe Window and 2.0s +20% speed boost to previous Taya.
  - [ ] Apply 1.0s Lock Delay to new Taya (gating target lock only; touch and pounce remain allowed).
  - [ ] Enforce non-stacking rule for safe windows.
- [ ] (2026-10-12) **T13 [Code/P0] Pounce Mechanics & Validation**
  - [ ] Implement `RequestPounce` with rate limiting and stun/cooldown validation.
  - [ ] Execute 0.35s windup telegraph on client, followed by 14-stud lunge at 45 studs/s (4 stud hit radius).
  - [ ] Implement 1.0s miss stun and 3.0s pounce cooldown upon missed pounce.
  - [ ] Validate 0.15s dash invulnerability against pounce lunges.
- [ ] (2026-10-12) **T14 [UI/P0] HUD v1 Implementation**
  - [ ] Role banner (Red hexagon TAYA vs Blue circle RUNNER).
  - [ ] Live round countdown (2:30).
  - [ ] Real-time scoreboard with local player highlight.
  - [ ] Runner stamina bar with low-stamina flash.
- [ ] (2026-10-12) **T15 [QA/P0] Core Loop Internal Playtest (Alpha Gate)**
  - [ ] Run 3 consecutive clean 4+ player matches.
  - [ ] Verify server authority on all tags and validate latency handling.

---

## Phase 3: Skills & Diskarte System (Days 7–9: Oct 13–15)

- [ ] (2026-10-13) **T16 [Code/P0] TargetLockController (Soft Lock Camera & Indicators)**
  - [x] Soft lock acquisition within 40 studs with line-of-sight check. (T16 Stage B implemented 2026-10-08; Studio validation pending.)
  - Stage B: client ModuleScript plus bootstrap, R toggle and T cycle reserved, camera-angle acquisition and manual unlock. Stages C through F remain pending.
  - [ ] Break lock beyond 55 studs or after 1s behind cover; trigger 4s lock cooldown.
  - [ ] Camera steering assistance (no automated character movement).
  - [ ] Overhead reticle ring indicator on locked target.
- [ ] (2026-10-13) **T17 [UI/P0] Skill Draft UI & Remote**
  - [ ] 12s draft modal displaying 2 Runner + 2 Taya cards.
  - [ ] Skill cards with icon, name, cooldown, tell, and weakness.
  - [ ] Implement `PickSkill(slot, skillId)` with server validation and timeout auto-pick.
- [ ] (2026-10-14) **T18 [Code/P0] SkillService: Runner Skills (RS_01 to RS_03)** — 🟡 **PARTIAL** (RS_01 done earlier; RS_03 server + cosmetics done 2026-10-10, manual 2-player test pending; RS_02 not started)
  - [ ] `RS_01` *Luksong Baka*: 14 studs height, 18 studs distance impulse, no air steering, 12s CD.
  - [ ] `RS_02` *Pekeng Takbo*: Decoy spawner, 4s running duration, lock-break, 18s CD.
  - [x] (2026-10-10) `RS_03` *Tsinelas Throw*: Physics projectile (25 studs range), 1.0s Taya stun on hit, 25s CD. (Server owns sim + hit test + HRushStunned stun in SkillService.server.lua; spinning slipper arc + impact star cosmetics + TEMP G test key in MovementController.client.lua; tunables in Config.Skills.RS_03. Needs live 2-player test before merge. Depends on TagService T11 for ServerRole; TEMP debug fallback in place. Safe Window does not protect; no F07 interaction.)
- [ ] (2026-10-14) **T19 [Code/P0] SkillService: Taya Skills (TS_01 to TS_03)**
  - [ ] `TS_01` *Sigaw*: 40 stud radial reveal for 2s, 20s CD.
  - [ ] `TS_02` *Lambat*: 8 stud net zone, -40% runner slow for 5s, 22s CD.
  - [ ] `TS_03` *Hatak*: +35% speed boost for 1.5s, disables target lock, 15s CD.
- [ ] (2026-10-14) **T20 [Art/Audio/P1] Skill VFX & SFX Tells v1**
  - [ ] Create distinct visual and audio cues for each of the 6 skills (dust ring, smoke puff, slipper arc, shout wave, net grid, speed lines).
- [ ] (2026-10-15) **T21 [Code/P0] Diskarte Meter System**
  - [ ] 0–100 per-player meter, resets each round, strictly non-passive.
  - [ ] Rewards: Lock-break (+15), Pounce dodge (+25), Counter (+20), Close-chase escape under 10 studs (+15), Taya pounce tag (+25), Catch after escape (+20).
  - [ ] Anti-snowball guard: max 1 reward between the same pair every 6s; no repeated tag gain within 3s.
- [ ] (2026-10-15) **T22 [Code/P0] Diskarte Moves (LIKSI, BANTAY, PUSO)**
  - [ ] `LIKSI` (Runner): 50% cooldown reduction on next skill within 8s.
  - [ ] `BANTAY` (Taya): Directional pointer to nearest Runner for 2s (no wallhack).
  - [ ] `PUSO` (Both): 0.75s Safe Window upon next valid tag interaction (expires at 10s).
- [ ] (2026-10-15) **T23 [QA/P0] Skill Counter Testing & First Balance Pass**
  - [ ] Conduct 1v1 counter-testing for each skill matchup.
  - [ ] Verify that pounce success rates fall within the 40–60% target band.

---

## Phase 4: Rush Systems & Event Timeline (Days 10–11: Oct 16–17)

- [ ] (2026-10-16) **T24 [Code/P0] Barangay Rush: Court Rush Event**
  - [ ] Trigger at 100s remaining in `Round Live` via `EventService`.
  - [ ] 2.5s telegraph warning banner ("BARANGAY RUSH: COURT RUSH!").
  - [ ] Open central court route (high risk, zero cover) while keeping outer counter-routes viable.
- [ ] (2026-10-16) **T25 [Code/P0] Match Phase Controller**
  - [ ] Orchestrate timeline transitions: Simula (150–100s), Barangay Rush (100–50s), Huling Habol (50–0s).
- [ ] (2026-10-17) **T26 [UI/Audio/P0] Huling Habol Presentation Escalation**
  - [ ] Escalation stages at 50s, 30s (vignette), 15s, 10s (heartbeat audio + pulsing timer), 5s.
  - [ ] Implement seamless musical percussion layer fade-ins.
- [ ] (2026-10-17) **T27 [UI/P1] Clutch Callouts & Recap Screens**
  - [ ] In-game clutch popups: "PERFECT ESCAPE", "NICE READ", "CLUTCH", "PERFECT POUNCE".
  - [ ] Round End recap modal (Taya times, tags, escapes, Diskarte earned).
  - [ ] Match End MVP screen with identity titles (e.g., "Escape Specialist").
- [ ] (2026-10-17) **T28 [QA/P0] Readability & Spectator Test (Beta Gate)**
  - [ ] Confirm spectator can immediately identify Taya, leader, and current phase within 30s.

---

## Phase 5: Second Map, Tutorial & Esports Features (Day 12: Oct 18–19)

- [ ] (2026-10-18) **T29 [Level/P1] Binaha na Baryo Map Greybox & Flood Hazard**
  - [ ] Build flooded barrio environment: raised stilt houses, sandbags, boats, 8 spawns.
  - [ ] Implement rising water at 100s (-20% move speed in submerged low areas).
  - [ ] Implement teal Evacuation Center zones granting a one-time Safe Window per visit.
- [ ] (2026-10-18) **T30 [Code/UI/P0] Interactive Onboarding Tutorial**
  - [ ] 60–90s 8-step tutorial: Move, Sprint, Dash, Tag, Skill, Diskarte, Rush preview, Win condition.
  - [ ] Practice dummy bot Taya with predictable behavior.
  - [ ] Player profile tutorial completion tracking & skip option.
- [ ] (2026-10-18) **T31 [Code/P0] Private Lobbies & Spectator Camera**
  - [ ] Private match lobby code entry & generation (`ES_01`).
  - [ ] Spectator camera controller (`ES_02`): Follow Taya, Free Cam, and auto-activity switch.
- [ ] (2026-10-18) **T32 [Management/P0] Day-12 Scope Review & Go/No-Go Checkpoint**
  - [ ] Formal review of Binaha na Baryo: lock map for release or cut to focus on Kalsada polish.
  - [ ] Formal cut of all P2 stretch items (Recycling Hub, Team Habulan, Time Trial).

---

## Phase 6: Polish, Feature Freeze & Playtesting (Oct 20–23)

- [ ] (2026-10-20) **T33 [Art/Audio/UI/P0] Asset Integration & Feature Freeze (Oct 21 Evening)**
  - [ ] Final visual pass for Barangay Kalsada (jeepney textures, sari-sari props, court paint).
  - [ ] Integrate Filipino voice lines ("Taya ka!", "Safe!", "Habol!", "Huling habol!").
  - [ ] Finalize accessibility settings: Colorblind palette toggle, UI text scaling (S/M/L), reduced shake.
  - [ ] **Feature Freeze Oct 21, 18:00**: Zero new gameplay code; bug fixes and tuning only.
- [ ] (2026-10-22) **T34 [QA/P0] Comprehensive Playtesting & Release Candidate Validation**
  - [ ] Conduct 6-player playtests on PC and Mobile.
  - [ ] Validate pounce hit rate against 40–60% target in Balance Workbook.
  - [ ] Verify mobile performance: 30+ FPS on mid-range devices, memory < 1GB.

---

## Phase 7: Final Submission Package & Launch (Oct 24–25)

- [ ] (2026-10-24) **T35 [Media/P0] Gameplay Trailer & Demo Recording**
  - [ ] Record 60–90 second high-energy gameplay trailer (.mp4).
  - [ ] Record 3–5 minute full 6-player match walkthrough (.mp4) with spectator view.
- [ ] (2026-10-24) **T36 [Management/P0] Competition Paperwork & Package Audit**
  - [ ] Audit `AI_LOG.md` and complete Form 03 (Asset & AI Usage Disclosure).
  - [ ] Complete Form 01 (Team Roles) & Form 02 (Declaration of Originality signed by team and coach).
  - [ ] Complete Template 01 (Game Synopsis, max 500 words).
  - [ ] Verify published Roblox place permissions and test from a fresh account.
- [ ] (2026-10-25) **T37 [Management/P0] Official Submission**
  - [ ] Submit all forms, video links, synopsis, and place link before the deadline (target: before 12:00 PM).
