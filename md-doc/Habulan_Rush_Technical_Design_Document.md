# **HABULAN RUSH Technical Design Document** 

_Version 1.0 • Platform: Roblox (Luau) • Derived from GDD v2.0 §18_ 

## **1. Technical goals** 

- Server-authoritative, fair multiplayer for 4–8 players. 

- Data-driven balance: all numbers in Config; zero hardcoded values elsewhere. 

- Stable performance on mobile (target 30+ FPS on mid-range devices). 

- Small, testable modules with clear ownership. 

## **2. Architecture** 

|**Module**|**Location**|**Responsibility**|**Owner**|
|---|---|---|---|
|Config|ReplicatedStorage|Tunable numbers, skill definitions, map data|Designer +<br>Programmer|
|MatchService|ServerScriptService|State machine, shuffle bag, scoring, phase<br>timers, disconnect handling|Programmer A|
|TagService|ServerScriptService|Pounce/touch validation, transfer, Safe Window,<br>Lock Delay, lag rewind|Programmer A|
|SkillService|ServerScriptService|Draft, cooldowns, role checks, effects, Diskarte|Programmer B|
|EventService|ServerScriptService|Barangay Rush events and Huling Habol<br>timeline|Programmer B|
|MovementController|StarterPlayerScripts|Sprint, dash, slide, stamina presentation|Programmer A|
|TargetLockController|StarterPlayerScripts|Soft lock camera and indicator|Programmer B|
|UIController|StarterPlayerScripts|HUD, banners, callouts, recap, spectator UI|UI Dev|
|Remotes|ReplicatedStorage|RemoteEvents / RemoteFunctions|Shared|



Owners are placeholders; assign at Design Lock. 

## **3. Data model** 

### **3.1 Config.Skills entry** 

|**Field**|**Type**|**Example**|
|---|---|---|
|id|string|"RS_01"|
|role|"Runner"|"Taya"|"Runner"|
|type|string|"Escape"|
|cooldown|number (s)|12|
|duration|number (s)|0|
|range|number (studs)|18|
|params|table|{ height = 14, distance = 18 }|
|tell|table|{ vfx = "DustRing", sfx = "Hup" }|
|weakness|string|"No air steering"|



Habulan Rush • Technical Design Document • Page 1 

### **3.2 Server player state (not replicated in full)** 

|**Field**|**Notes**|
|---|---|
|role|Runner | Taya|
|tayaTime|Seconds as Taya this round; server only authoritative|
|totalPoints / totalTayaTime|Match totals|
|skills|{ runnerSkillId, tayaSkillId }|
|cooldowns|Map skillId → readyAt (server clock)|
|diskarte|0–100, round scoped|
|safeUntil / stunUntil / lockDelayUntil /<br>lockCooldownUntil|Server clock timestamps|
|connected|boolean|



## **4. Networking** 

### **4.1 Remotes** 

|**Remote**|**Directi**<br>**on**|**Payload**|**Server validation**|
|---|---|---|---|
|RequestPounce|C→S|direction (unit vector)|Role Taya; state Round Live; cooldown ready; not<br>stunned; rate limit|
|RequestSkill|C→S|skillId|State, ownership, role, cooldown, stun|
|RequestDash|C→S|direction|Cooldown ready; state Round Live|
|PickSkill|C→S|slot, skillId|Draft state only; id must be in offered set|
|ActivateDiskarte|C→S|moveId|Meter = 100; move allowed for role|
|StateChanged|S→C|state, timer, round|—|
|TagEvent|S→C|taggerId, targetId, time|—|
|SkillEvent|S→C|playerId, skillId, params|Drives VFX/SFX tells|
|DiskarteUpdate|S→C|value (owner only)|—|
|ClutchEvent|S→C|type, playerId|—|



### **4.2 Rules** 

- All remotes validate argument types and ranges before use; unexpected types are dropped and counted. 

- Per-player rate limit on each request remote (e.g. max 10/s) with warning logging. 

- Clients may predict movement and cosmetics; hit results, cooldowns, scores and Diskarte come only from the server. 

- Use unreliable events only for cosmetic effects; gameplay events are reliable. 

### **4.3 Lag-aware tag validation** 

- Server stores a 0.5 s ring buffer of Runner positions at Heartbeat rate. 

- On RequestPounce, the server resolves the lunge using target positions rewound by min(client latency, Config.RewindMax); default 0.12 s, cap 0.2 s. 

- Reject if rewind exceeds cap, preventing exploit-friendly latency. 

- Log every tag with ping, rewound distance and result for the Playtest Log. 

Habulan Rush • Technical Design Document • Page 2 

## **5. Match and event timing** 

- Server clock (workspace:GetServerTimeNow) is the only timer source; clients render countdowns from StateChanged timestamps. 

- EventService subscribes to MatchService phase changes: SIMULA → BARANGAY RUSH at 100 s, HULING HABOL at 50 s. 

- Event warning fires 2.5 s before the change; map data defines the trigger and the counter-route. 

## **6. Client systems** 

- MovementController: input mapping (PC, touch, gamepad), stamina bar, dash and slide animations; sends requests, never final positions of a tag. 

- TargetLockController: nearest valid target in cone and range with line-of-sight check; ring indicator; breaks per server messages. 

- UIController: single state-driven HUD; every element hides or shows by state, never by polling. 

- • Spectator: free camera, follow Taya, auto-switch to highest-activity chase (MVP-lite). 

## **7. Performance budget** 

|**Area**|**Budget**|
|---|---|
|Parts per map|≤ 6,000 with streaming disabled; keep draw calls low via meshes/unions|
|Active particle emitters|≤ 30 at once; pooled|
|Server frame|Heartbeat work < 4 ms at 8 players|
|Memory|Mobile target under 1 GB|
|Network|< 20 KB/s per client average|



## **8. Security and anti-cheat** 

- No client authority over speed, cooldown, role, score or timers. 

- Server sanity-checks movement speed (speed ceiling = boosted Hatak speed + margin) and teleport distance. 

- Config is read-only at runtime; admin commands are for private lobbies only. 

## **9. Tooling and workflow** 

- Version control (Git/Rojo or Team Create with published backups). Branch per feature; merge only builds that run in a live 2-player test. 

- Folder layout mirrors the architecture table; one ModuleScript per service. 

- Logging: tagged logs per service; AI_LOG.md updated the same day AI is used. 

- Debug overlay (private lobby only): ping, rewind, states, Diskarte, cooldowns. 

## **10. Technical risks** 

|**Risk**|**Mitigation**|
|---|---|
|Lag disputes on pounce|Rewind buffer, generous hit radius, clear tag feedback, logs|
|Mobile frame rate|Part budgets, pooled VFX, early device test|
|Event desync|Server-timestamped events, clients render only|
|Merge conflicts|Module ownership, small commits, daily integration|



Habulan Rush • Technical Design Document • Page 3 

